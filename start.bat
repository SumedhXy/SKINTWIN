@echo off
setlocal

set "ROOT=%~dp0"
set "BACKEND=%ROOT%backend"
set "FRONTEND=%ROOT%frontend"

if not exist "%BACKEND%\.venv\Scripts\python.exe" (
    echo Backend virtual environment not found: %BACKEND%\.venv
    pause
    exit /b 1
)

where flutter >nul 2>&1
if errorlevel 1 (
    echo Flutter was not found on PATH.
    pause
    exit /b 1
)

start "SkinTwin Backend" cmd /k "cd /d "%BACKEND%" && .venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000"
start "SkinTwin Frontend" cmd /k "cd /d "%FRONTEND%" && flutter pub get && flutter run -d chrome --web-port 8082"

echo SkinTwin services are starting.
echo Backend:  http://127.0.0.1:8000
 echo Frontend: http://localhost:8082
endlocal
