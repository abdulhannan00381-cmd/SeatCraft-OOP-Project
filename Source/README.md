# SeatCraft — Event Seat Booking (C++ / Qt)

An offline box-office desk app for a university OOP project. It handles multiple events across three venues, seat booking with VIP/Regular pricing, tickets, search, whole-booking cancellation, and venue scheduling with conflict detection. It uses no database, no network and no payments; everything is saved in one local text file.

The look follows the approved **Marquee** design (canvas: https://claude.ai/artifact/9Rk9enGXCMoiyzoX3LbNTw).

## Build and run (Windows)

You need:
- Qt 6.8 for MinGW in `C:\Qt\6.8.3\mingw_64`.
- The MinGW 13.1 compiler in `C:\Qt\Tools\mingw1310_64`.
- CMake (`pip install cmake`).

```bat
build.bat                 :: build everything into .\build
build.bat build-release   :: or into another folder
```

Outputs in `build\`:

| File | What it is |
|---|---|
| `SeatCraft.exe` | Desktop app, **Production edition**: venues only, you add your own events. The Qt runtime is copied beside it. |
| `SeatCraft-Demo.exe` | The same app, **Demo edition**: sample events, bookings and a clash to fix. |
| `seatcraft_cli.exe` | Terminal fallback (brief milestone 2): `seatcraft_cli.exe [datafile]` |
| `seatcraft_tests.exe` | Acceptance checks — prints `75 / 75 checks passed` |

The core, the terminal app and the tests also build without Qt:
- With CMake: `cmake -DSEATCRAFT_BUILD_GUI=OFF ...`
- With the plain Makefile: `mingw32-make && mingw32-make test`

**Editions and data files.** Any exe whose name contains `demo` (or the `--demo` switch) runs the Demo edition. Each edition keeps its own data:
- Production: `%APPDATA%\SeatCraft\SeatCraft\Production\seatcraft.txt` (starts with the three venues and no events)
- Demo: `%APPDATA%\SeatCraft\SeatCraft\Demo\seatcraft.txt` (starts with the sample programme)

Use `--data <file>` to point the app at another file.

**Tickets.** After a booking, *Download ticket* saves the ticket as a PDF (A4) and a PNG in `Downloads\SeatCraft Tickets\`.

**Event artwork.** The sample events have drawn posters; every new event gets its own generated poster based on its title and type (Talks, Music, Tech, Theatre, Sports, Film, Festival, Art).

## The five screens

| Screen | What you can do |
|---|---|
| **Discover** | See the featured event, quick-book the best seats together, use the 14-day calendar and category filters, and browse event posters and venues. |
| **Seat selection** | Switch between events. Each venue has its own plan: fan, flat or tiered. Click seats, use "best seats together", see the view from your seat and a live total. Then enter the customer name and confirm. |
| **Venues** | See each venue's plan, capacity, VIP/Regular rows and upcoming events. Each plan can switch between seating zones and availability. |
| **Bookings** | See the selected booking as a ticket, one ticket per seat, a seat locator, search by ID or name, a status filter, and whole-booking cancellation with confirmation. |
| **Organizer** | See KPIs and a week view with a venue timeline. Overlapping events in one venue are flagged, the suggested fixes are previewed on the timeline, and you can apply and re-check them. Also: publish drafts, the events table, and adding a new draft event. |

## Code structure

```
src/core/        Plain C++17 (no Qt): every rule lives here
  Types.h          enums, Result, text/date/money helpers
  Ticket.*         Ticket (abstract) ◁ RegularTicket, VIPTicket
  Venue.*          Venue has Seats; layout geometry (fan / flat / tiered)
  Event.*          one scheduled event; clash rule
  Booking.*        Customer + Booking (owns one ticket per seat)
  BookingManager.* create / cancel / search / best seats / summaries
  ScheduleManager.* conflicts, suggested fixes, reschedule, publish
  FileStore.*      load/validate/save seatcraft.txt (temp file + replace)
  SeedData.*       sample programme used on first run
src/cli/main.cpp   terminal fallback
src/app/           Qt bridge: AppController (QObject) + main.cpp
qml/               the five screens and shared components (Theme.qml = design tokens)
assets/art/        event artwork (SVG)
tests/             acceptance checks (brief cases 01–09 + scheduling)
```

**The rule for the GUI:** QML only displays data and forwards clicks to `AppController`. The controller calls `BookingManager` and `ScheduleManager`. No booking or scheduling rule exists in the GUI.

## OOP points for the viva

- **Polymorphism:**
  - `Booking::total()` sums `Ticket::calculatePrice()` through `Ticket` pointers; the concrete class decides the category.
  - Acceptance case 04 shows Rs 800 + Rs 1,200 = Rs 2,000.
- **Inheritance:** `RegularTicket` and `VIPTicket` derive from the abstract `Ticket`.
- **Encapsulation:**
  - `Event::moveTo()` and `setStatus()` are private; only `ScheduleManager` (a friend) may move or publish an event.
  - `Booking::setStatus()` is reachable only from `BookingManager`.
- **Composition:**
  - A `Venue` has `Seat`s.
  - A `Booking` has a `Customer` and owns its `Ticket`s (`std::unique_ptr`).

## Rules implemented

- Booked seats are always rebuilt from confirmed bookings. A selection is not a booking.
- A booking needs a non-blank name (no `|` or line breaks) and at least one existing, free, non-duplicate seat.
- IDs are sequential **per event** and include cancelled records, so they are never reused. The key is event + ID, which keeps the brief's sample `EVT01 · BKG-0013 · TKT-0013/0014` unchanged.
- Every change is saved before success is shown. If saving fails, the change is undone (acceptance case 08).
- A damaged data file is reported with its line number and never overwritten (case 09). The app offers to start again with the sample data and keeps the damaged file beside it.
- **Scheduling:** two events conflict when they share a venue and date and their `[start, end)` times overlap.
  - Different venues may run at the same time.
  - Back-to-back events (17:00 end, 17:00 start) do not clash.
  - Events with bookings are locked.
  - Drafts can't be published while in conflict.

## Changes from the original brief

| Brief | Now |
|---|---|
| One preconfigured event | Six events in three venues (one draft that clashes on purpose) |
| Single seat grid | Venue-shaped plans: fan auditorium, flat hall, tiered amphitheatre |
| — | Venue scheduling, conflict detection and suggested fixes; Organizer screen (a mode of the same desk, not a login) |
| `EVENT` line only | `VENUE` and `EVENT` lines with start **and end** times; IDs per event |
| — | Best seats together, view from seat, quick book, seat locator |
| — | Ticket download as PDF and image; two editions (Demo / Production) |

Still out of scope, as in the brief: partial cancellation, seat holds, QR codes, payments, multiple desks.

## Fonts

The design uses Big Shoulders Display, Instrument Sans and IBM Plex Mono (all SIL OFL). If their `.ttf` files are placed in `assets/fonts` (or `fonts` next to the exe), the app uses them automatically. Otherwise it uses Windows' built-in Bahnschrift (condensed), Segoe UI and Consolas.

## Checking the screens

`SeatCraft.exe --data test.txt --screenshots <folder>` renders every screen, including a scripted booking and a schedule fix, to PNG files and exits. It is useful for comparing against the design canvas.

## Four-minute demo (use SeatCraft-Demo.exe)

1. **Discover:** the featured TechTalk; quick book shows C5–C6 for Rs 1,600.
2. **Seat selection:** pick C5 and C6, note the view from the seat and the total, then confirm for Ayesha Khan. This creates BKG-0013 with TKT-0013 and TKT-0014.
3. Close and reopen the app; the booking is still there.
4. **Bookings:** search for BKG-0013, then cancel it. C5 and C6 are free again.
5. **Organizer:** the Hamlet clash in the Main Auditorium. Preview the fixes, apply one, then publish.
6. **Code:** explain the `Ticket` hierarchy and the `ScheduleManager` clash rule.
