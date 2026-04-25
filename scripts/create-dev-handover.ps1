param(
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not $OutputPath -or [string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "artifacts\developer-handover-$timestamp.zip"
}

$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDir = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("offline-school-dev-handover-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

$includePaths = @(
    'README.md',
    'CONTRIBUTING.md',
    '.gitignore',
    'apps',
    'backend',
    'docs',
    'infra',
    'packages',
    'scripts'
)

$excludedDirectoryNames = @(
    '.git',
    '.dart_tool',
    '.idea',
    '.plugin_symlinks',
    '.vscode',
    '.yarn',
    '.npm',
    '.pub',
    '.pub-cache',
    'ephemeral',
    'node_modules',
    'dist',
    'build',
    'coverage',
    'secrets'
)

$excludedFileNames = @(
    '.metadata',
    '.DS_Store',
    'Thumbs.db',
    'Desktop.ini'
)

$excludedExtensions = @(
    '.db',
    '.sqlite',
    '.sqlite3',
    '.msix',
    '.msi',
    '.exe',
    '.appxbundle',
    '.pem',
    '.p12',
    '.pfx',
    '.key',
    '.crt',
    '.cer',
    '.log'
)

$excludedWildcardPatterns = @(
    '.env',
    '.env.*',
    '.flutter-plugins',
    '.flutter-plugins-dependencies',
    '.packages',
    'npm-debug.log*',
    'yarn-debug.log*',
    'yarn-error.log*',
    'pnpm-debug.log*',
    '*.suo',
    '*.ntvs*',
    '*.iml',
    '*.njsproj',
    '*.sln',
    '*.sw?'
)

$sourceExtensions = @(
    '.ts',
    '.tsx',
    '.js',
    '.jsx',
    '.dart',
    '.py',
    '.java',
    '.kt',
    '.swift',
    '.go',
    '.rs',
    '.cs',
    '.cpp',
    '.c',
    '.h',
    '.hpp',
    '.json',
    '.yaml',
    '.yml',
    '.sql',
    '.html',
    '.css',
    '.scss',
    '.md'
)

function Test-ShouldExcludeFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    if ($excludedFileNames -contains $File.Name) {
        return $true
    }

    if ($excludedExtensions -contains $File.Extension.ToLowerInvariant()) {
        return $true
    }

    foreach ($pattern in $excludedWildcardPatterns) {
        if ($File.Name -like $pattern) {
            return $true
        }
    }

    return $false
}

function Copy-IncludedTree {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRelativePath
    )

    $sourcePath = Join-Path $repoRoot $SourceRelativePath
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        return
    }

    $item = Get-Item -LiteralPath $sourcePath
    $destinationPath = Join-Path $tempRoot $SourceRelativePath

    if ($item.PSIsContainer) {
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null

        Get-ChildItem -LiteralPath $sourcePath -Recurse -Force | ForEach-Object {
            $relativePath = $_.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
            if ([string]::IsNullOrWhiteSpace($relativePath) -or $relativePath -eq '.') {
                return
            }

            $pathSegments = $relativePath -split '[\\/]'
            $matchedExcludedDirectories = @(
                $pathSegments | Where-Object { $excludedDirectoryNames -contains $_ }
            )
            if ($matchedExcludedDirectories.Count -gt 0) {
                return
            }

            $targetPath = Join-Path $tempRoot $relativePath
            if ($_.PSIsContainer) {
                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
                return
            }

            if (Test-ShouldExcludeFile -File $_) {
                return
            }

            $targetParent = Split-Path -Parent $targetPath
            if (-not (Test-Path -LiteralPath $targetParent)) {
                New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            }

            Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Force
        }

        return
    }

    if (Test-ShouldExcludeFile -File $item) {
        return
    }

    $targetParent = Split-Path -Parent $destinationPath
    if (-not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
    }

    Copy-Item -LiteralPath $item.FullName -Destination $destinationPath -Force
}

function Get-FileStats {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $allFiles = @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Force)
    $sourceFiles = @(
        $allFiles | Where-Object {
            $sourceExtensions -contains $_.Extension.ToLowerInvariant()
        }
    )

    return [PSCustomObject]@{
        TotalFiles  = $allFiles.Count
        SourceFiles = $sourceFiles.Count
    }
}

try {
    foreach ($relativePath in $includePaths) {
        Copy-IncludedTree -SourceRelativePath $relativePath
    }

    $copiedStats = Get-FileStats -RootPath $tempRoot
    if ($copiedStats.SourceFiles -eq 0) {
        throw "No source files were collected for handover. Check include/exclude rules in scripts/create-dev-handover.ps1."
    }

    if (Test-Path -LiteralPath $resolvedOutputPath) {
        Remove-Item -LiteralPath $resolvedOutputPath -Force
    }

    Compress-Archive -Path (Join-Path $tempRoot '*') -DestinationPath $resolvedOutputPath -CompressionLevel Optimal

    Write-Host "Created developer handover ZIP:"
    Write-Host "  $resolvedOutputPath"
    Write-Host "  Files included: $($copiedStats.TotalFiles)"
    Write-Host "  Source-like files included: $($copiedStats.SourceFiles)"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
