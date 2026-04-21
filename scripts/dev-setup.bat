@echo off
REM scripts\dev-setup.bat
REM Run once after cloning: scripts\dev-setup.bat
REM Sets up all workspaces for local development on Windows.

setlocal enabledelayedexpansion

set ROOT=%~dp0..
echo.
echo offline_School dev setup
echo Root: %ROOT%

REM ─── Check prerequisites ────────────────────────────────────────────────────
echo.
echo -- Checking prerequisites

where node >nul 2>&1
if %errorlevel%==0 (
    for /f "tokens=*" %%v in ('node --version') do echo [OK] Node.js %%v
) else (
    echo [WARN] Node.js not found. Install from https://nodejs.org
)

where npm >nul 2>&1
if %errorlevel%==0 (
    echo [OK] npm found
) else (
    echo [WARN] npm not found
)

where flutter >nul 2>&1
if %errorlevel%==0 (
    echo [OK] flutter found
) else (
    echo [WARN] Flutter not found. Install from https://flutter.dev
)

where docker >nul 2>&1
if %errorlevel%==0 (
    echo [OK] docker found
) else (
    echo [WARN] Docker not found — start PostgreSQL and Redis manually
)

REM ─── Backend ────────────────────────────────────────────────────────────────
echo.
echo -- Installing backend dependencies
cd /d "%ROOT%\backend"
call npm install
if %errorlevel%==0 (
    echo [OK] Backend npm install complete
) else (
    echo [ERROR] npm install failed in backend
    exit /b 1
)

if not exist "%ROOT%\backend\.env" (
    copy "%ROOT%\backend\.env.example" "%ROOT%\backend\.env" >nul
    echo [OK] Created backend\.env from .env.example
) else (
    echo [OK] backend\.env already exists
)

REM ─── Flutter apps ───────────────────────────────────────────────────────────
where flutter >nul 2>&1
if %errorlevel%==0 (
    echo.
    echo -- Installing Flutter desktop app dependencies
    cd /d "%ROOT%\apps\desktop_app"
    call flutter pub get
    if %errorlevel%==0 (
        echo [OK] desktop_app pub get complete
    ) else (
        echo [WARN] flutter pub get failed
    )

    echo -- Generating Drift database code
    call flutter pub run build_runner build --delete-conflicting-outputs
    if %errorlevel%==0 (
        echo [OK] Drift code generation complete
    ) else (
        echo [WARN] Drift code gen failed. Run manually: flutter pub run build_runner build
    )
) else (
    echo [WARN] Flutter not found -- skipping Flutter setup
)

REM ─── Local services (Docker) ────────────────────────────────────────────────
where docker >nul 2>&1
if %errorlevel%==0 (
    echo.
    echo -- Starting local services (PostgreSQL + Redis)
    cd /d "%ROOT%\infra"
    call docker compose up -d
    echo [OK] PostgreSQL and Redis started
) else (
    echo [WARN] Docker not found -- start PostgreSQL and Redis manually
)

REM ─── Summary ────────────────────────────────────────────────────────────────
echo.
echo Setup complete!
echo.
echo   Backend:  cd backend ^&^& npm run start:dev
echo   Desktop:  cd apps\desktop_app ^&^& flutter run -d windows
echo   Health:   curl http://localhost:3000/health
echo.
echo   See README.md and docs\05-roadmap.md for next steps.
echo.
endlocal
