// SeatCraft terminal fallback — the brief's numbered menu, extended for
// multiple events and venue scheduling. Uses exactly the same core classes
// as the desktop app.
#include "core/BookingManager.h"
#include "core/FileStore.h"
#include "core/ScheduleManager.h"
#include "core/SeedData.h"

#include <iostream>
#include <sstream>
#include <string>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

using namespace seatcraft;

namespace {

std::string ask(const std::string& prompt) {
    std::cout << prompt;
    std::string line;
    if (!std::getline(std::cin, line)) return "0";
    // Some shells prefix piped input with a UTF-8 byte-order mark; ignore it.
    if (line.size() >= 3 && line.compare(0, 3, "\xEF\xBB\xBF") == 0) line.erase(0, 3);
    return util::trim(line);
}

bool confirm(const std::string& prompt) {
    const std::string a = util::toLower(ask(prompt + " (y/n): "));
    return a == "y" || a == "yes";
}

void show(const Result& r) { std::cout << (r.ok ? "  OK  " : "  !!  ") << r.message << "\n"; }

void printEventLine(const BookingManager& m, const Event& e) {
    const Venue* v = m.venue(e.venueId());
    const EventSummary s = m.summary(e.id());
    std::cout << "  [" << e.id() << "] " << e.title() << " | " << e.displayDate() << " | " << e.timeRange() << " | "
              << v->name() << " | " << (e.isOnSale() ? std::to_string(s.remaining) + " of " + std::to_string(s.capacity) + " open" : "DRAFT")
              << "\n";
}

void printSeats(const BookingManager& m, const Event& e) {
    const Venue* v = m.venue(e.venueId());
    const std::set<std::string> taken = m.bookedSeats(e.id());
    std::cout << "\n                    ===== STAGE =====\n\n";
    for (char row : v->rows()) {
        const bool vip = v->vipRows().find(row) != std::string::npos;
        std::cout << "  " << row << (vip ? " VIP " : "     ");
        for (int n = 1; n <= v->seatsPerRow(); ++n) {
            const std::string id = std::string(1, row) + std::to_string(n);
            if (taken.count(id)) std::cout << " --";
            else std::cout << (n < 10 ? "  " : " ") << n;
            if (n == v->aisleAfter()) std::cout << "  |";
        }
        std::cout << "\n";
    }
    std::cout << "\n  -- = booked   | = aisle   VIP " << util::formatMoney(e.vipPrice()) << "   Regular "
              << util::formatMoney(e.regularPrice()) << "\n";
}

std::vector<std::string> parseSeats(const std::string& text) {
    std::vector<std::string> seats;
    std::string cleaned = text;
    for (char& c : cleaned) if (c == ',') c = ' ';
    std::istringstream in(cleaned);
    std::string s;
    while (in >> s) {
        for (char& c : s) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
        seats.push_back(s);
    }
    return seats;
}

void book(BookingManager& m, const Event& e) {
    if (!e.isOnSale()) { std::cout << "  Tickets for this event are not on sale yet.\n"; return; }
    printSeats(m, e);
    std::string input = ask("\n  Seats (e.g. C5 C6) or \"best 2\": ");
    std::vector<std::string> seats;
    if (util::toLower(input).compare(0, 4, "best") == 0) {
        int q = 0;
        if (!util::parseInt(util::trim(input.substr(4)), q) || q < 1 || q > 8) { std::cout << "  Enter a number from 1 to 8.\n"; return; }
        seats = m.bestTogether(e.id(), q, SeatPreference::Any);
        if (seats.empty()) { std::cout << "  There are no " << q << " seats together left.\n"; return; }
        std::cout << "  Best " << q << " together:";
        for (const auto& s : seats) std::cout << ' ' << s;
        std::cout << "\n";
    } else {
        seats = parseSeats(input);
    }
    if (seats.empty()) { std::cout << "  Choose at least one seat to continue.\n"; return; }
    const Venue* v = m.venue(e.venueId());
    int total = 0;
    for (const auto& s : seats) {
        if (!v->hasSeat(s)) { std::cout << "  Seat " << s << " does not exist in " << v->name() << ".\n"; return; }
        if (m.isSeatBooked(e.id(), s)) { std::cout << "  Seat " << s << " is already booked. Please choose another seat.\n"; return; }
        total += e.priceFor(v->categoryOf(s));
    }
    std::cout << "  Total: " << util::formatMoney(total) << "  (selection is not a booking yet)\n";
    const std::string name = ask("  Customer name: ");
    if (!confirm("  Confirm booking")) { std::cout << "  Nothing was booked.\n"; return; }
    std::string id;
    const Result r = m.createBooking(e.id(), name, seats, &id);
    show(r);
    if (r.ok) {
        const Booking* b = m.booking(e.id(), id);
        for (const auto& t : b->tickets())
            std::cout << "     " << t->id() << "  " << t->seatId() << "  " << t->categoryName() << "  "
                      << util::formatMoney(t->calculatePrice()) << "\n";
    }
}

void find(const BookingManager& m) {
    const std::string q = ask("  Booking ID or customer name: ");
    const std::vector<const Booking*> found = m.search(q);
    if (found.empty()) { std::cout << "  No booking matches \"" << q << "\".\n"; return; }
    for (const Booking* b : found) {
        const Event* e = m.event(b->eventId());
        std::cout << "  " << b->eventId() << " " << b->id() << " | " << b->customer().name() << " | " << e->title() << " | "
                  << b->seatList() << " | " << util::formatMoney(b->total()) << " | "
                  << (b->isConfirmed() ? "Confirmed" : "Cancelled") << "\n";
    }
}

void cancel(BookingManager& m, const Event& e) {
    const std::string id = ask("  Booking ID to cancel (for " + e.title() + "): ");
    const Booking* b = m.booking(e.id(), id);
    if (!b) { std::cout << "  No booking " << id << " was found for this event.\n"; return; }
    if (!b->isConfirmed()) { std::cout << "  Booking " << id << " is already cancelled.\n"; return; }
    std::cout << "  " << b->customer().name() << " | " << b->seatList() << " | " << util::formatMoney(b->total()) << "\n";
    if (!confirm("  Cancel the whole booking? The seats will be released")) { std::cout << "  Booking kept.\n"; return; }
    show(m.cancelBooking(e.id(), id));
}

void summary(const BookingManager& m) {
    int sold = 0, value = 0;
    for (const Event& e : m.events()) {
        const EventSummary s = m.summary(e.id());
        std::cout << "  " << e.id() << "  " << e.title() << "\n     booked " << s.confirmedSeats << " / " << s.capacity
                  << "   remaining " << s.remaining << "   confirmed value " << util::formatMoney(s.confirmedValue)
                  << (e.isOnSale() ? "" : "   (draft)") << "\n";
        sold += s.confirmedSeats;
        value += s.confirmedValue;
    }
    std::cout << "  Total seats sold " << sold << "   total confirmed value " << util::formatMoney(value) << "\n";
}

void schedule(BookingManager& m) {
    ScheduleManager sched(m);
    const std::vector<Conflict> conflicts = sched.findConflicts();
    if (conflicts.empty()) std::cout << "  No schedule conflicts.\n";
    for (const Conflict& c : conflicts) {
        std::cout << "  CONFLICT  " << m.venue(c.venueId)->name() << " on " << util::formatDate(c.date) << ": "
                  << m.event(c.firstEventId)->title() << " and " << m.event(c.secondEventId)->title() << " overlap "
                  << util::formatTime(c.overlapStart) << "-" << util::formatTime(c.overlapEnd) << " (" << c.minutes() << " min)\n";
        const std::vector<ScheduleFix> fixes = sched.suggestFixes(c);
        if (fixes.empty()) { std::cout << "  Both events have bookings; resolve this manually.\n"; continue; }
        for (std::size_t i = 0; i < fixes.size(); ++i) std::cout << "    " << (i + 1) << ") " << fixes[i].description << "\n";
        int pick = 0;
        if (util::parseInt(ask("  Apply fix number (Enter to skip): "), pick) && pick >= 1 && pick <= static_cast<int>(fixes.size()))
            show(sched.apply(fixes[pick - 1]));
    }
    for (const Event& e : m.events())
        if (!e.isOnSale() && confirm("  Publish " + e.title() + " now")) show(sched.publish(e.id()));
}

} // namespace

int main(int argc, char** argv) {
#ifdef _WIN32
    SetConsoleOutputCP(CP_UTF8);
#endif
    const std::string path = argc > 1 ? argv[1] : "seatcraft.txt";
    FileStore store(path);
    BookingManager m;
    if (store.exists()) {
        const Result r = store.load(m);
        if (!r.ok) { std::cerr << r.message << "\n"; return 1; }
    } else {
        const Result seeded = populateSeedData(m);
        if (!seeded.ok) { std::cerr << "Seed data error: " << seeded.message << "\n"; return 1; }
        const Result saved = store.save(m);
        if (!saved.ok) { std::cerr << saved.message << "\n"; return 1; }
        std::cout << "Created " << path << " with the sample programme.\n";
    }
    m.setSaveHook([&store](const BookingManager& mgr) { return store.save(mgr); });

    std::string current = "EVT01";
    for (;;) {
        const Event* e = m.event(current);
        std::cout << "\n=== SeatCraft box office ===\n";
        printEventLine(m, *e);
        std::cout << "  1 Seats  2 Book  3 Find  4 Cancel  5 Summary  6 Change event  7 Schedule  0 Exit\n";
        const std::string choice = ask("> ");
        if (choice == "1") printSeats(m, *e);
        else if (choice == "2") book(m, *e);
        else if (choice == "3") find(m);
        else if (choice == "4") cancel(m, *e);
        else if (choice == "5") summary(m);
        else if (choice == "6") {
            for (const Event& ev : m.events()) printEventLine(m, ev);
            const std::string id = util::trim(ask("  Event ID: "));
            std::string upper = id;
            for (char& c : upper) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
            if (m.event(upper)) current = upper;
            else std::cout << "  No event " << id << ".\n";
        } else if (choice == "7") schedule(m);
        else if (choice == "0") { std::cout << "All changes are saved in " << path << ". Goodbye.\n"; return 0; }
        else std::cout << "  Choose a number from the menu.\n";
    }
}
