#include "FileStore.h"

#include <cstdio>
#include <fstream>
#include <sstream>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

namespace seatcraft {

namespace {

Result lineError(int line, const std::string& msg) {
    return Result::failure("Line " + std::to_string(line) + ": " + msg);
}

std::string statusCode(EventStatus s) { return s == EventStatus::OnSale ? "ONSALE" : "DRAFT"; }

bool replaceFile(const std::string& from, const std::string& to) {
#ifdef _WIN32
    return MoveFileExA(from.c_str(), to.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0;
#else
    return std::rename(from.c_str(), to.c_str()) == 0;
#endif
}

} // namespace

bool FileStore::exists() const {
    std::ifstream in(path_.c_str());
    return in.good();
}

std::string FileStore::serialize(const BookingManager& m) {
    std::ostringstream out;
    out << "SEATCRAFT|1\n";
    for (const Venue& v : m.venues())
        out << "VENUE|" << v.id() << '|' << v.name() << '|' << Venue::layoutCode(v.layout()) << '|' << v.rows() << '|'
            << v.seatsPerRow() << '|' << v.vipRows() << '|' << v.aisleAfter() << '\n';
    for (const Event& e : m.events())
        out << "EVENT|" << e.id() << '|' << e.title() << '|' << e.category() << '|' << e.date() << '|'
            << util::formatTime(e.start()) << '|' << util::formatTime(e.end()) << '|' << e.venueId() << '|'
            << e.vipPrice() << '|' << e.regularPrice() << '|' << statusCode(e.status()) << '\n';
    for (const Booking* b : m.bookings()) {
        out << "BOOKING|" << b->id() << '|' << b->eventId() << '|' << b->customer().name() << '|'
            << (b->isConfirmed() ? "CONFIRMED" : "CANCELLED") << '\n';
        for (const auto& t : b->tickets())
            out << "TICKET|" << t->id() << '|' << b->id() << '|' << t->seatId() << '|'
                << util::categoryCode(t->getCategory()) << '|' << t->calculatePrice() << '\n';
    }
    return out.str();
}

Result FileStore::parse(const std::string& text, BookingManager& out) {
    BookingManager m;
    std::unique_ptr<Booking> pending;
    int pendingLine = 0;

    auto flush = [&]() -> Result {
        if (!pending) return Result::success();
        const Result r = m.restoreBooking(std::move(pending));
        pending.reset();
        return r.ok ? r : lineError(pendingLine, r.message);
    };

    std::istringstream in(text);
    std::string raw;
    int lineNo = 0;
    while (std::getline(in, raw)) {
        ++lineNo;
        if (!raw.empty() && raw.back() == '\r') raw.pop_back();
        if (util::trim(raw).empty()) continue;
        const std::vector<std::string> f = util::split(raw, '|');
        const std::string& kind = f[0];

        if (kind == "SEATCRAFT") {
            if (f.size() != 2 || f[1] != "1") return lineError(lineNo, "This file was written by an unsupported version.");
        } else if (kind == "VENUE") {
            if (f.size() != 8) return lineError(lineNo, "A venue record needs 8 fields.");
            LayoutType layout;
            int perRow = 0, aisle = 0;
            if (!Venue::parseLayoutCode(f[3], layout)) return lineError(lineNo, "Unknown venue layout \"" + f[3] + "\".");
            if (!util::parseInt(f[5], perRow) || !util::parseInt(f[7], aisle)) return lineError(lineNo, "Venue numbers are not valid.");
            const Result r = m.addVenue(Venue(f[1], f[2], layout, f[4], perRow, f[6], aisle));
            if (!r.ok) return lineError(lineNo, r.message);
        } else if (kind == "EVENT") {
            if (f.size() != 11) return lineError(lineNo, "An event record needs 11 fields.");
            int start = 0, end = 0, vip = 0, reg = 0;
            if (!util::parseTime(f[5], start) || !util::parseTime(f[6], end)) return lineError(lineNo, "Event times must look like 15:00.");
            if (!util::parseInt(f[8], vip) || !util::parseInt(f[9], reg)) return lineError(lineNo, "Event prices are not valid.");
            EventStatus st;
            if (f[10] == "ONSALE") st = EventStatus::OnSale;
            else if (f[10] == "DRAFT") st = EventStatus::Draft;
            else return lineError(lineNo, "Unknown event status \"" + f[10] + "\".");
            const Result r = m.addEvent(Event(f[1], f[2], f[3], f[4], start, end, f[7], vip, reg, st));
            if (!r.ok) return lineError(lineNo, r.message);
        } else if (kind == "BOOKING") {
            const Result r = flush();
            if (!r.ok) return r;
            if (f.size() != 5) return lineError(lineNo, "A booking record needs 5 fields.");
            BookingStatus st;
            if (f[4] == "CONFIRMED") st = BookingStatus::Confirmed;
            else if (f[4] == "CANCELLED") st = BookingStatus::Cancelled;
            else return lineError(lineNo, "Unknown booking status \"" + f[4] + "\".");
            pending.reset(new Booking(f[1], f[2], Customer(f[3]), st));
            pendingLine = lineNo;
        } else if (kind == "TICKET") {
            if (f.size() != 6) return lineError(lineNo, "A ticket record needs 6 fields.");
            if (!pending || pending->id() != f[2]) return lineError(lineNo, "Ticket " + f[1] + " is not directly after booking " + f[2] + ".");
            Category c;
            int price = 0;
            if (!util::parseCategoryCode(f[4], c)) return lineError(lineNo, "Unknown ticket category \"" + f[4] + "\".");
            if (!util::parseInt(f[5], price)) return lineError(lineNo, "Ticket price is not valid.");
            pending->addTicket(Ticket::create(c, f[1], f[3], price));
        } else {
            return lineError(lineNo, "Unknown record type \"" + kind + "\".");
        }
    }
    const Result r = flush();
    if (!r.ok) return r;
    if (m.venues().empty()) return Result::failure("The file contains no venues.");
    // (An empty programme — venues but no events — is valid: that is a fresh Production install.)
    out = std::move(m);
    return Result::success();
}

Result FileStore::load(BookingManager& out) const {
    std::ifstream in(path_.c_str(), std::ios::binary);
    if (!in) return Result::failure("Could not open " + path_ + ".");
    std::ostringstream buf;
    buf << in.rdbuf();
    const Result r = parse(buf.str(), out);
    if (!r.ok) return Result::failure(path_ + " is damaged and was not loaded (" + r.message + "). The file has been left unchanged.");
    return r;
}

Result FileStore::save(const BookingManager& manager) const {
    const std::string tmp = path_ + ".tmp";
    {
        std::ofstream out(tmp.c_str(), std::ios::binary | std::ios::trunc);
        if (!out) return Result::failure("Could not write to " + tmp + ".");
        out << serialize(manager);
        out.flush();
        if (!out) {
            out.close();
            std::remove(tmp.c_str());
            return Result::failure("Writing " + tmp + " failed.");
        }
    }
    if (!replaceFile(tmp, path_)) {
        std::remove(tmp.c_str());
        return Result::failure("Could not replace " + path_ + ".");
    }
    return Result::success();
}

} // namespace seatcraft
