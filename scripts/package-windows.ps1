param(
    [Parameter(Mandatory = $true)][string]$InstallDirectory,
    [Parameter(Mandatory = $true)][string]$SourceDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [Parameter(Mandatory = $true)][string]$Commit
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$install = (Resolve-Path -LiteralPath $InstallDirectory).Path
$source = (Resolve-Path -LiteralPath $SourceDirectory).Path
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
$engine = Join-Path $source 'upstream/KytyPS5'
$upstreamSha = 'b3e419ff1101999525fa2d061ada1d102cf788b1'
$build = Join-Path $source '_Build/windows'

if (-not (Test-Path -LiteralPath (Join-Path $engine 'CMakeLists.txt'))) {
    throw 'Pinned KytyPS5 source is missing'
}
if ((git -C $engine rev-parse HEAD) -ne $upstreamSha) {
    throw 'Pinned KytyPS5 source commit does not match upstream.lock'
}

function Assert-Pe64([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    $reader = [System.IO.BinaryReader]::new($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5a4d) {
            throw "Not a Windows PE executable: $Path"
        }
        $stream.Position = 0x3c
        $peOffset = $reader.ReadInt32()
        if ($peOffset -lt 0 -or $peOffset -gt ($stream.Length - 6)) {
            throw "Invalid PE header offset: $Path"
        }
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550 -or $reader.ReadUInt16() -ne 0x8664) {
            throw "Executable is not a valid x64 PE: $Path"
        }
    }
    finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

$requiredFiles = @(
    'launcher.exe',
    'kyty_emulator.exe',
    'Qt6Concurrent.dll',
    'Qt6Core.dll',
    'Qt6Gui.dll',
    'Qt6Network.dll',
    'Qt6Widgets.dll',
    'platforms/qwindows.dll',
    'libwinpthread-1.dll'
)
foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $install $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required runtime file missing: $relativePath"
    }
}
Assert-Pe64 (Join-Path $install 'launcher.exe')
Assert-Pe64 (Join-Path $install 'kyty_emulator.exe')

$licenseFiles = Get-ChildItem -LiteralPath $engine -Force -Recurse -File |
    Where-Object {
        $_.FullName -notmatch '[\\/]\.git([\\/]|$)' -and
        $_.Name -match '^(LICENSE|LICENCE|COPYING|NOTICE)(\..*)?$'
    }
if (-not ($licenseFiles | Where-Object { $_.FullName -eq (Join-Path $engine 'LICENSE') })) {
    throw 'Upstream GPL license file is missing'
}
if (-not ($licenseFiles | Where-Object { $_.FullName -eq (Join-Path $engine 'LICENSES/Kyty-MIT.txt') })) {
    throw 'Original Kyty MIT notice is missing'
}

if (Test-Path -LiteralPath $output) {
    Remove-Item -LiteralPath $output -Recurse -Force
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("MohammedLabPS5-" + [guid]::NewGuid())
$package = Join-Path $stage 'package'
$licenseDestination = Join-Path $package 'licenses/third-party'
New-Item -ItemType Directory -Path $licenseDestination -Force | Out-Null

try {
    Get-ChildItem -LiteralPath $install -Force |
        Copy-Item -Destination $package -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $source 'README-EN.md') -Destination $package
    Copy-Item -LiteralPath (Join-Path $source 'README-AR.md') -Destination $package
    Copy-Item -LiteralPath (Join-Path $engine 'LICENSE') -Destination (Join-Path $package 'LICENSE')
    Copy-Item -LiteralPath (Join-Path $engine 'LICENSES/Kyty-MIT.txt') `
        -Destination (Join-Path $package 'LICENSES-Kyty-MIT.txt')

    foreach ($license in $licenseFiles) {
        $relative = [System.IO.Path]::GetRelativePath($engine, $license.FullName)
        $destination = Join-Path $licenseDestination $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $license.FullName -Destination $destination
    }

    $toolchain = @(
        "Windows runner: windows-2022",
        "Qt: 6.10.3 (MSVC 2022 x64)",
        "CMake: $((cmake --version | Select-Object -First 1).Trim())",
        "Ninja: $((ninja --version).Trim())",
        "clang-cl: $((clang-cl --version | Select-Object -First 1).Trim())",
        "glslang: $((glslangValidator --version | Select-Object -First 1).Trim())"
    )
    $submodules = git -C $engine submodule status --recursive
    if ($LASTEXITCODE -ne 0 -or -not $submodules) {
        throw 'Recursive upstream dependencies are not initialized'
    }
    $manifest = @(
        'Product: MohammedLab PS5 Windows x64',
        "Repository commit: $Commit",
        "Pinned KytyPS5 commit: $upstreamSha",
        "Qt version: 6.10.3",
        'Emulator: upstream kyty_emulator.exe built from the pinned source',
        'No Sony firmware, SDK, keys, or games are included.',
        '',
        'Toolchain:',
        $toolchain,
        '',
        'Recursive submodules:',
        $submodules,
        '',
        'Note: glslang is installed from the windows-2022 runner vcpkg registry; its registry revision is runner-image managed.'
    ) -join "`r`n"
    $manifestPath = Join-Path $package 'build-manifest.txt'
    [System.IO.File]::WriteAllText($manifestPath, $manifest, [System.Text.UTF8Encoding]::new($false))

    function Add-DirectoryToArchive(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$Root,
        [string]$Prefix,
        [string[]]$ExcludedTopDirectories = @(),
        [string]$ExtraManifest = $null
    ) {
        $base = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
            [System.IO.Path]::DirectorySeparatorChar
        foreach ($file in Get-ChildItem -LiteralPath $Root -Force -Recurse -File) {
            $relative = [System.IO.Path]::GetRelativePath($Root, $file.FullName)
            $parts = $relative -split '[\\/]'
            if ($parts | Where-Object { $_ -in @('.git', '_Build', 'artifacts') }) {
                continue
            }
            if ($ExcludedTopDirectories -and ($parts[0] -in $ExcludedTopDirectories)) {
                continue
            }
            $entry = ($Prefix.TrimEnd('/') + '/' + ($relative -replace '\\', '/')).TrimStart('/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $Archive, $file.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
        if ($ExtraManifest) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $Archive, $ExtraManifest, "$($Prefix.TrimEnd('/'))/build-manifest.txt",
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    }

    $binaryZip = Join-Path $output 'MohammedLab-PS5-Windows-x64.zip'
    $archive = [System.IO.Compression.ZipFile]::Open(
        $binaryZip, [System.IO.Compression.ZipArchiveMode]::Create
    )
    try {
        Add-DirectoryToArchive -Archive $archive -Root $package -Prefix ''
    }
    finally {
        $archive.Dispose()
    }

    $sourceZip = Join-Path $output 'MohammedLab-PS5-source.zip'
    $archive = [System.IO.Compression.ZipFile]::Open(
        $sourceZip, [System.IO.Compression.ZipArchiveMode]::Create
    )
    try {
        Add-DirectoryToArchive -Archive $archive -Root $source `
            -Prefix 'MohammedLab-PS5-source' `
            -ExcludedTopDirectories @('_Build', 'artifacts') `
            -ExtraManifest $manifestPath
    }
    finally {
        $archive.Dispose()
    }

    foreach ($zip in @($binaryZip, $sourceZip)) {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
        try {
            if ($archive.Entries.Count -eq 0) {
                throw "Archive is empty: $zip"
            }
            foreach ($entry in $archive.Entries) {
                $null = $entry.Open().CopyTo([System.IO.Stream]::Null)
            }
        }
        finally {
            $archive.Dispose()
        }
        $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
        [System.IO.File]::WriteAllText(
            "$zip.sha256", "$hash  $([System.IO.Path]::GetFileName($zip))`n",
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    $binaryArchive = [System.IO.Compression.ZipFile]::OpenRead($binaryZip)
    try {
        $entries = @($binaryArchive.Entries | ForEach-Object { $_.FullName })
        foreach ($requiredEntry in @(
            'launcher.exe', 'kyty_emulator.exe', 'platforms/qwindows.dll',
            'build-manifest.txt', 'README-EN.md', 'README-AR.md', 'LICENSE',
            'LICENSES-Kyty-MIT.txt'
        )) {
            if ($requiredEntry -notin $entries) {
                throw "Required Windows archive entry missing: $requiredEntry"
            }
        }
    }
    finally {
        $binaryArchive.Dispose()
    }

    $sourceArchive = [System.IO.Compression.ZipFile]::OpenRead($sourceZip)
    try {
        $sourceEntries = @($sourceArchive.Entries | ForEach-Object { $_.FullName })
        foreach ($requiredEntry in @(
            'MohammedLab-PS5-source/.gitmodules',
            'MohammedLab-PS5-source/upstream/KytyPS5/CMakeLists.txt',
            'MohammedLab-PS5-source/upstream/KytyPS5/src/main.cpp',
            'MohammedLab-PS5-source/upstream/KytyPS5/3rdparty/SDL3/CMakeLists.txt',
            'MohammedLab-PS5-source/build-manifest.txt'
        )) {
            if ($requiredEntry -notin $sourceEntries) {
                throw "Required recursive source archive entry missing: $requiredEntry"
            }
        }
    }
    finally {
        $sourceArchive.Dispose()
    }

    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $output 'build-manifest.txt')
}
finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
