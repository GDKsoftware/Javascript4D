@echo off
setlocal enabledelayedexpansion

REM Platform: Win32 or Win64 (default: Win64)
set PLATFORM=%1
if "%PLATFORM%"=="" set PLATFORM=Win64

echo ====================================================
echo Javascript4D - Test Suite (%PLATFORM%)
echo ====================================================
echo.

REM Set Delphi paths
set DELPHI_PATH=C:\Program Files (x86)\Embarcadero\Studio\37.0
set DCC32="%DELPHI_PATH%\bin\dcc32.exe"
set DCC64="%DELPHI_PATH%\bin\dcc64.exe"

REM Choose compiler based on platform
if "%PLATFORM%"=="Win64" (
    set COMPILER=%DCC64%
) else (
    set COMPILER=%DCC32%
)

REM Check if Delphi compiler exists
if not exist %COMPILER% (
    echo ERROR: Delphi compiler not found at %COMPILER%
    echo Please update DELPHI_PATH in this batch file
    exit /b 1
)

REM ====================================================
REM STEP 1: Clean up
REM ====================================================
echo [1/3] Cleaning up old artifacts...
if exist "%PLATFORM%\Debug" rmdir /s /q "%PLATFORM%\Debug"
mkdir "%PLATFORM%\Debug"
echo.

REM ====================================================
REM STEP 2: Build Tests
REM ====================================================
echo [2/3] Building tests...
echo.

set DUNITX_PATH=%DELPHI_PATH%\source\DunitX

%COMPILER% -$O- -$W+ -$R+ -$Q+ --no-config -B -Q -TX.exe ^
  -DDEBUG ^
  -E%PLATFORM%\Debug ^
  -N0%PLATFORM%\Debug ^
  -NH%PLATFORM%\Debug ^
  -NO%PLATFORM%\Debug ^
  -NSSystem;Xml;Data;Datasnap;Web;Soap ^
  -U"%DELPHI_PATH%\lib\%PLATFORM%\release";..\Source\Core;..\Source\Lexer;..\Source\Parser;..\Source\Runtime;..\Source\API;"%DUNITX_PATH%" ^
  -I"%DELPHI_PATH%\lib\%PLATFORM%\release";..\Source\Core;..\Source\Lexer;..\Source\Parser;..\Source\Runtime;..\Source\API;"%DUNITX_PATH%" ^
  -O"%DELPHI_PATH%\lib\%PLATFORM%\release";..\Source\Core;..\Source\Lexer;..\Source\Parser;..\Source\Runtime;..\Source\API;"%DUNITX_PATH%" ^
  -R"%DELPHI_PATH%\lib\%PLATFORM%\release";..\Source\Core;..\Source\Lexer;..\Source\Parser;..\Source\Runtime;..\Source\API;"%DUNITX_PATH%" ^
  JS4D.Tests.dpr

if errorlevel 1 (
    echo ERROR: Test build failed!
    exit /b 1
)

echo Test build successful!
echo.

REM ====================================================
REM STEP 3: Run Tests
REM ====================================================
echo [3/3] Running tests...
echo.

%PLATFORM%\Debug\JS4D.Tests.exe -exit:continue

set TEST_RESULT=!ERRORLEVEL!

echo.
if !TEST_RESULT! EQU 0 (
    echo ====================================================
    echo ALL TESTS PASSED
    echo ====================================================
) else (
    echo ====================================================
    echo TESTS FAILED (Exit code: !TEST_RESULT!)
    echo ====================================================
)

endlocal
exit /b %TEST_RESULT%
