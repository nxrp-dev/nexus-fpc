# Copyright (c) 2026 Kevin Collins.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses",
# as defined by the Mozilla Public License, v. 2.0.
#
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
# PE32+ checks use the Microsoft PE format, not GNU section-boundary symbols.
function Test-NXContractImage([string]$Path, [bool]$IsDll, [bool]$Relocatable) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    function U16([int]$Offset) { [BitConverter]::ToUInt16($bytes, $Offset) }
    function U32([int]$Offset) { [BitConverter]::ToUInt32($bytes, $Offset) }
    function U64([int]$Offset) { [BitConverter]::ToUInt64($bytes, $Offset) }
    function Require([bool]$Condition, [string]$Message) {
        if (-not $Condition) { throw "$Path : $Message" }
    }
    Require ((U16 0) -eq 0x5a4d) 'missing DOS signature'
    $pe = U32 0x3c
    Require ((U32 $pe) -eq 0x4550) 'missing PE signature'
    Require ((U16 ($pe+4)) -eq 0x8664) 'not AMD64'
    $optional = $pe+24
    Require ((U16 $optional) -eq 0x20b) 'not PE32+'
    Require (((U16 ($pe+22)) -band 0x2000) -eq $(if ($IsDll) {0x2000} else {0})) 'DLL characteristic'
    $base = U64 ($optional+24)
    $sectionAlignment = U32 ($optional+32)
    $fileAlignment = U32 ($optional+36)
    $imageSize = U32 ($optional+56)
    $headersSize = U32 ($optional+60)
    $sections = @()
    $table = $optional+(U16 ($pe+20))
    $previousEnd = $headersSize
    $zeroFill = 0
    for ($i = 0; $i -lt (U16 ($pe+6)); $i++) {
        $offset = $table+40*$i
        $section = [pscustomobject]@{
            Name = [Text.Encoding]::ASCII.GetString($bytes,$offset,8).Trim([char]0)
            Size = U32 ($offset+8); RVA = U32 ($offset+12)
            RawSize = U32 ($offset+16); Raw = U32 ($offset+20)
            Flags = U32 ($offset+36)
        }
        $span = [Math]::Max($section.Size,$section.RawSize)
        Require (($section.RVA % $sectionAlignment) -eq 0) 'section RVA alignment'
        Require ($section.RVA -ge $previousEnd) 'overlapping section virtual ranges'
        Require (($section.RVA+$span) -le $imageSize) 'section outside image'
        if ($section.RawSize) {
            Require (($section.Raw % $fileAlignment) -eq 0) 'raw alignment'
            Require (($section.Raw+$section.RawSize) -le $bytes.Length) 'section outside file'
        }
        if (($section.Flags -band 0x80000000L) -ne 0 -and $section.Size -gt $section.RawSize) {
            $zeroFill += $section.Size-$section.RawSize
        }
        $previousEnd = $section.RVA+$span
        $sections += $section
    }
    function Section([long]$RVA, [long]$Size = 1) {
        @($sections | Where-Object { $RVA -ge $_.RVA -and ($RVA+$Size) -le ($_.RVA+[Math]::Max($_.Size,$_.RawSize)) }) | Select-Object -First 1
    }
    function FileOffset([long]$RVA, [long]$Size = 1) {
        $section = Section $RVA $Size
        Require ($null -ne $section) ('unmapped RVA {0:x}' -f $RVA)
        Require (($RVA-$section.RVA+$Size) -le $section.RawSize) 'RVA has no file bytes'
        [int]($section.Raw+$RVA-$section.RVA)
    }
    function Directory([int]$Index) {
        $offset = $optional+112+8*$Index
        [pscustomobject]@{ RVA = U32 $offset; Size = U32 ($offset+4) }
    }
    $entry = Section (U32 ($optional+16))
    Require ($null -ne $entry -and ($entry.Flags -band 0x20000000) -ne 0) 'entry not executable'
    Require ($zeroFill -ge 131072) 'fixture did not exercise large zero-fill storage'
    foreach ($index in @(1,3,9)) {
        $dir = Directory $index
        Require ($dir.RVA -ne 0 -and $dir.Size -gt 0) "missing directory $index"
        $null = FileOffset $dir.RVA $dir.Size
    }
    if ($IsDll) {
        foreach ($index in @(0,2)) {
            $dir = Directory $index
            Require ($dir.RVA -ne 0 -and $dir.Size -gt 0) "missing DLL directory $index"
            $null = FileOffset $dir.RVA $dir.Size
        }
        Require ($base -eq 0x180000000L) 'unexpected DLL preferred base'
    }
    $unwind = Directory 3
    Require (($unwind.Size % 12) -eq 0) 'malformed exception directory'
    $offset = FileOffset $unwind.RVA $unwind.Size
    $previousEnd = 0
    for ($i = 0; $i -lt $unwind.Size; $i += 12) {
        $begin = U32 ($offset+$i); $end = U32 ($offset+$i+4)
        $code = Section $begin ($end-$begin)
        Require ($end -gt $begin -and $begin -ge $previousEnd) 'unsorted/overlapping unwind functions'
        Require ($null -ne $code -and ($code.Flags -band 0x20000000) -ne 0) 'unwind function not executable'
        $null = FileOffset (U32 ($offset+$i+8)) 4
        $previousEnd = $end
    }
    $tls = Directory 9
    $offset = FileOffset $tls.RVA 40
    $start = U64 $offset; $end = U64 ($offset+8)
    Require ($end -ge $start -and $start -ge $base -and $end -le ($base+$imageSize)) 'TLS template bounds'
    $index = Section ((U64 ($offset+16))-$base) 4
    Require ($null -ne $index -and ($index.Flags -band 0x80000000L) -ne 0) 'TLS index not writable'
    $callbacks = (U64 ($offset+24))-$base
    $callbackCount = 0
    while ($true) {
        Require ($callbackCount -lt 64) 'TLS callbacks missing terminator'
        $address = U64 (FileOffset ($callbacks+$callbackCount*8) 8)
        if ($address -eq 0) { break }
        $code = Section ($address-$base)
        Require ($null -ne $code -and ($code.Flags -band 0x20000000) -ne 0) 'TLS callback not executable'
        $callbackCount++
    }
    Require ($callbackCount -gt 0) 'RTL TLS callback not retained'
    $reloc = Directory 5
    $relocations = 0
    if ($Relocatable) {
        Require ($reloc.RVA -ne 0 -and $reloc.Size -gt 0) 'missing base relocations'
        $offset = FileOffset $reloc.RVA $reloc.Size
        $limit = $offset+$reloc.Size
        while ($offset -lt $limit) {
            $page = U32 $offset; $size = U32 ($offset+4)
            Require ($size -ge 8 -and ($size % 2) -eq 0 -and ($offset+$size) -le $limit) 'malformed relocation block'
            for ($i = 8; $i -lt $size; $i += 2) {
                $item = U16 ($offset+$i); $kind = $item -shr 12
                Require ($kind -eq 0 -or $kind -eq 10) 'unexpected AMD64 relocation type'
                if ($kind -eq 10) {
                    Require ($null -ne (Section ($page+($item -band 4095)) 8)) 'relocation target outside sections'
                    $relocations++
                }
            }
            $offset += $size
        }
        Require ($relocations -gt 0) 'no DIR64 relocations'
    } else {
        Require ($reloc.Size -eq 0) 'fixed EXE unexpectedly relocatable'
    }
    [pscustomobject]@{ Image = $Path; ImageBase = $base; ZeroFillBytes = $zeroFill
        Sections = $sections; UnwindRows = $unwind.Size/12; TLSCallbacks = $callbackCount; DIR64Relocations = $relocations }
}
