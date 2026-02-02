@echo off
echo ========================================
echo Deploying SOTA Addon
echo ========================================
echo.

REM Определяем пути
set "SOURCE_DIR=%~dp0SotA"
set "TARGET_DIR=F:\Game\WOW Turtle\twmoa_1180 — копия\Interface\AddOns\SOTA"
set "SAVED_VARS_DIR=F:\Game\WOW Turtle\twmoa_1180 — копия\WTF\Account\LOGOSHH\SavedVariables"
set "SAVED_VARS_FILE=%SAVED_VARS_DIR%\SOTA.lua"

REM Проверяем существование исходной папки
if not exist "%SOURCE_DIR%" (
    echo ERROR: Source directory not found: %SOURCE_DIR%
    pause
    exit /b 1
)

REM Создаем целевую папку, если её нет
if not exist "%TARGET_DIR%" (
    echo Creating target directory: %TARGET_DIR%
    mkdir "%TARGET_DIR%"
)

REM Копируем все файлы из SotA в целевую папку
echo.
echo Copying files from %SOURCE_DIR% to %TARGET_DIR%...
xcopy /E /Y /I "%SOURCE_DIR%\*" "%TARGET_DIR%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✓ Files copied successfully!
) else (
    echo.
    echo ✗ Error copying files!
    pause
    exit /b 1
)

REM Удаляем файл SOTA.lua из SavedVariables
echo.
echo Checking for SavedVariables file...
REM Используем PowerShell для поиска и удаления файла по имени
powershell -NoProfile -ExecutionPolicy Bypass -Command "$base = 'F:\Game\WOW Turtle'; $dirs = Get-ChildItem $base -Directory; $target = $dirs | Where-Object { $_.Name -match 'twmoa' -or $_.Name -match '1180' }; if ($target) { $savedVarsDir = Join-Path $target.FullName 'WTF\Account\LOGOSHH\SavedVariables'; $file = Get-ChildItem -Path $savedVarsDir -Filter 'SOTA.lua' -ErrorAction SilentlyContinue; if ($file) { Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 100; if (-not (Test-Path $file.FullName)) { Write-Host 'SavedVariables file deleted successfully!' } else { Write-Host 'Error: File still exists' } } else { Write-Host 'SavedVariables file not found' } }"

echo.
echo ========================================
echo Deployment completed!
echo ========================================
echo.
pause
