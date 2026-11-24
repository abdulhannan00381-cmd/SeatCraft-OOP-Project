# SeatCraft — Event Seat Booking (C++ OOP Project)

SeatCraft is an offline desktop box office for campus events. Desk staff pick seats on a map of the real venue, confirm a booking and download the ticket. Organizers schedule events, and the app catches clashes in the same venue.

- **Core:** plain C++17 classes that hold every rule (no GUI code)
- **Interface:** Qt 6 Quick (QML), five screens: Discover, Seat selection, Bookings, Venues, Organizer
- **Storage:** one local text file, no database, no internet
- **Tests:** 75 automated acceptance checks

## OOP concepts

| Concept | Where |
|---|---|
| Inheritance | `RegularTicket` and `VIPTicket` derive from the abstract `Ticket` (`Source/src/core/Ticket.h`) |
| Polymorphism | `Booking::total()` sums `Ticket::calculatePrice()` through base-class pointers (`Booking.cpp`) |
| Abstraction | `Ticket` has pure virtual functions and cannot be created directly |
| Encapsulation | private data and setters; only `ScheduleManager` (a friend) may move or publish an `Event`, only `BookingManager` may cancel a `Booking` |
| Composition | a `Venue` has `Seat`s; a `Booking` has a `Customer` and owns its `Ticket`s (`std::unique_ptr`) |

## Repository layout

```
Source/      full C++ / QML source, CMakeLists.txt, build.bat, Makefile, README.md
  src/core/    C++17 core: Ticket, Venue, Event, Booking, BookingManager, ScheduleManager, FileStore, SeedData
  src/app/     Qt bridge (AppController) and the GUI entry point
  src/cli/     terminal version of the box office
  qml/         the screens
  tests/       acceptance checks
Docs/        setup guide, screenshots, product film
```

## Build and run

You need Qt 6.8 for MinGW 64-bit and CMake 3.21 or newer. See [Source/README.md](Source/README.md) for details.

```bat
cd Source
build.bat
build\seatcraft_tests.exe
build\SeatCraft-Demo.exe
```

The core, the terminal app and the tests also build with any MinGW g++ and no Qt:

```bat
cd Source
mingw32-make
mingw32-make test
```

`SeatCraft-Demo.exe` starts with sample events and bookings. `SeatCraft.exe` starts clean.
