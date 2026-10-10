"""Offline PCP/ELF validation and immutable Linux package bundle publication."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import uuid


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def metadata(path):
    data = Path(path).read_bytes()
    if len(data) < 32 or data[:6] != b'NXP004':
        raise ValueError(f'Unsupported package metadata: {path}; expected NexusFPC NXP004, rebuild with NexusFPC')
    result = dict(name='', sdk='', build='', requires={})
    pos = 32
    while pos + 6 <= len(data):
        length, kind, entry = struct.unpack_from('<iBB', data, pos)
        pos += 6
        if length < 0 or length > len(data) - pos or kind != 1:
            raise ValueError(f'Invalid package metadata: {path}')
        if entry == 255:
            break
        part = data[pos:pos + length]
        pos += length
        offset = 0

        def string():
            nonlocal offset
            if offset >= len(part):
                raise ValueError('Truncated package string')
            size = part[offset]
            offset += 1
            value = part[offset:offset + size]
            offset += size
            if len(value) != size:
                raise ValueError('Truncated package string')
            return value.decode('ascii')

        if entry == 93:
            result['name'] = string().upper()
        elif entry == 92:
            string()
            result['sdk'], result['build'] = string(), string()
        elif entry == 245:
            while offset < len(part):
                name, identity = string().upper(), string()
                if name in result['requires']:
                    raise ValueError('Duplicate package dependency')
                result['requires'][name] = identity
    if not result['name'] or not result['sdk'] or not result['build']:
        raise ValueError(f'Incomplete package metadata: {path}')
    return result


class ELF:
    """Only the little-endian ELF64 x86-64 ABI supported by this SDK.

    Resolve file-backed relocations without dlopen: validation never executes
    constructors from the image being published.
    """
    def __init__(self, path):
        self.data = Path(path).read_bytes()
        if self.data[:7] != b'\x7fELF\x02\x01\x01' or self.unpack('<H', 18)[0] != 62:
            raise ValueError(f'Not an x86-64 ELF image: {path}')
        if self.unpack('<H', 16)[0] not in (2, 3):
            raise ValueError('Expected executable/shared ELF image')
        offset = self.unpack('<Q', 40)[0]
        size, count = self.unpack('<HH', 58)
        if size != 64 or not count or offset < 64 or offset + size * count > len(self.data):
            raise ValueError('Unsupported ELF section layout')
        self.sections = [self.unpack('<IIQQQQIIQQ', offset + i * size) for i in range(count)]
        for section in self.sections:
            if section[1] != 8 and section[4] + section[5] > len(self.data):
                raise ValueError('Truncated ELF section')
        self.symbols, self.relocations = {}, {}
        self.tables = {}
        for index, section in enumerate(self.sections):
            if section[1] not in (2, 11):
                continue
            if section[6] >= count or section[9] != 24 or section[5] % 24:
                raise ValueError('Invalid ELF symbol table')
            strings = self.sections[section[6]]
            if strings[1] != 3:
                raise ValueError('Invalid ELF string table')
            symbols = []
            for off in range(section[4], section[4] + section[5], 24):
                name, info, other, owner, value, length = self.unpack('<IBBHQQ', off)
                name = self.cstring(strings[4] + name, strings[4] + strings[5])
                symbol = dict(name=name, value=value, owner=owner)
                symbols.append(symbol)
                if owner and name:
                    self.symbols[name] = value
            self.tables[index] = symbols
        for section in self.sections:
            if section[1] != 4:
                continue
            if section[6] not in self.tables or section[9] != 24 or section[5] % 24:
                raise ValueError('Invalid ELF relocation table')
            for off in range(section[4], section[4] + section[5], 24):
                address, info, addend = self.unpack('<QQq', off)
                if info >> 32 >= len(self.tables[section[6]]):
                    raise ValueError('Invalid ELF relocation symbol')
                self.relocations[address] = (info & 0xffffffff, self.tables[section[6]][info >> 32], addend)

    def unpack(self, fmt, offset):
        if offset < 0 or offset + struct.calcsize(fmt) > len(self.data):
            raise ValueError('Truncated ELF structure')
        return struct.unpack_from(fmt, self.data, offset)

    def cstring(self, offset, limit):
        end = self.data.find(b'\0', offset, limit)
        if offset < 0 or offset >= limit or end < offset:
            raise ValueError('Invalid ELF string')
        return self.data[offset:end].decode('ascii')

    def offset(self, address, size=1):
        for section in self.sections:
            if (section[2] & 2 and section[1] != 8 and
                    section[3] <= address and address + size <= section[3] + section[5]):
                return section[4] + address - section[3]
        raise ValueError(f'ELF address has no file data: {address:x}')

    def pointer(self, address):
        relocation = self.relocations.get(address)
        if relocation:
            kind, symbol, addend = relocation
            if kind == 8:  # R_X86_64_RELATIVE
                return addend
            if kind == 1 and symbol['owner']:  # R_X86_64_64
                return symbol['value'] + addend
            raise ValueError('Descriptor points outside its image')
        return self.unpack('<Q', self.offset(address, 8))[0]

    def short(self, address):
        offset = self.offset(address)
        count = self.data[offset]
        self.offset(address, count + 1)
        return self.data[offset + 1:offset + 1 + count].decode('ascii')

    def descriptor(self):
        if 'FPC_PACKAGE_INFO' in self.symbols:
            address = self.pointer(self.symbols['FPC_PACKAGE_INFO'])
        elif 'FPC_PACKAGE_ROOT' in self.symbols:
            address = self.symbols['FPC_PACKAGE_ROOT']
        else:
            raise ValueError('Missing package descriptor')
        words = self.unpack('<21Q', self.offset(address, 168))
        if words[:3] != (0x4e58504b, 4, 168):
            raise ValueError('Unsupported package descriptor')
        field = lambda index: self.pointer(address + 8 * index)
        result = dict(name=self.short(field(6)), sdk=self.short(field(18)),
                      build=self.short(field(19)), requires={})
        if words[9] > 65535:
            raise ValueError('Invalid dependency count')
        dependencies, identities = field(10), field(20)
        for index in range(words[9]):
            slot = self.pointer(dependencies + 8 * index)
            relocation = self.relocations.get(slot)
            if (not relocation or relocation[0] != 1 or relocation[1]['owner'] or
                    not relocation[1]['name'].startswith('FPC_PACKAGE_')):
                raise ValueError('Invalid ELF package dependency relocation')
            name = relocation[1]['name'][len('FPC_PACKAGE_'):]
            if name in result['requires']:
                raise ValueError('Duplicate descriptor dependency')
            result['requires'][name] = self.short(self.pointer(identities + 8 * index))
        return result


def bundle(directory):
    directory = Path(directory).resolve()
    current = directory / 'current.json'
    if current.is_file():
        name = json.loads(current.read_text())['generation']
        if not re.fullmatch(r'generation-[a-f0-9]{32}', name):
            raise ValueError('Invalid package generation')
        directory = directory / name
        if not (directory / 'bundle.json').is_file():
            raise ValueError('Selected package generation has no manifest')
    manifest = directory / 'bundle.json'
    if manifest.is_file():
        listed = json.loads(manifest.read_text())['artifacts']
        for name, value in listed.items():
            if Path(name).name != name or name in ('.', '..') or digest(directory / name) != value:
                raise ValueError('Package bundle artifact differs: ' + name)
        actual = {p.name for p in directory.iterdir() if p.is_file() and p.name != 'bundle.json'}
        if actual != set(listed):
            raise ValueError('Unlisted or missing package bundle artifacts')
    return directory


def publish(output, work, name, kind, sdk_id, directories):
    output, work = Path(output), Path(work)
    inputs = {}
    for directory in directories:
        for path in bundle(directory).iterdir():
            if path.suffix not in ('.pcp', '.so'):
                continue
            key = path.name
            if key in inputs and digest(inputs[key]) != digest(path):
                raise ValueError('Conflicting package artifact: ' + key)
            inputs[key] = path
    filenames = [name + '.pcp', 'lib' + name + '.so'] if kind == 'package' else [name]
    for filename in filenames:
        if filename in inputs and digest(inputs[filename]) != digest(work / filename):
            raise ValueError('Build into a new bundle when replacing an existing package: ' + filename)
        inputs[filename] = work / filename
    owners = {}
    for filename in inputs:
        if filename.endswith('.so') and filename[3:-3] + '.pcp' not in inputs:
            raise ValueError('Missing package metadata: ' + filename)
    for filename, path in inputs.items():
        if path.suffix != '.pcp':
            continue
        record = metadata(path)
        image = inputs.get('lib' + path.stem + '.so')
        if record['sdk'] != sdk_id or image is None:
            raise ValueError('Missing image or mismatched SDK: ' + filename)
        descriptor = ELF(image).descriptor()
        if any(descriptor[key] != record[key] for key in ('name', 'sdk', 'build')):
            raise ValueError('PCP and ELF identities differ: ' + filename)
        if any(record['requires'].get(k) != v for k, v in descriptor['requires'].items()):
            raise ValueError('PCP and ELF dependency identities differ: ' + filename)
        if record['name'] in owners:
            raise ValueError('Duplicate package identity')
        owners[record['name']] = record
    for record in owners.values():
        for dependency, identity in record['requires'].items():
            if dependency not in owners or owners[dependency]['build'] != identity:
                raise ValueError('Missing or incompatible dependency: ' + dependency)
    if kind != 'package':
        record = ELF(work / name).descriptor()
        if record['sdk'] != sdk_id:
            raise ValueError('Executable SDK identity differs')
        for dependency, identity in record['requires'].items():
            if dependency not in owners or owners[dependency]['build'] != identity:
                raise ValueError('Executable dependency differs: ' + dependency)
    generation = output / ('generation-' + uuid.uuid4().hex)
    generation.mkdir()
    for filename, path in inputs.items():
        shutil.copy2(path, generation / filename)
    manifest = dict(format=1, sdk_identity=sdk_id,
                    artifacts={filename: digest(generation / filename) for filename in sorted(inputs)})
    (generation / 'bundle.json').write_text(json.dumps(manifest, indent=2))
    temporary = output / ('current-' + uuid.uuid4().hex + '.json')
    temporary.write_text(json.dumps(dict(generation=generation.name)))
    os.replace(temporary, output / 'current.json')
    return generation
