# RBTray Copilot Instructions

## Project Overview

RBTray is a **native Windows C++ system utility** (in maintenance mode) that allows minimizing any window to the system tray. It uses a **two-component architecture**:

1. **RBTray.exe** - Main application with message pump and tray management
2. **RBHook.dll** - Windows hook DLL for intercepting mouse events system-wide

## Architecture & Data Flow

### Critical Communication Pattern

The components communicate via **Windows messages** to the hidden `RBTrayHook` window:

- `WM_ADDTRAY (0x0401)` - Hook DLL signals main app to minimize a window
- `WM_REMTRAY (0x0402)` - Request to restore window from tray
- `WM_REFRTRAY (0x0403)` - Refresh/validate window state in tray
- `WM_TRAYCMD (0x0404)` - Tray icon notification callback

### Hook Mechanism (RBHook.dll)

Installs two **global Windows hooks**:

- `WH_MOUSE` - Detects right-click on minimize button or Shift+right-click on title bar
- `WH_CALLWNDPROCRET` - Monitors window visibility changes to auto-remove tray icons

**Important:** The DLL is injected into every GUI process on the system. Changes affect system-wide behavior.

### Tray Management (RBTray.cpp)

- Fixed array `_hwndItems[MAXTRAYITEMS]` (64 slots) tracks minimized windows
- Each window becomes a tray icon using `Shell_NotifyIcon` API
- Icons retrieved via `WM_GETICON` messages or class icons
- Special handling: MDI children ignored, child windows resolve to root ancestor

## Build System

**Visual Studio 2022 solution** with two projects:

- Build outputs to `x86/` and `x64/` directories based on platform
- Uses static runtime (`MultiThreaded`) - no MSVC runtime DLL dependencies
- Platform toolset: v143 (Windows 10 SDK)
- **No test framework** - testing requires manual system integration tests

Build both platforms:

```powershell
MSBuild RBTray.sln /p:Configuration=Release /p:Platform=x86
MSBuild RBTray.sln /p:Configuration=Release /p:Platform=x64
```

## Code Conventions

### Windows API Style

- **Wide strings** (`WCHAR`, `L""` literals) - all UI text is Unicode
- **Hungarian notation** for Windows types: `hwnd`, `hIcon`, `nid` (NOTIFYICONDATA)
- Static/global variables prefixed with `_` (e.g., `_hwndHook`, `_hLib`)
- No C++ classes or STL - pure Win32 C-style code

### Critical Patterns

- **NOTIFYICONDATA_V2_SIZE** used for tray icons (not V3/V4 for XP compatibility)
- Window validation before operations: `IsWindow(hwnd)` checks are essential
- Sleep delays in `CloseWindowFromTray()` allow apps time to respond to `WM_CLOSE`

### --no-hook Mode

Command-line option disables hook DLL - only Control-Alt-Down hotkey works. Use this when debugging hook-related issues or conflicts with other software.

## Known Limitations

- Windows Store apps (UWP) cannot be minimized (architectural limitation)
- 32-bit RBTray.exe only hooks 32-bit processes; 64-bit only hooks 64-bit
- Requires elevated privileges to minimize elevated windows (UAC boundary)
- No configuration UI - behavior is hard-coded
- Project in maintenance mode - no new features accepted

## Key Files

- `RBTray.h` - Shared constants/messages between .exe and .dll
- `RBTray.cpp:MinimizeWindowToTray()` - Core minimization logic with special case handling
- `RBHook.cpp:MouseProc()` - Hit testing logic for minimize button vs title bar
- `resource.h`, `RBTray.rc` - Dialog/icon resources (About dialog, context menu IDs)
