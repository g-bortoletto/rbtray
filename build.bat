@echo off
setlocal enabledelayedexpansion

:: RBTray Build Script
:: Compiles RBTray.exe and RBHook.dll using Visual Studio C++ Build Tools

:: ============================================================================
:: Configuration
:: ============================================================================

set "MODE=%1"
set "ARCH=%2"

:: Show usage if help is requested
if /i "%1"=="/?" goto :usage
if /i "%1"=="-h" goto :usage
if /i "%1"=="--help" goto :usage
if /i "%1"=="help" goto :usage

if "%MODE%"=="" set "MODE=release"
if "%ARCH%"=="" set "ARCH=x86"

:: Normalize input
if not "%MODE%"=="" set "MODE=%MODE:~0,1%"
if /i "%MODE%"=="d" set "MODE=debug"
if /i "%MODE%"=="r" set "MODE=release"

:: ============================================================================
:: Locate Visual Studio Build Tools
:: ============================================================================

echo [RBTray Build] Searching for Visual Studio Build Tools...

:: Try common VS 2022 installations
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        set "VSINSTALLDIR=%%i"
    )
)

if not defined VSINSTALLDIR (
    echo ERROR: Visual Studio Build Tools not found!
    echo Please install "Desktop development with C++" from Visual Studio Installer.
    exit /b 1
)

:: Initialize VS environment
if /i "%ARCH%"=="x64" (
    call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul
    if errorlevel 1 (
        echo ERROR: Failed to initialize Visual Studio x64 build environment.
        exit /b 1
    )
    set "OUTDIR=x64"
    set "MACHINE=X64"
) else (
    call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvars32.bat" >nul
    if errorlevel 1 (
        echo ERROR: Failed to initialize Visual Studio x86 build environment.
        exit /b 1
    )
    set "OUTDIR=x86"
    set "MACHINE=X86"
)

echo [RBTray Build] Using: %VSINSTALLDIR%
echo [RBTray Build] Architecture: %ARCH%
echo [RBTray Build] Mode: %MODE%
echo.

:: ============================================================================
:: Build Configuration
:: ============================================================================

:: Common compiler flags
set "CL_COMMON=/nologo /W3 /EHsc /DUNICODE /D_UNICODE /DWIN32 /D_WINDOWS"

:: Common linker flags
set "LINK_COMMON=/NOLOGO /SUBSYSTEM:WINDOWS /MACHINE:%MACHINE%"

:: Resource compiler
set "RC_FLAGS=/nologo"

if /i "%MODE%"=="debug" (
    :: Debug mode: No optimization, debug info, runtime checks
    set "CL_FLAGS=/Od /Zi /RTC1 /D_DEBUG /MTd"
if not exist "%OUTDIR%" mkdir "%OUTDIR%"
if errorlevel 1 (
    echo ERROR: Failed to create output directory
    exit /b 1
)
) else (
    :: Release mode: Maximum optimization, intrinsics, PDB for debugging
    set "CL_FLAGS=/O2 /Oi /GL /Gy /DNDEBUG /MT"
    set "LINK_FLAGS=/DEBUG /OPT:REF /OPT:ICF /LTCG /INCREMENTAL:NO"
)

:: Create output directories
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

:: ============================================================================
:: Build RBHook.dll
:: ============================================================================

echo [RBTray Build] Compiling RBHook.dll...

:: Compile RBHook.cpp
cl.exe %CL_COMMON% %CL_FLAGS% /D_USRDLL /DRBHOOK_EXPORTS ^
    /c RBHook.cpp /Fo"%OUTDIR%\RBHook.obj"

if errorlevel 1 (
    echo ERROR: Failed to compile RBHook.cpp
    exit /b 1
)

:: Link RBHook.dll
link.exe %LINK_COMMON% %LINK_FLAGS% /DLL ^
    /OUT:"%OUTDIR%\RBHook.dll" ^
    /PDB:"%OUTDIR%\RBHook.pdb" ^
    "%OUTDIR%\RBHook.obj" ^
    user32.lib

if errorlevel 1 (
    echo ERROR: Failed to link RBHook.dll
    exit /b 1
)

echo [RBTray Build] RBHook.dll compiled successfully.
echo.

:: ============================================================================
:: Build RBTray.exe
:: ============================================================================

echo [RBTray Build] Compiling RBTray.exe...

:: Compile resource file
rc.exe %RC_FLAGS% /fo"%OUTDIR%\RBTray.res" RBTray.rc

if errorlevel 1 (
    echo ERROR: Failed to compile resources
    exit /b 1
)

:: Compile RBTray.cpp
cl.exe %CL_COMMON% %CL_FLAGS% ^
    /c RBTray.cpp /Fo"%OUTDIR%\RBTray.obj"

if errorlevel 1 (
    echo ERROR: Failed to compile RBTray.cpp
    exit /b 1
)

:: Link RBTray.exe
link.exe %LINK_COMMON% %LINK_FLAGS% ^
    /OUT:"%OUTDIR%\RBTray.exe" ^
    /PDB:"%OUTDIR%\RBTray.pdb" ^
    "%OUTDIR%\RBTray.obj" "%OUTDIR%\RBTray.res" ^
    kernel32.lib user32.lib shell32.lib

if errorlevel 1 (
    echo ERROR: Failed to link RBTray.exe
    exit /b 1
)

echo [RBTray Build] RBTray.exe compiled successfully.
echo.

:: ============================================================================
echo Output files:
dir /B "%OUTDIR%\RBTray.exe" "%OUTDIR%\RBHook.dll"
if not exist "%OUTDIR%\RBTray.exe" (
    echo WARNING: RBTray.exe not found in %OUTDIR%!
)
if not exist "%OUTDIR%\RBHook.dll" (
    echo WARNING: RBHook.dll not found in %OUTDIR%!
)
echo.
echo Build mode: %MODE%
echo Architecture: %ARCH%
echo ============================================================================
echo ============================================================================
echo Output directory: %OUTDIR%\
echo.
dir /B "%OUTDIR%\RBTray.exe" "%OUTDIR%\RBHook.dll" 2>nul
echo.
echo Build mode: %MODE%
echo Architecture: %ARCH%
echo ============================================================================

endlocal
exit /b 0

:: ============================================================================
:: Usage Message
:: ============================================================================
:usage
echo.
echo RBTray Build Script
echo ===================
echo.
echo Usage: build.bat [mode] [architecture]
echo.
echo Arguments:
echo   mode          Build mode: debug or release (default: release)
echo                 Shortcuts: d (debug), r (release)
echo   architecture  Target platform: x86 or x64 (default: x86)
echo.
echo Examples:
echo   build.bat                    Build release x86 (default)
echo   build.bat release x64        Build optimized 64-bit version
echo   build.bat debug x86          Build debug 32-bit version
echo   build.bat d x64              Build debug 64-bit (shorthand)
echo.
echo Build Modes:
echo   Release - Maximum optimization (/O2 /Oi /GL /LTCG)
echo             Static runtime (/MT)
echo             Link-time code generation
echo   Debug   - No optimization (/Od)
echo             Debug symbols (/Zi)
echo             Runtime checks (/RTC1)
echo             Debug static runtime (/MTd)
echo.
echo Requirements:
echo   - Visual Studio Build Tools (Desktop development with C++)
echo   - Windows 10 SDK
echo.
exit /b 0
