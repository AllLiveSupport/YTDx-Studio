@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo   YTDx Studio - Windows Release Build & Package Script
echo ============================================================

set "VERSION=1.0.0"
set "PROJECT_ROOT=%~dp0.."
set "DIST_DIR=%PROJECT_ROOT%\dist"
set "STAGE_DIR=%DIST_DIR%\YTDx-Studio-%VERSION%-Windows-x64"
set "AURA_DIR=%PROJECT_ROOT%\aura_app"
set "RELEASE_DIR=%AURA_DIR%\build\windows\x64\runner\Release"

cd /d "%PROJECT_ROOT%"

echo.
echo [1/4] Python Sanal Ortami Hazirlaniyor...
if not exist ".venv" (
    python -m venv .venv
)
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
echo [OK] Python bagimliliklari guncellendi.

echo.
echo [2/4] Flutter Windows Release Derleniyor...
cd /d "%AURA_DIR%"
call flutter pub get
call flutter build windows --release
if errorlevel 1 (
    echo [HATA] Flutter Windows derlemesi basarisiz oldu.
    pause
    exit /b 1
)

echo.
echo [3/4] Dagitim Paketi Hazirlaniyor...
cd /d "%PROJECT_ROOT%"
if exist "%STAGE_DIR%" rmdir /s /q "%STAGE_DIR%"
mkdir "%STAGE_DIR%"
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

xcopy /E /I /Y "%RELEASE_DIR%\*" "%STAGE_DIR%\"
xcopy /E /I /Y "src" "%STAGE_DIR%\src\"
xcopy /E /I /Y "icons" "%STAGE_DIR%\icons\"
copy /Y "requirements.txt" "%STAGE_DIR%\"
copy /Y "main.py" "%STAGE_DIR%\"
copy /Y "LICENSE" "%STAGE_DIR%\"
copy /Y "README.md" "%STAGE_DIR%\"

echo.
echo [4/4] ZIP Arsivi Olusturuluyor...
powershell -Command "Compress-Archive -Path '%STAGE_DIR%\*' -DestinationPath '%DIST_DIR%\YTDx-Studio-%VERSION%-Windows-x64.zip' -Force"

echo.
echo ============================================================
echo   TEBRIKLER! Windows Paketi Basariyla Uretildi:
echo   %DIST_DIR%\YTDx-Studio-%VERSION%-Windows-x64.zip
echo ============================================================
pause
