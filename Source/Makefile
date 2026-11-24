# Builds the SeatCraft core, terminal fallback and acceptance tests with g++.
# Usage (Windows, MinGW):  mingw32-make        then  mingw32-make test
# The Qt desktop app is built with CMake instead (see README.md).

CXX      ?= g++
CXXFLAGS := -std=c++14 -Wall -Wextra -O2 -Isrc
BUILD    := build-cli

CORE := src/core/Util.cpp src/core/Ticket.cpp src/core/Venue.cpp src/core/Event.cpp \
        src/core/Booking.cpp src/core/BookingManager.cpp src/core/ScheduleManager.cpp \
        src/core/FileStore.cpp src/core/SeedData.cpp
HDRS := $(wildcard src/core/*.h)

all: $(BUILD)/seatcraft_cli.exe $(BUILD)/seatcraft_tests.exe

$(BUILD):
	mkdir $(BUILD)

$(BUILD)/seatcraft_cli.exe: $(CORE) src/cli/main.cpp $(HDRS) | $(BUILD)
	$(CXX) $(CXXFLAGS) -o $@ $(CORE) src/cli/main.cpp

$(BUILD)/seatcraft_tests.exe: $(CORE) tests/acceptance_tests.cpp $(HDRS) | $(BUILD)
	$(CXX) $(CXXFLAGS) -o $@ $(CORE) tests/acceptance_tests.cpp

test: $(BUILD)/seatcraft_tests.exe
	cd $(BUILD) && seatcraft_tests.exe

.PHONY: all test
