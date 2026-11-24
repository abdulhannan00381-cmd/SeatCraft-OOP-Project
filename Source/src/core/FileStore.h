// FileStore — local text-file persistence (no database, no network).
//
// Format: one record per line, fields separated by "|".
//   SEATCRAFT|1
//   VENUE|MA|Main Auditorium|FAN|ABCDE|12|AB|6
//   EVENT|EVT01|University TechTalk 2026|Talks|2026-11-12|15:00|17:00|MA|1200|800|ONSALE
//   BOOKING|BKG-0013|EVT01|Ayesha Khan|CONFIRMED
//   TICKET|TKT-0013|BKG-0013|C5|REGULAR|800
// TICKET lines follow their BOOKING line. Booking and ticket IDs are
// sequential per event; the key of a booking is event + booking ID.
#pragma once

#include "BookingManager.h"

#include <string>

namespace seatcraft {

class FileStore {
public:
    explicit FileStore(std::string path) : path_(std::move(path)) {}

    const std::string& path() const { return path_; }
    bool exists() const;

    // Loads into `out` only if the whole file is valid. A damaged file is
    // reported (with its line number) and never overwritten.
    Result load(BookingManager& out) const;

    // Writes to "<path>.tmp" first, then replaces the old file. If anything
    // fails, the previous file is left untouched.
    Result save(const BookingManager& manager) const;

    static std::string serialize(const BookingManager& manager);
    static Result parse(const std::string& text, BookingManager& out);

private:
    std::string path_;
};

} // namespace seatcraft
