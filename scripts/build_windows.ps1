<#
.SYNOPSIS
    YTDx Studio - Modern PowerShell Windows Package Builder
#>

param(
    [string]$Target = "x64"
)

$ErrorActionPreference = "Stop"
$Version = "1.0.0"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\.."
$DistDir = "$ProjectRoot\dist"
$StageDir = "$DistDir\YTDx-Studio-$Version-Windows-$Target"
$ZipName = "YTDx-Studio-$Version-Windows-$Target.zip"
$AuraDir = "$ProjectRoot\aura_app"
$ReleaseDir = "$AuraDir\build\windows\$Target\runner\Release"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "⚡ YTDx Studio - Windows Release Paketleyici ($Target)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Set-Location $ProjectRoot

# 1. Python Environment
Write-Host "`n[1/4] 🐍 Python Bağımlılıkları Kontrol Ediliyor..." -ForegroundColor Yellow
if (-not (Test-Path ".venv")) {
    python -m venv .venv
}
& .venv\Scripts\python.exe -m pip install --upgrade pip --quiet
& .venv\Scripts\python.exe -m pip install -r requirements.txt --quiet
Write-Host "   -> ✓ Python ortamı hazır." -ForegroundColor Green

# 2. Flutter Build
Write-Host "`n[2/4] 🚀 Flutter Windows Release Derleniyor ($Target)..." -ForegroundColor Yellow
Set-Location $AuraDir
flutter pub get
flutter build windows --release

# 3. Staging
Write-Host "`n[3/4] 📦 Dağıtım Klasörü Hazırlanıyor..." -ForegroundColor Yellow
Set-Location $ProjectRoot
if (Test-Path $StageDir) { Remove-Item -Recurse -Force $StageDir }
New-Item -ItemType Directory -Force -Path $StageDir | Out-Null
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Copy-Item -Recurse -Force "$ReleaseDir\*" $StageDir\
Copy-Item -Recurse -Force "src" $StageDir\src
Copy-Item -Recurse -Force "icons" $StageDir\icons
Copy-Item -Force "requirements.txt" $StageDir\requirements.txt
Copy-Item -Force "main.py" $StageDir\main.py
Copy-Item -Force "LICENSE" $StageDir\LICENSE
Copy-Item -Force "README.md" $StageDir\README.md

# 4. Zip Archive
Write-Host "`n[4/4] 🗜️ Dağıtım ZIP Arşivi Oluşturuluyor..." -ForegroundColor Yellow
Compress-Archive -Path "$StageDir\*" -DestinationPath "$DistDir\$ZipName" -Force
$ZipSize = (Get-Item "$DistDir\$ZipName").Length / 1MB

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "🎉 Windows Paketi Başarıyla Üretildi!" -ForegroundColor Green
Write-Host "📁 Dosya: $DistDir\$ZipName ($([math]::Round($ZipSize, 2)) MB)" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Green
