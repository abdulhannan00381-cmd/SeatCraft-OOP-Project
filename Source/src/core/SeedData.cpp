#include "SeedData.h"

namespace seatcraft {

namespace {

struct SeedBooking {
    int number;
    const char* customer;
    std::vector<std::string> seats;
    bool cancelled;
};

const char* kNames[] = {
    "Ali Raza", "Hira Shah", "Noor Fatima", "Ahmed Khan", "Mehwish Ali", "Saad Qureshi", "Iqra Javed",
    "Fahad Malik", "Ayesha Siddiqui", "Bilal Khan", "Zainab Hussain", "Hamza Ali", "Sara Ahmed", "Usman Tariq",
    "Mariam Iqbal", "Kashif Mehmood", "Rabia Anwar", "Talha Butt", "Amna Riaz", "Danish Akhtar", "Sana Mir",
    "Omar Farooq", "Laiba Aslam", "Waqar Younis", "Hina Pervaiz", "Asad Rafiq", "Kiran Naz", "Junaid Sheikh",
    "Areeba Khalid", "Shoaib Nadeem"};

std::vector<std::string> seatRange(char row, int from, int to) {
    std::vector<std::string> out;
    for (int n = from; n <= to; ++n) out.push_back(std::string(1, row) + std::to_string(n));
    return out;
}

// Splits `seats` into `count` bookings as evenly as possible (earlier bookings get the extra seat).
std::vector<SeedBooking> fill(const std::vector<std::string>& seats, int count, int firstNumber, int nameOffset) {
    std::vector<SeedBooking> out;
    const int total = static_cast<int>(seats.size());
    const int base = total / count, extra = total % count;
    std::size_t pos = 0;
    for (int i = 0; i < count; ++i) {
        const int size = base + (i < extra ? 1 : 0);
        std::vector<std::string> mine(seats.begin() + pos, seats.begin() + pos + size);
        pos += size;
        out.push_back(SeedBooking{firstNumber + i, kNames[(nameOffset + i) % 30], mine, false});
    }
    return out;
}

Result addBookings(BookingManager& m, const std::string& eventId, const std::vector<SeedBooking>& list) {
    const Event* e = m.event(eventId);
    const Venue* v = m.venue(e->venueId());
    int ticketNo = 1;
    for (const SeedBooking& sb : list) {
        std::unique_ptr<Booking> b(new Booking(util::formatId("BKG", sb.number), eventId, Customer(sb.customer),
                                               sb.cancelled ? BookingStatus::Cancelled : BookingStatus::Confirmed));
        for (const std::string& s : sb.seats) {
            const Category c = v->categoryOf(s);
            b->addTicket(Ticket::create(c, util::formatId("TKT", ticketNo++), s, e->priceFor(c)));
        }
        const Result r = m.restoreBooking(std::move(b));
        if (!r.ok) return r;
    }
    return Result::success();
}

int toMin(int h, int m) { return h * 60 + m; }

} // namespace

Result populateVenues(BookingManager& m) {
    Result r = m.addVenue(Venue("MA", "Main Auditorium", LayoutType::Fan, "ABCDE", 12, "AB", 6));
    if (r.ok) r = m.addVenue(Venue("EH", "Engineering Hall E-101", LayoutType::Flat, "ABCD", 10, "A", 5));
    if (r.ok) r = m.addVenue(Venue("OA", "Open-Air Amphitheatre", LayoutType::Tiered, "ABCDEF", 14, "A", 7));
    return r;
}

Result populateSeedData(BookingManager& m) {
    Result r = Result::success();
#define SC_TRY(expr) do { r = (expr); if (!r.ok) return r; } while (0)

    SC_TRY(populateVenues(m));

    SC_TRY(m.addEvent(Event("EVT01", "University TechTalk 2026", "Talks", "2026-11-12", toMin(15, 0), toMin(17, 0), "MA", 1200, 800, EventStatus::OnSale)));
    SC_TRY(m.addEvent(Event("EVT02", "Hamlet, Reimagined", "Theatre", "2026-11-12", toMin(16, 30), toMin(18, 30), "MA", 900, 600, EventStatus::Draft)));
    SC_TRY(m.addEvent(Event("EVT03", "Robotics Expo Finals", "Tech", "2026-11-12", toMin(15, 0), toMin(18, 0), "EH", 700, 500, EventStatus::OnSale)));
    SC_TRY(m.addEvent(Event("EVT04", "Qawwali Under the Stars", "Music", "2026-11-14", toMin(19, 30), toMin(22, 0), "OA", 1500, 900, EventStatus::OnSale)));
    SC_TRY(m.addEvent(Event("EVT05", "Startup Pitch Night", "Talks", "2026-11-18", toMin(18, 0), toMin(20, 30), "MA", 1000, 600, EventStatus::OnSale)));
    SC_TRY(m.addEvent(Event("EVT06", "Winter Jazz Ensemble", "Music", "2026-11-20", toMin(19, 0), toMin(21, 0), "MA", 1400, 900, EventStatus::OnSale)));

    // EVT01 — the brief's sample: 12 seats booked, C5/C6 left open for BKG-0013.
    SC_TRY(addBookings(m, "EVT01", {
        {7, "Zara Noor", {"E6", "E7", "E10"}, false},
        {8, "Usman Ali", {"D3", "D8"}, false},
        {9, "Bilal Ahmed", {"A2", "A3"}, false},
        {10, "Sana Iqbal", {"A7", "B9"}, false},
        {11, "Hamza Raza", {"B4"}, false},
        {12, "Maria Tariq", {"C2", "C9"}, false}}));

    // EVT03 — Robotics Expo: 31 of 40 booked; open seats A1 A10 B5 B6 C1 C2 D5 D6 D10.
    {
        std::vector<std::string> taken;
        for (const std::string& s : seatRange('A', 2, 9)) if (s != "A4" && s != "A5") taken.push_back(s);
        for (const char* s : {"B1", "B2", "B3", "B4", "B7", "B8", "B9", "B10", "C3", "C4", "C5", "C6", "C7", "C8",
                              "C9", "C10", "D1", "D2", "D3", "D4", "D7", "D8", "D9"}) taken.push_back(s);
        std::vector<SeedBooking> list = fill(taken, 20, 1, 0);
        list.push_back(SeedBooking{21, "Hassan Javed", {"A4", "A5"}, false});
        SC_TRY(addBookings(m, "EVT03", list));
    }

    // EVT04 — Qawwali: row A full, the centre of rows B–F taken (52 of 84).
    {
        std::vector<std::string> taken;
        for (const std::string& s : seatRange('A', 1, 14)) if (s != "A7" && s != "A8") taken.push_back(s);
        for (char row : std::string("BCDE"))
            for (const std::string& s : seatRange(row, 4, 11)) taken.push_back(s);
        for (const std::string& s : seatRange('F', 5, 10)) taken.push_back(s);
        std::vector<SeedBooking> list = fill(taken, 29, 1, 5);
        list.push_back(SeedBooking{30, "Fatima Malik", {"A7", "A8"}, false});
        SC_TRY(addBookings(m, "EVT04", list));
    }

    // EVT05 — Startup Pitch Night: 18 booked plus one cancelled booking (E5 released).
    {
        std::vector<SeedBooking> list = fill({"A5", "A6", "B6", "B7", "C3", "C4", "C10", "C11", "D4"}, 3, 1, 12);
        list.push_back(SeedBooking{4, "Imran Shah", {"E5"}, true});
        std::vector<SeedBooking> more = fill({"D5", "D7", "E1", "E2", "E3", "E10", "E11", "E12"}, 4, 5, 16);
        list.insert(list.end(), more.begin(), more.end());
        list.push_back(SeedBooking{9, "Omar Siddiqui", {"D6"}, false});
        SC_TRY(addBookings(m, "EVT05", list));
    }

    // EVT06 — Winter Jazz: 5 booked.
    SC_TRY(addBookings(m, "EVT06", {
        {1, "Nadia Hassan", {"A6", "A7"}, false},
        {2, "Faisal Qadir", {"C6", "C7"}, false},
        {3, "Mahnoor Zafar", {"D12"}, false}}));

#undef SC_TRY
    return Result::success();
}

} // namespace seatcraft
