// Acceptance checks from the brief (cases 01–09) plus the multi-event
// scheduling rules. Plain C++ with a tiny CHECK macro — no framework needed.
#include "core/BookingManager.h"
#include "core/FileStore.h"
#include "core/ScheduleManager.h"
#include "core/SeedData.h"

#include <cstdio>
#include <fstream>
#include <iostream>

using namespace seatcraft;

static int g_checks = 0, g_failed = 0;
#define CHECK(cond)                                                                    \
    do {                                                                               \
        ++g_checks;                                                                    \
        if (!(cond)) { ++g_failed; std::cout << "  FAIL line " << __LINE__ << ": " #cond "\n"; } \
    } while (0)

static void section(const char* name) { std::cout << name << "\n"; }

static BookingManager seeded() {
    BookingManager m;
    const Result r = populateSeedData(m);
    if (!r.ok) std::cout << "  seed error: " << r.message << "\n";
    return m;
}

static const std::string kFile = "test_seatcraft.txt";

int main() {
    std::remove(kFile.c_str());

    section("Seed data matches the approved design");
    {
        BookingManager m = seeded();
        CHECK(m.venues().size() == 3);
        CHECK(m.events().size() == 6);
        CHECK(m.summary("EVT01").confirmedSeats == 12);
        CHECK(m.summary("EVT01").confirmedValue == 11600);
        CHECK(m.summary("EVT03").remaining == 9);
        CHECK(m.summary("EVT04").remaining == 32);
        CHECK(m.summary("EVT05").remaining == 42);
        CHECK(m.summary("EVT05").cancelledBookings == 1);
        CHECK(m.summary("EVT06").remaining == 55);
        CHECK(m.nextBookingId("EVT01") == "BKG-0013");
        CHECK(m.nextTicketId("EVT01") == "TKT-0013");
    }

    BookingManager m = seeded();
    FileStore store(kFile);
    CHECK(store.save(m).ok);
    m.setSaveHook([&store](const BookingManager& mgr) { return store.save(mgr); });

    section("01  Select C5 and C6, Ayesha Khan, confirm");
    {
        std::string id;
        const Result r = m.createBooking("EVT01", "Ayesha Khan", {"C5", "C6"}, &id);
        CHECK(r.ok);
        CHECK(id == "BKG-0013");
        const Booking* b = m.booking("EVT01", id);
        CHECK(b && b->tickets().size() == 2);
        CHECK(b && b->total() == 1600);
        CHECK(b && b->tickets()[0]->id() == "TKT-0013" && b->tickets()[1]->id() == "TKT-0014");
        CHECK(m.summary("EVT01").confirmedSeats == 14);
        CHECK(m.summary("EVT01").remaining == 46);
        CHECK(m.summary("EVT01").confirmedValue == 13200);
    }

    section("02  A2 is already booked");
    {
        const Result r = m.createBooking("EVT01", "Test Person", {"A2"});
        CHECK(!r.ok);
        CHECK(m.summary("EVT01").confirmedSeats == 14);
    }

    section("03  No seats / blank name / forbidden characters");
    {
        const std::string before = m.nextBookingId("EVT01");
        CHECK(!m.createBooking("EVT01", "Someone", {}).ok);
        CHECK(!m.createBooking("EVT01", "   ", {"A1"}).ok);
        CHECK(!m.createBooking("EVT01", "Bad|Name", {"A1"}).ok);
        CHECK(!m.createBooking("EVT01", "Someone", {"Z99"}).ok);
        CHECK(!m.createBooking("EVT01", "Someone", {"A1", "A1"}).ok);
        CHECK(m.nextBookingId("EVT01") == before);      // no ID was committed
    }

    section("04  One Regular + one VIP = Rs 2,000 (polymorphism)");
    {
        std::string id;
        CHECK(m.createBooking("EVT01", "Mixed Pair", {"D1", "A1"}, &id).ok);
        const Booking* b = m.booking("EVT01", id);
        CHECK(b && b->total() == 2000);
        CHECK(b && b->tickets()[0]->getCategory() == Category::VIP);      // sorted front row first
        CHECK(b && b->tickets()[1]->categoryName() == "Regular");
        CHECK(m.cancelBooking("EVT01", id).ok);
    }

    section("05  Restart keeps BKG-0013, its IDs and prices");
    {
        BookingManager reloaded;
        CHECK(store.load(reloaded).ok);
        const Booking* b = reloaded.booking("EVT01", "BKG-0013");
        CHECK(b && b->isConfirmed() && b->total() == 1600);
        CHECK(reloaded.isSeatBooked("EVT01", "C5") && reloaded.isSeatBooked("EVT01", "C6"));
        CHECK(reloaded.nextBookingId("EVT01") == "BKG-0015");
    }

    section("06  Cancel BKG-0013, restart: seats free, history kept, IDs not reused");
    {
        CHECK(m.cancelBooking("EVT01", "BKG-0013").ok);
        BookingManager reloaded;
        CHECK(store.load(reloaded).ok);
        CHECK(!reloaded.isSeatBooked("EVT01", "C5"));
        CHECK(reloaded.booking("EVT01", "BKG-0013") && !reloaded.booking("EVT01", "BKG-0013")->isConfirmed());
        CHECK(reloaded.summary("EVT01").confirmedValue == 11600);
        CHECK(reloaded.nextBookingId("EVT01") == "BKG-0015");
        CHECK(reloaded.nextTicketId("EVT01") == "TKT-0017");
    }

    section("07  Unknown ID / already cancelled");
    {
        CHECK(!m.cancelBooking("EVT01", "BKG-9999").ok);
        CHECK(!m.cancelBooking("EVT01", "BKG-0013").ok);
        CHECK(m.search("BKG-9999").empty());
        CHECK(!m.search("ayesha").empty());
    }

    section("08  Save to an unwritable location: no success, data unchanged");
    {
        BookingManager temp = seeded();
        FileStore bad("Z:/no/such/folder/seatcraft.txt");
        temp.setSaveHook([&bad](const BookingManager& mgr) { return bad.save(mgr); });
        const Result r = temp.createBooking("EVT01", "Ayesha Khan", {"C5"});
        CHECK(!r.ok);
        CHECK(!temp.isSeatBooked("EVT01", "C5"));
        CHECK(temp.nextBookingId("EVT01") == "BKG-0013");
    }

    section("09  Malformed file is reported and left untouched");
    {
        const std::string damaged = "test_damaged.txt";
        {
            std::ofstream out(damaged.c_str());
            out << "SEATCRAFT|1\nVENUE|MA|Main Auditorium|FAN|ABCDE|12|AB|6\n"
                   "EVENT|EVT01|TechTalk|Talks|2026-11-12|15:00|17:00|MA|1200|800|ONSALE\n"
                   "BOOKING|BKG-0001|EVT01|A|CONFIRMED\nTICKET|TKT-0001|BKG-0001|C5|REGULAR|800\n"
                   "BOOKING|BKG-0002|EVT01|B|CONFIRMED\nTICKET|TKT-0002|BKG-0002|C5|REGULAR|800\n";
        }
        BookingManager target;
        const Result r = FileStore(damaged).load(target);
        CHECK(!r.ok);
        CHECK(r.message.find("Line 6") != std::string::npos);
        CHECK(target.events().empty());
        std::ifstream in(damaged.c_str());
        std::string first;
        std::getline(in, first);
        CHECK(first == "SEATCRAFT|1");
        in.close();
        std::remove(damaged.c_str());
    }

    section("10  Schedule: same venue overlap is a conflict, other venues are fine");
    {
        ScheduleManager s(m);
        const std::vector<Conflict> c = s.findConflicts();
        CHECK(c.size() == 1);
        CHECK(c.size() == 1 && c[0].venueId == "MA" && c[0].minutes() == 30);
        // TechTalk (MA) and Robotics (EH) run at the same time without a conflict.
        CHECK(!m.event("EVT01")->clashesWith(*m.event("EVT03")));
        CHECK(!s.publish("EVT02").ok);                 // blocked while in conflict
        CHECK(!s.reschedule("EVT01", "MA", 600, 720).ok);   // locked: has bookings
    }

    section("11  Suggested fixes clear the conflict; back-to-back is allowed");
    {
        ScheduleManager s(m);
        const std::vector<ScheduleFix> fixes = s.suggestFixes(s.findConflicts()[0]);
        CHECK(fixes.size() >= 2);
        CHECK(fixes[0].eventId == "EVT02" && fixes[0].venueId == "MA" && fixes[0].start == 17 * 60);
        bool hasVenueMove = false;
        for (const ScheduleFix& f : fixes) if (f.venueId == "OA") hasVenueMove = true;
        CHECK(hasVenueMove);
        CHECK(s.apply(fixes[0]).ok);
        CHECK(s.findConflicts().empty());
        CHECK(s.publish("EVT02").ok);
        CHECK(m.event("EVT02")->isOnSale());
        BookingManager reloaded;
        CHECK(store.load(reloaded).ok);
        CHECK(reloaded.event("EVT02")->start() == 17 * 60 && reloaded.event("EVT02")->isOnSale());
    }

    section("12  Best seats together");
    {
        BookingManager fresh = seeded();
        const std::vector<std::string> two = fresh.bestTogether("EVT01", 2, SeatPreference::Any);
        CHECK(two.size() == 2 && two[0] == "C5" && two[1] == "C6");
        const std::vector<std::string> vip4 = fresh.bestTogether("EVT01", 4, SeatPreference::VIP);
        CHECK(vip4.size() == 4 && vip4[0] == "A8");
        CHECK(fresh.bestTogether("EVT04", 1, SeatPreference::VIP).empty());   // Qawwali VIP sold out
        CHECK(fresh.bestTogether("EVT03", 3, SeatPreference::Any).empty());   // no 3 together left
    }

    section("13  Venue geometry");
    {
        BookingManager fresh = seeded();
        const Venue* ma = fresh.venue("MA");
        const SeatPose p = ma->pose(2, 5);    // C5
        CHECK(p.x > 350 && p.x < 380 && p.y > 260 && p.y < 285);
        CHECK(ma->capacity() == 60 && fresh.venue("EH")->capacity() == 40 && fresh.venue("OA")->capacity() == 84);
    }

    std::remove(kFile.c_str());
    std::cout << "\n" << (g_checks - g_failed) << " / " << g_checks << " checks passed\n";
    return g_failed == 0 ? 0 : 1;
}
