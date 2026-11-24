cmake_minimum_required(VERSION 3.21)
project(SeatCraft VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ---- Core: plain C++, no GUI dependency -------------------------------------
add_library(seatcraft_core STATIC
    src/core/Util.cpp
    src/core/Ticket.cpp
    src/core/Venue.cpp
    src/core/Event.cpp
    src/core/Booking.cpp
    src/core/BookingManager.cpp
    src/core/ScheduleManager.cpp
    src/core/FileStore.cpp
    src/core/SeedData.cpp
)
target_include_directories(seatcraft_core PUBLIC src)

# Terminal fallback (brief milestone 2) and acceptance checks.
add_executable(seatcraft_cli src/cli/main.cpp)
target_link_libraries(seatcraft_cli PRIVATE seatcraft_core)

add_executable(seatcraft_tests tests/acceptance_tests.cpp)
target_link_libraries(seatcraft_tests PRIVATE seatcraft_core)
enable_testing()
add_test(NAME acceptance COMMAND seatcraft_tests WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

# ---- Desktop app: Qt Quick -------------------------------------------------
option(SEATCRAFT_BUILD_GUI "Build the Qt Quick desktop app" ON)
if(SEATCRAFT_BUILD_GUI)
    find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Svg)
    qt_standard_project_setup(REQUIRES 6.5)

    qt_add_executable(SeatCraft WIN32
        src/app/main.cpp
        src/app/AppController.h
        src/app/AppController.cpp
    )

    set(SEATCRAFT_QML
        qml/Main.qml
        qml/Theme.qml
        qml/TopBar.qml
        qml/NavLink.qml
        qml/AppButton.qml
        qml/EventArt.qml
        qml/GeneratedArt.qml
        qml/SeatGlyph.qml
        qml/VenuePlan.qml
        qml/ViewFromSeat.qml
        qml/DiscoverPage.qml
        qml/SeatPage.qml
        qml/VenuesPage.qml
        qml/BookingsPage.qml
        qml/OrganizerPage.qml
        qml/NewEventDialog.qml
        qml/LoadErrorPage.qml
    )
    # Serve every QML file from the module root, so the Theme singleton is
    # never shadowed by an implicit import of the qml/ folder.
    foreach(f ${SEATCRAFT_QML})
        get_filename_component(name ${f} NAME)
        set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${name})
    endforeach()
    set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

    qt_add_qml_module(SeatCraft
        URI SeatCraft
        VERSION 1.0
        QML_FILES ${SEATCRAFT_QML}
        RESOURCES
            assets/art/tt.svg
            assets/art/hm.svg
            assets/art/rb.svg
            assets/art/qw.svg
            assets/art/sp.svg
            assets/art/jz.svg
            assets/art/hero_tt.svg
    )

    target_link_libraries(SeatCraft PRIVATE Qt6::Quick Qt6::QuickControls2 Qt6::Svg seatcraft_core)

    # Optional: drop the design's .ttf files into assets/fonts and they are loaded at start-up.
    target_compile_definitions(SeatCraft PRIVATE SEATCRAFT_FONT_DIR="${CMAKE_CURRENT_SOURCE_DIR}/assets/fonts")
endif()
