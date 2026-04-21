#!/usr/bin/env bash
# scripts/build-installer.ps1 equivalent for PowerShell
# Usage: pwsh scripts/build-installer.ps1
#
# Builds the Flutter Windows MSIX installer for offline_School desktop.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ROOT = Split-Path -Parent $PSScriptRoot
$APP_DIR = Join-Path $ROOT "apps\desktop_app"

Write-Host "Building offline_School Windows installer..." -ForegroundColor Cyan

Push-Location $APP_DIR

# Ensure deps are up to date
flutter pub get

# Generate Drift code (if not already generated)
flutter pub run build_runner build --delete-conflicting-outputs

# Build the Windows release
flutter build windows --release

# Package as MSIX
flutter pub run msix:create

$msixPath = Join-Path $APP_DIR "build\windows\runner\Release\offline_school.msix"
if (Test-Path $msixPath) {
    Write-Host "`nInstaller created: $msixPath" -ForegroundColor Green
} else {
    Write-Error "MSIX not found. Check build output above."
}

Pop-Location
