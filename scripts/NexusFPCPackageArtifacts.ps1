# Shared package bundle operations. Dot-sourced by the SDK build/compile helpers.
function Read-NexusPackageMetadata([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        $header = $reader.ReadBytes(32)
        if ($header.Length -ne 32 -or [Text.Encoding]::ASCII.GetString($header,0,6) -cne 'NXP004') {
            throw "Unsupported package metadata: $Path; expected NexusFPC NXP004, rebuild with NexusFPC"
        }
        $result = @{Name='';SDK='';Build='';Requires=@{}}
        while ($stream.Position -lt $stream.Length) {
            $length = $reader.ReadInt32()
            $kind = $reader.ReadByte()
            $entry = $reader.ReadByte()
            if ($length -lt 0 -or $length -gt ($stream.Length-$stream.Position) -or $kind -ne 1) {
                throw "Invalid package metadata: $Path"
            }
            if ($entry -eq 255) { break }
            $data = $reader.ReadBytes($length)
            $part = [IO.BinaryReader]::new([IO.MemoryStream]::new($data,$false))
            try {
                function Read-PackageString {
                    $size = $part.ReadByte()
                    $bytes = $part.ReadBytes($size)
                    if ($bytes.Length -ne $size) { throw "Truncated package metadata: $Path" }
                    [Text.Encoding]::ASCII.GetString($bytes)
                }
                switch ($entry) {
                    93 { $result.Name = Read-PackageString }
                    92 {
                        $null = Read-PackageString
                        $result.SDK = Read-PackageString
                        $result.Build = Read-PackageString
                    }
                    245 {
                        while ($part.BaseStream.Position -lt $length) {
                            $name = Read-PackageString
                            $identity = Read-PackageString
                            if ($result.Requires.ContainsKey($name)) { throw "Duplicate package dependency: $Path" }
                            $result.Requires[$name] = $identity
                        }
                    }
                }
            } finally { $part.Dispose() }
        }
        if (-not $result.Name -or -not $result.Build) { throw "Incomplete package metadata: $Path" }
        return $result
    } finally { $reader.Dispose() }
}

function Read-NexusPackageImage([string]$Path) {
    # Read the exported descriptor without executing or mapping package code.
    $bytes = [IO.File]::ReadAllBytes($Path)
    function Read-U16([int]$Offset) { [BitConverter]::ToUInt16($bytes,$Offset) }
    function Read-U32([int]$Offset) { [BitConverter]::ToUInt32($bytes,$Offset) }
    function Read-U64([int]$Offset) { [BitConverter]::ToUInt64($bytes,$Offset) }
    $pe = Read-U32 60
    if ((Read-U32 $pe) -ne 0x4550 -or (Read-U16 ($pe+4)) -ne 0x8664) { throw "Not a Win64 package image: $Path" }
    $optional = $pe+24
    if ((Read-U16 $optional) -ne 0x20b) { throw "Unsupported package PE format: $Path" }
    $imageBase = Read-U64 ($optional+24)
    $sectionTable = $optional+(Read-U16 ($pe+20))
    $sections = @()
    for ($i=0; $i -lt (Read-U16 ($pe+6)); $i++) {
        $offset = $sectionTable+40*$i
        $sections += [pscustomobject]@{Address=(Read-U32 ($offset+12)); Size=(Read-U32 ($offset+16)); Raw=(Read-U32 ($offset+20))}
    }
    function Get-ImageOffset([uint64]$Rva) {
        foreach ($section in $sections) {
            if ($Rva -ge $section.Address -and $Rva -lt ($section.Address+$section.Size)) {
                $offset = $section.Raw+$Rva-$section.Address
                if ($offset -ge $bytes.Length) { break }
                return [int]$offset
            }
        }
        throw "Invalid package image address: $Path"
    }
    function Read-ImageString([uint64]$Address) {
        $offset = Get-ImageOffset ($Address-$imageBase)
        [Text.Encoding]::ASCII.GetString($bytes,$offset+1,$bytes[$offset])
    }
    $exports = Get-ImageOffset (Read-U32 ($optional+112))
    $functions = Get-ImageOffset (Read-U32 ($exports+28))
    $names = Get-ImageOffset (Read-U32 ($exports+32))
    $ordinals = Get-ImageOffset (Read-U32 ($exports+36))
    for ($i=0; $i -lt (Read-U32 ($exports+24)); $i++) {
        $offset = Get-ImageOffset (Read-U32 ($names+4*$i))
        $end = $offset
        while ($end -lt $bytes.Length -and $bytes[$end] -ne 0) { $end++ }
        if ([Text.Encoding]::ASCII.GetString($bytes,$offset,$end-$offset) -cne 'FPC_PACKAGE_INFO') { continue }
        $ordinal = Read-U16 ($ordinals+2*$i)
        $pointer = Get-ImageOffset (Read-U32 ($functions+4*$ordinal))
        $descriptor = Get-ImageOffset ((Read-U64 $pointer)-$imageBase)
        if ((Read-U64 $descriptor) -ne 0x4e58504b -or
            (Read-U64 ($descriptor+8)) -ne 4 -or (Read-U64 ($descriptor+16)) -ne 168) {
            throw "Unsupported package image descriptor: $Path"
        }
        return @{Name=(Read-ImageString (Read-U64 ($descriptor+6*8)));
            SDK=(Read-ImageString (Read-U64 ($descriptor+18*8)));
            Build=(Read-ImageString (Read-U64 ($descriptor+19*8)))}
    }
    throw "Missing package descriptor export: $Path"
}

function Get-NexusPackageBundle([string]$Directory) {
    $directory = (Resolve-Path -LiteralPath $Directory).Path
    $current = Join-Path $directory 'current.json'
    if (Test-Path -LiteralPath $current) {
        $selection = Get-Content -LiteralPath $current -Raw | ConvertFrom-Json
        if ($selection.Generation -notmatch '^generation-[0-9a-f]{32}$') { throw "Invalid bundle selection: $current" }
        $directory = Join-Path $directory $selection.Generation
    }
    $manifestPath = Join-Path $directory 'bundle.json'
    if (Test-Path -LiteralPath $manifestPath) {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.Format -ne 1 -or -not $manifest.Files) { throw "Invalid package bundle manifest: $manifestPath" }
        $listed = @{}
        foreach ($file in $manifest.Files) {
            if ($file.Name -notmatch '^[A-Za-z0-9_.-]+\.(pcp|dll|exe)$' -or
                $listed.ContainsKey($file.Name) -or
                (Get-FileHash -LiteralPath (Join-Path $directory $file.Name)).Hash -ne $file.SHA256) {
                throw "Package bundle artifact differs from its manifest: $manifestPath"
            }
            $listed[$file.Name] = $true
        }
        foreach ($file in Get-ChildItem -LiteralPath $directory -File) {
            if ($file.Extension -in @('.pcp','.dll','.exe') -and -not $listed.ContainsKey($file.Name)) {
                throw "Unlisted package bundle artifact: $($file.FullName)"
            }
        }
    }
    elseif (Test-Path -LiteralPath $current) { throw "Missing package bundle manifest: $manifestPath" }
    return $directory
}

function Publish-NexusPackageBundle([string]$OutputDirectory,[string]$Work,[string]$Name,
    [string]$Kind,[string]$SDKIdentity,[string[]]$PackageDirectories) {
    $inputs = @{}
    $directories = @($PackageDirectories)
    if ($Kind -eq 'Package' -and (Test-Path -LiteralPath "$OutputDirectory\current.json")) {
        $directories += Get-NexusPackageBundle $OutputDirectory
    }
    foreach ($directory in $directories) {
        foreach ($file in Get-ChildItem -LiteralPath $directory -File) {
            if ($file.Extension -notin @('.pcp','.dll')) { continue }
            if ($Kind -eq 'Package' -and $file.BaseName -eq $Name) { continue }
            if ($inputs.ContainsKey($file.Name) -and
                (Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $inputs[$file.Name]).Hash) {
                throw "Conflicting package artifacts named $($file.Name)."
            }
            $inputs[$file.Name] = $file.FullName
        }
    }
    $extensions = if ($Kind -eq 'Package') { @('.pcp','.dll') } else { @('.exe') }
    foreach ($extension in $extensions) {
        $path = Join-Path $Work ($Name+$extension)
        if (-not (Test-Path -LiteralPath $path)) { throw "Expected output missing: $path. Package name must match its filename." }
        $inputs[$Name+$extension] = $path
    }
    $packages = @{}
    foreach ($entry in $inputs.GetEnumerator()) {
        if ([IO.Path]::GetExtension($entry.Key) -ne '.pcp') { continue }
        $metadata = Read-NexusPackageMetadata $entry.Value
        if ($metadata.SDK -ne $SDKIdentity -or -not $inputs.ContainsKey($metadata.Name+'.dll')) {
            throw "Incomplete or incompatible package bundle: $($metadata.Name)"
        }
        $image = Read-NexusPackageImage $inputs[$metadata.Name+'.dll']
        if ($image.Name -ne $metadata.Name -or $image.SDK -ne $metadata.SDK -or $image.Build -ne $metadata.Build) {
            throw "Package metadata/image identity mismatch: $($metadata.Name)"
        }
        $packages[$metadata.Name] = $metadata
    }
    foreach ($package in $packages.Values) {
        foreach ($dependency in $package.Requires.GetEnumerator()) {
            if (-not $packages.ContainsKey($dependency.Key) -or $packages[$dependency.Key].Build -ne $dependency.Value) {
                throw "Dependency build mismatch: $($package.Name) requires $($dependency.Key). Build a new complete distribution in a new output directory."
            }
        }
    }
    $generation = 'generation-' + [guid]::NewGuid().ToString('N')
    $directory = Join-Path $OutputDirectory $generation
    New-Item -ItemType Directory -Path $directory | Out-Null
    $files = @()
    foreach ($entry in $inputs.GetEnumerator()) {
        # Application distributions contain runtime images only.
        if ($Kind -ne 'Package' -and [IO.Path]::GetExtension($entry.Key) -eq '.pcp') { continue }
        Copy-Item -LiteralPath $entry.Value -Destination $directory
        $files += [pscustomobject]@{Name=$entry.Key;SHA256=(Get-FileHash -LiteralPath (Join-Path $directory $entry.Key)).Hash}
    }
    [pscustomobject]@{Format=1;SDK=$SDKIdentity;Files=$files} |
        ConvertTo-Json -Depth 6 | Set-Content "$directory\bundle.json" -Encoding UTF8
    $pending = Join-Path $OutputDirectory ($generation+'.json')
    [pscustomobject]@{Format=1;Generation=$generation} | ConvertTo-Json |
        Set-Content -LiteralPath $pending -Encoding UTF8
    $current = Join-Path $OutputDirectory 'current.json'
    if (Test-Path -LiteralPath $current) {
        [IO.File]::Replace($pending,$current,(Join-Path $OutputDirectory ($generation+'.previous.json')))
    }
    else { [IO.File]::Move($pending,$current) }
    return $directory
}
