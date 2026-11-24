SEATCRAFT v1.0 - Event Seat Booking (C++ / Qt)
==============================================

QUICK START (Windows 10/11, 64-bit - nothing to install)
  1. Unzip this folder anywhere (e.g. Desktop). Do not run it from inside the zip.
  2. Open the App folder.
  3. Double-click:
       SeatCraft-Demo.exe  -> sample events, bookings and a schedule clash to fix
       SeatCraft.exe       -> clean Production edition: add your own events

  If Windows shows "Windows protected your PC", click "More info" -> "Run anyway".
  (The app is not code-signed; it never uses the internet.)

WHAT'S INSIDE
  App\     Ready-to-run program (both editions, terminal version, test runner)
  Source\  Full C++ / QML source code, build.bat, README.md, the original brief
  Docs\    Setup guide (open SeatCraft-Setup-Guide.html), product film + captions, links

TRY IT
  App\seatcraft_tests.exe  -> runs the 75 acceptance checks
  Tickets you download are saved to  Downloads\SeatCraft Tickets\  (PDF + PNG)
  Data is kept in  %APPDATA%\SeatCraft\SeatCraft\Demo  and  ...\Production

REBUILD FROM SOURCE
  Needs Qt 6.8 (MinGW 64-bit) and CMake. See Source\README.md, then run Source\build.bat
