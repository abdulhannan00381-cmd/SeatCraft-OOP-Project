@echo off
REM Builds SeatCraft: core, terminal fallback, tests and the Qt desktop app (both editions).
REM Usage:  build.bat            -> builds into .\build
REM         build.bat myfolder   -> builds into .\myfolder
REM Edit the two paths below if Qt is installed somewhere else.
setlocal
set "QTDIR=C:\Qt\6.8.3\mingw_64"
set "MINGW=C:\Qt\Tools\mingw1310_64\bin"
set "BUILD=%~1"
if "%BUILD%"=="" set "BUILD=build"
set "ROOT=%~dp0"

REM CMake: use the pip-installed copy if present, otherwise whatever is on PATH.
REM The build uses mingw32-make, which ships with Qt's MinGW compiler (no Ninja needed).
for /f "delims=" %%i in ('python -c "import cmake;print(cmake.CMAKE_BIN_DIR)" 2^>nul') do set "CMAKEBIN=%%i"
set "PATH=%MINGW%;%QTDIR%\bin;%CMAKEBIN%;%PATH%"

if not exist "%QTDIR%\bin\qmake.exe" (
  echo Qt was not found in %QTDIR%. Install Qt 6.8 for MinGW or edit QTDIR in build.bat.
  exit /b 1
)

cmake -S "%ROOT%." -B "%ROOT%%BUILD%" -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="%QTDIR%" -DCMAKE_CXX_COMPILER="%MINGW%\g++.exe" -DCMAKE_MAKE_PROGRAM="%MINGW%\mingw32-make.exe"
if errorlevel 1 exit /b 1
cmake --build "%ROOT%%BUILD%" -j %NUMBER_OF_PROCESSORS%
if errorlevel 1 exit /b 1

REM Copy the Qt runtime next to the app so it starts by double-click.
"%QTDIR%\bin\windeployqt.exe" --qmldir "%ROOT%qml" --no-translations --no-system-d3d-compiler "%ROOT%%BUILD%\SeatCraft.exe" >nul
copy /y "%MINGW%\libgcc_s_seh-1.dll" "%ROOT%%BUILD%" >nul
copy /y "%MINGW%\libstdc++-6.dll" "%ROOT%%BUILD%" >nul
copy /y "%MINGW%\libwinpthread-1.dll" "%ROOT%%BUILD%" >nul

REM Demo edition = the same program under a name containing "Demo".
copy /y "%ROOT%%BUILD%\SeatCraft.exe" "%ROOT%%BUILD%\SeatCraft-Demo.exe" >nul

echo.
echo Built: %BUILD%\SeatCraft.exe (Production, starts empty)
echo        %BUILD%\SeatCraft-Demo.exe (Demo, sample events and bookings)
echo        %BUILD%\seatcraft_cli.exe and %BUILD%\seatcraft_tests.exe
endlocal
