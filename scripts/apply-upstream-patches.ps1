$ErrorActionPreference = 'Stop'

$repository = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$engine = Join-Path $repository 'upstream/KytyPS5'
$ffmpeg = Join-Path $engine '3rdparty/ffmpeg-core'
$expectedEngine = 'b3e419ff1101999525fa2d061ada1d102cf788b1'
$expectedFfmpeg = '9ac4cfd195f192ed8b08566f49c28dbb48d08341'
$enginePatch = Join-Path $repository 'patches/upstream/0001-mohammedlab-launcher.patch'
$ffmpegPatch = Join-Path $repository 'patches/upstream/0002-ffmpeg-source-lock.patch'
$extentPatch = Join-Path $repository 'patches/upstream/0003-vulkan-extent-initializers.patch'
$vulkanTestsPatch = Join-Path $repository 'patches/upstream/0004-label-vulkan-device-tests.patch'

if (-not (Test-Path -LiteralPath (Join-Path $engine 'CMakeLists.txt')) -or
    -not (Test-Path -LiteralPath (Join-Path $ffmpeg 'CMakeLists.txt'))) {
    throw 'Recursive source files are missing; initialize submodules or restore the complete source archive'
}
foreach ($patch in @($enginePatch, $ffmpegPatch, $extentPatch, $vulkanTestsPatch)) {
    if (-not (Test-Path -LiteralPath $patch -PathType Leaf)) {
        throw "Required upstream patch is missing: $patch"
    }
}

$lock = Get-Content -LiteralPath (Join-Path $repository 'upstream.lock') -Raw
foreach ($revision in @($expectedEngine, $expectedFfmpeg)) {
    if (-not $lock.Contains($revision)) {
        throw "Expected source revision $revision is missing from upstream.lock"
    }
}

$engineRevision = & git -C $engine rev-parse HEAD 2>$null
$hasGitMetadata = $LASTEXITCODE -eq 0
if ($hasGitMetadata) {
    if ($engineRevision.Trim() -ne $expectedEngine) {
        throw 'KytyPS5 checkout does not match the pinned source revision'
    }
    $ffmpegRevision = & git -C $ffmpeg rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or $ffmpegRevision.Trim() -ne $expectedFfmpeg) {
        throw 'FFmpeg source checkout does not match the pinned submodule revision'
    }
    $submoduleStatus = git -C $engine status --porcelain --ignore-submodules=none
    if ($LASTEXITCODE -ne 0 -or $submoduleStatus) {
        throw "Refusing to patch a dirty recursive source checkout:`n$submoduleStatus"
    }
} elseif ((Test-Path -LiteralPath (Join-Path $engine '.git')) -or
    (Test-Path -LiteralPath (Join-Path $repository '.git'))) {
    throw 'Git metadata is incomplete; use a clean recursive checkout or a source archive'
}

foreach ($item in @(
    @{ Root = $engine; Patch = $enginePatch; Name = 'KytyPS5' },
    @{ Root = $ffmpeg; Patch = $ffmpegPatch; Name = 'FFmpeg' },
    @{ Root = $engine; Patch = $extentPatch; Name = 'Vulkan extent initializer' },
    @{ Root = $engine; Patch = $vulkanTestsPatch; Name = 'Vulkan-dependent CTest labels' }
)) {
    & git -C $item.Root apply --check $item.Patch 2>$null
    if ($LASTEXITCODE -eq 0) {
        & git -C $item.Root apply $item.Patch
        if ($LASTEXITCODE -ne 0) {
            throw "Could not apply the $($item.Name) patch"
        }
        continue
    }

    if (-not $hasGitMetadata) {
        & git -C $item.Root apply --reverse --check $item.Patch 2>$null
        if ($LASTEXITCODE -eq 0) {
            continue
        }
    }
    throw "$($item.Name) patch does not match the source or is already applied"
}
if ($hasGitMetadata) {
    & git -C $engine diff --check
    if ($LASTEXITCODE -ne 0) {
        throw 'Patched KytyPS5 source contains whitespace errors'
    }
    & git -C $ffmpeg diff --check
    if ($LASTEXITCODE -ne 0) {
        throw 'Patched FFmpeg source contains whitespace errors'
    }
}
