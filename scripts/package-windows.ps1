param(
    [Parameter(Mandatory = $true)][string]$InstallDirectory,
    [Parameter(Mandatory = $true)][string]$VcpkgInstallDirectory,
    [Parameter(Mandatory = $true)][string]$SwiftShaderLicensePath,
    [Parameter(Mandatory = $true)][string]$SourceDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [Parameter(Mandatory = $true)][string]$Commit
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$install = (Resolve-Path -LiteralPath $InstallDirectory).Path
$vcpkgInstall = (Resolve-Path -LiteralPath $VcpkgInstallDirectory).Path
$swiftShaderLicense = (Resolve-Path -LiteralPath $SwiftShaderLicensePath).Path
$source = (Resolve-Path -LiteralPath $SourceDirectory).Path
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
$engine = Join-Path $source 'upstream/KytyPS5'
$upstreamSha = 'b3e419ff1101999525fa2d061ada1d102cf788b1'
$vcpkgSha = '9624c70bcc649d9ecff24185a72b12e0001de6f7'
$ffmpegArchiveSha256 = '32839a244a418063f6fb4bbe55585bc66ea17a859b920cae0e3aa1eab9398c09'
$patchPaths = @(
    'patches/upstream/0001-mohammedlab-launcher.patch',
    'patches/upstream/0002-ffmpeg-source-lock.patch',
    'patches/upstream/0003-vulkan-extent-initializers.patch',
    'patches/upstream/0004-label-vulkan-device-tests.patch',
    'patches/ci/0001-swiftshader-no-mp-for-clang-cl.patch'
)

if (-not (Test-Path -LiteralPath (Join-Path $engine 'CMakeLists.txt'))) {
    throw 'Pinned KytyPS5 source is missing'
}
if ((git -C $engine rev-parse HEAD) -ne $upstreamSha) {
    throw 'Pinned KytyPS5 source commit does not match upstream.lock'
}
if ($env:VCPKG_COMMIT -ne $vcpkgSha -or $env:GLSLANG_PACKAGE -notmatch '16\.1\.0') {
    throw "Unexpected vcpkg/glslang versions: $env:VCPKG_COMMIT / $env:GLSLANG_PACKAGE"
}
$patchHashes = foreach ($relativePath in $patchPaths) {
    $patch = Join-Path $source $relativePath
    if (-not (Test-Path -LiteralPath $patch -PathType Leaf)) {
        throw "Required source patch missing: $relativePath"
    }
    $digest = (Get-FileHash -LiteralPath $patch -Algorithm SHA256).Hash.ToLowerInvariant()
    "$relativePath SHA256=$digest"
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
if (-not (Test-Path -LiteralPath (Join-Path $engine 'LICENSES/Kyty-MIT.txt') -PathType Leaf)) {
    throw 'Original Kyty MIT notice is missing'
}
$ffmpegLicenseDirectory = Join-Path $install 'licenses/ffmpeg'
foreach ($relativePath in @('copyright', 'SOURCE.txt', 'build-log.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ffmpegLicenseDirectory $relativePath) -PathType Leaf)) {
        throw "Required FFmpeg license/provenance file missing: licenses/ffmpeg/$relativePath"
    }
}
$qtRoot = [System.IO.Path]::GetFullPath((Join-Path $env:Qt6_DIR '..\..\..'))
$qtLicensesAtInstallRoot = Join-Path $qtRoot 'licenses'
$qtLicensesAtQtRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $env:Qt6_DIR '..\..\..\..\..\Licenses'))
$qtLicenseRoot = @($qtLicensesAtInstallRoot, $qtLicensesAtQtRoot) |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    Select-Object -First 1
if (-not $qtLicenseRoot) {
    throw "Qt license directory is missing; checked $qtLicensesAtInstallRoot and $qtLicensesAtQtRoot"
}
$qtLicenseFiles = @(Get-ChildItem -LiteralPath $qtLicenseRoot -Force -Recurse -File |
    Where-Object { $_.Name -match '^(LICENSE|LICENCE|COPYING|NOTICE)(\..*)?$' })
if ($qtLicenseFiles.Count -eq 0) {
    throw 'No Qt license notices found in the pinned Qt installation'
}
$vcpkgLicenseFiles = @(Get-ChildItem -LiteralPath (Join-Path $vcpkgInstall 'share') `
        -Directory -Force |
    ForEach-Object {
        $license = Join-Path $_.FullName 'copyright'
        if (Test-Path -LiteralPath $license -PathType Leaf) {
            Get-Item -LiteralPath $license
        }
    })
$requiredVcpkgLicenses = @(
    'glslang', 'spirv-tools', 'spirv-headers', 'vulkan-tools', 'vulkan-loader', 'volk', 'vulkan-headers'
)
foreach ($packageName in $requiredVcpkgLicenses) {
    if (-not ($vcpkgLicenseFiles | Where-Object {
        $_.Directory.Name -ieq $packageName
    })) {
        throw "Required vcpkg license notice is missing: $packageName"
    }
}

if (Test-Path -LiteralPath $output) {
    Remove-Item -LiteralPath $output -Recurse -Force
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("MohammedLabPS5-" + [guid]::NewGuid())
$package = Join-Path $stage 'package'
$licenseDestination = Join-Path $package 'licenses/third-party'
New-Item -ItemType Directory -Path $licenseDestination -Force | Out-Null
$qtLicenseDestination = Join-Path $package 'licenses/Qt'
New-Item -ItemType Directory -Path $qtLicenseDestination -Force | Out-Null
$vcpkgLicenseDestination = Join-Path $package 'licenses/vcpkg'
New-Item -ItemType Directory -Path $vcpkgLicenseDestination -Force | Out-Null

try {
    Get-ChildItem -LiteralPath $install -Force |
        Copy-Item -Destination $package -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $source 'README-EN.md') -Destination $package
    Copy-Item -LiteralPath (Join-Path $source 'README-AR.md') -Destination $package
    Copy-Item -LiteralPath (Join-Path $engine 'LICENSE') -Destination (Join-Path $package 'LICENSE')
    Copy-Item -LiteralPath (Join-Path $engine 'LICENSES/Kyty-MIT.txt') `
        -Destination (Join-Path $package 'LICENSES-Kyty-MIT.txt')
    $swiftShaderLicenseDestination = Join-Path $package 'licenses/SwiftShader/LICENSE.txt'
    New-Item -ItemType Directory -Path (Split-Path -Parent $swiftShaderLicenseDestination) -Force | Out-Null
    Copy-Item -LiteralPath $swiftShaderLicense -Destination $swiftShaderLicenseDestination

    foreach ($license in $licenseFiles) {
        $relative = [System.IO.Path]::GetRelativePath($engine, $license.FullName)
        $destination = Join-Path $licenseDestination $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $license.FullName -Destination $destination
    }
    foreach ($license in $qtLicenseFiles) {
        $relative = [System.IO.Path]::GetRelativePath($qtLicenseRoot, $license.FullName)
        $destination = Join-Path $qtLicenseDestination $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $license.FullName -Destination $destination
    }
    foreach ($license in $vcpkgLicenseFiles) {
        $relative = [System.IO.Path]::GetRelativePath(
            (Join-Path $vcpkgInstall 'share'), $license.Directory.FullName)
        $destination = Join-Path (Join-Path $vcpkgLicenseDestination $relative) 'copyright'
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $license.FullName -Destination $destination
    }

    $toolchain = @(
        "Windows runner: windows-2022",
        "Qt: 6.10.3 (MSVC 2022 x64)",
        "vcpkg commit: $env:VCPKG_COMMIT",
        "glslang port: $env:GLSLANG_PACKAGE",
        "Vulkan tools: $env:VULKAN_TOOLS_PACKAGE",
        "Vulkan loader: $env:VULKAN_LOADER_PACKAGE",
        "SwiftShader test ICD source: $env:SWIFTSHADER_COMMIT",
        'SwiftShader Apache-2.0 license is included; its ICD is not bundled.',
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
        "Pinned vcpkg revision: $vcpkgSha",
        "Pinned glslang version: 16.1.0 with tools,opt features; MSYS2 runtime 3.6.5-1 is SHA-512 locked in upstream.lock; vcpkg copyright notices are included under licenses/vcpkg",
        "CI-only Vulkan probe: vulkan-tools 1.4.328.0 and SwiftShader source $((Get-Content (Join-Path $source 'upstream.lock') | Select-String 'google/swiftshader' | ForEach-Object { $_.ToString().Trim() }))",
        'The software Vulkan ICD and vulkaninfo test utility are CI-only and are not bundled in this application ZIP.',
        "Pinned FFmpeg recipe/source: ext-ffmpeg-core 9ac4cfd195f192ed8b08566f49c28dbb48d08341",
        "FFmpeg Windows x64 archive SHA256: $ffmpegArchiveSha256",
        'Emulator: upstream kyty_emulator.exe built from the pinned source',
        'No Sony firmware, SDK, keys, or games are included.',
        '',
        'Tracked source patch SHA-256:',
        $patchHashes,
        '',
        'Toolchain:',
        $toolchain,
        '',
        'Recursive submodules:',
        $submodules,
        '',
        'Qt runtime license texts and FFmpeg license/provenance files are included under licenses/.'
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

    $sourceArchive = [System.IO.Compression.ZipFile]::Open(
        $sourceZip, [System.IO.Compression.ZipArchiveMode]::Update
    )
    try {
        $swiftShaderEntry = $sourceArchive.CreateEntry(
            'MohammedLab-PS5-source/licenses/SwiftShader/LICENSE.txt',
            [System.IO.Compression.CompressionLevel]::Optimal
        )
        $swiftShaderEntryStream = $swiftShaderEntry.Open()
        $swiftShaderInputStream = [System.IO.File]::OpenRead($swiftShaderLicense)
        try {
            $swiftShaderInputStream.CopyTo($swiftShaderEntryStream)
        }
        finally {
            $swiftShaderInputStream.Dispose()
            $swiftShaderEntryStream.Dispose()
        }
        foreach ($license in $qtLicenseFiles) {
            $relative = [System.IO.Path]::GetRelativePath($qtLicenseRoot, $license.FullName)
            $entryName = "MohammedLab-PS5-source/licenses/Qt/$($relative -replace '\\', '/')"
            $entry = $sourceArchive.CreateEntry(
                $entryName, [System.IO.Compression.CompressionLevel]::Optimal
            )
            $entryStream = $entry.Open()
            $inputStream = [System.IO.File]::OpenRead($license.FullName)
            try {
                $inputStream.CopyTo($entryStream)
            }
            finally {
                $inputStream.Dispose()
                $entryStream.Dispose()
            }
        }
        foreach ($relativePath in @('copyright', 'SOURCE.txt', 'build-log.txt')) {
            $licensePath = Join-Path $ffmpegLicenseDirectory $relativePath
            $entryName = "MohammedLab-PS5-source/licenses/ffmpeg/$relativePath"
            $entry = $sourceArchive.CreateEntry(
                $entryName, [System.IO.Compression.CompressionLevel]::Optimal
            )
            $entryStream = $entry.Open()
            $inputStream = [System.IO.File]::OpenRead($licensePath)
            try {
                $inputStream.CopyTo($entryStream)
            }
            finally {
                $inputStream.Dispose()
                $entryStream.Dispose()
            }
        }
        foreach ($license in $vcpkgLicenseFiles) {
            $relative = [System.IO.Path]::GetRelativePath(
                (Join-Path $vcpkgInstall 'share'), $license.Directory.FullName)
            $entryName = "MohammedLab-PS5-source/licenses/vcpkg/$($relative -replace '\\', '/')/copyright"
            $entry = $sourceArchive.CreateEntry(
                $entryName, [System.IO.Compression.CompressionLevel]::Optimal
            )
            $entryStream = $entry.Open()
            $inputStream = [System.IO.File]::OpenRead($license.FullName)
            try {
                $inputStream.CopyTo($entryStream)
            }
            finally {
                $inputStream.Dispose()
                $entryStream.Dispose()
            }
        }
    }
    finally {
        $sourceArchive.Dispose()
    }

    foreach ($zip in @($binaryZip, $sourceZip)) {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
        try {
            if ($archive.Entries.Count -eq 0) {
                throw "Archive is empty: $zip"
            }
            foreach ($entry in $archive.Entries) {
                $entryStream = $entry.Open()
                try {
                    $entryStream.CopyTo([System.IO.Stream]::Null)
                }
                finally {
                    $entryStream.Dispose()
                }
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
            'LICENSES-Kyty-MIT.txt', 'licenses/Qt/', 'licenses/ffmpeg/copyright',
            'licenses/ffmpeg/SOURCE.txt', 'licenses/ffmpeg/build-log.txt',
            'licenses/vcpkg/glslang/copyright',
            'licenses/vcpkg/spirv-tools/copyright',
            'licenses/vcpkg/spirv-headers/copyright',
            'licenses/vcpkg/vulkan-tools/copyright',
            'licenses/vcpkg/vulkan-loader/copyright',
            'licenses/vcpkg/volk/copyright',
            'licenses/vcpkg/vulkan-headers/copyright',
            'licenses/SwiftShader/LICENSE.txt'
        )) {
            if ($requiredEntry.EndsWith('/') -and
                -not ($entries | Where-Object { $_.StartsWith($requiredEntry) })) {
                throw "Required Windows archive directory missing: $requiredEntry"
            }
            if (-not $requiredEntry.EndsWith('/') -and $requiredEntry -notin $entries) {
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
            'MohammedLab-PS5-source/upstream/KytyPS5/src/launcher/src/launcherLanguage.cpp',
            'MohammedLab-PS5-source/upstream/KytyPS5/3rdparty/SDL3/CMakeLists.txt',
            'MohammedLab-PS5-source/upstream/KytyPS5/3rdparty/ffmpeg-core/CMakeLists.txt',
            'MohammedLab-PS5-source/patches/upstream/0001-mohammedlab-launcher.patch',
            'MohammedLab-PS5-source/patches/upstream/0002-ffmpeg-source-lock.patch',
            'MohammedLab-PS5-source/patches/upstream/0003-vulkan-extent-initializers.patch',
            'MohammedLab-PS5-source/patches/upstream/0004-label-vulkan-device-tests.patch',
            'MohammedLab-PS5-source/patches/ci/0001-swiftshader-no-mp-for-clang-cl.patch',
            'MohammedLab-PS5-source/licenses/vcpkg/vulkan-tools/copyright',
            'MohammedLab-PS5-source/licenses/vcpkg/vulkan-loader/copyright',
            'MohammedLab-PS5-source/licenses/vcpkg/volk/copyright',
            'MohammedLab-PS5-source/licenses/vcpkg/vulkan-headers/copyright',
            'MohammedLab-PS5-source/licenses/SwiftShader/LICENSE.txt',
            'MohammedLab-PS5-source/scripts/apply-upstream-patches.ps1',
            'MohammedLab-PS5-source/upstream.lock',
            'MohammedLab-PS5-source/licenses/vcpkg/glslang/copyright',
            'MohammedLab-PS5-source/licenses/vcpkg/spirv-tools/copyright',
            'MohammedLab-PS5-source/licenses/vcpkg/spirv-headers/copyright',
            'MohammedLab-PS5-source/licenses/ffmpeg/copyright',
            'MohammedLab-PS5-source/licenses/ffmpeg/SOURCE.txt',
            'MohammedLab-PS5-source/licenses/ffmpeg/build-log.txt',
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
