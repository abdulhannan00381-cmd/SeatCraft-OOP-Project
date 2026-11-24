#include "BookingManager.h"

#include <algorithm>
#include <cmath>
#include <cstdio>

namespace seatcraft {

Result BookingManager::persist() const {
    if (!saveHook_) return Result::success();
    return saveHook_(*this);
}

// ---------------------------------------------------------------- setup

Result BookingManager::addVenue(const Venue& v) {
    const Result r = v.validate();
    if (!r.ok) return r;
    if (venue(v.id())) return Result::failure("Venue " + v.id() + " is listed twice.");
    venues_.push_back(v);
    return Result::success();
}

Result BookingManager::addEvent(const Event& e) {
    const Result r = e.validate();
    if (!r.ok) return r;
    if (event(e.id())) return Result::failure("Event " + e.id() + " is listed twice.");
    if (!venue(e.venueId())) return Result::failure("Event " + e.id() + " refers to an unknown venue " + e.venueId() + ".");
    events_.push_back(e);
    return Result::success();
}

Result BookingManager::restoreBooking(std::unique_ptr<Booking> b) {
    const Event* e = event(b->eventId());
    if (!e) return Result::failure("Booking " + b->id() + " refers to an unknown event " + b->eventId() + ".");
    if (util::parseIdNumber(b->id(), "BKG") < 0) return Result::failure("Booking ID " + b->id() + " is not valid.");
    if (booking(b->eventId(), b->id())) return Result::failure("Booking " + b->id() + " appears twice for " + b->eventId() + ".");
    const Result nameOk = Customer::validateName(b->customer().name());
    if (!nameOk.ok) return Result::failure("Booking " + b->id() + ": " + nameOk.message);
    if (b->tickets().empty()) return Result::failure("Booking " + b->id() + " has no tickets.");

    const Venue* v = venue(e->venueId());
    const std::set<std::string> taken = bookedSeats(e->id());
    std::set<std::string> ticketIds;
    for (const Booking* other : bookingsFor(e->id()))
        for (const auto& t : other->tickets()) ticketIds.insert(t->id());
    std::set<std::string> seatsInThis;
    for (const auto& t : b->tickets()) {
        if (util::parseIdNumber(t->id(), "TKT") < 0) return Result::failure("Ticket ID " + t->id() + " is not valid.");
        if (!ticketIds.insert(t->id()).second) return Result::failure("Ticket " + t->id() + " appears twice for " + e->id() + ".");
        if (!v->hasSeat(t->seatId())) return Result::failure("Ticket " + t->id() + " uses seat " + t->seatId() + ", which does not exist in " + v->name() + ".");
        if (v->categoryOf(t->seatId()) != t->getCategory()) return Result::failure("Ticket " + t->id() + " has the wrong category for seat " + t->seatId() + ".");
        if (t->calculatePrice() <= 0) return Result::failure("Ticket " + t->id() + " has no price.");
        if (!seatsInThis.insert(t->seatId()).second) return Result::failure("Booking " + b->id() + " lists seat " + t->seatId() + " twice.");
        if (b->isConfirmed() && taken.count(t->seatId()))
            return Result::failure("Seat " + t->seatId() + " has two confirmed tickets for " + e->id() + ".");
    }
    bookings_.push_back(std::move(b));
    return Result::success();
}

// ---------------------------------------------------------------- queries

const Venue* BookingManager::venue(const std::string& id) const {
    for (const auto& v : venues_)
        if (v.id() == id) return &v;
    return nullptr;
}

const Event* BookingManager::event(const std::string& id) const {
    for (const auto& e : events_)
        if (e.id() == id) return &e;
    return nullptr;
}

Event* BookingManager::eventMutable(const std::string& id) {
    for (auto& e : events_)
        if (e.id() == id) return &e;
    return nullptr;
}

const Venue* BookingManager::venueOf(const std::string& eventId) const {
    const Event* e = event(eventId);
    return e ? venue(e->venueId()) : nullptr;
}

std::vector<const Booking*> BookingManager::bookings() const {
    std::vector<const Booking*> out;
    for (const auto& b : bookings_) out.push_back(b.get());
    return out;
}

std::vector<const Booking*> BookingManager::bookingsFor(const std::string& eventId) const {
    std::vector<const Booking*> out;
    for (const auto& b : bookings_)
        if (b->eventId() == eventId) out.push_back(b.get());
    return out;
}

const Booking* BookingManager::booking(const std::string& eventId, const std::string& bookingId) const {
    for (const auto& b : bookings_)
        if (b->eventId() == eventId && b->id() == bookingId) return b.get();
    return nullptr;
}

Booking* BookingManager::bookingMutable(const std::string& eventId, const std::string& bookingId) {
    for (auto& b : bookings_)
        if (b->eventId() == eventId && b->id() == bookingId) return b.get();
    return nullptr;
}

std::set<std::string> BookingManager::bookedSeats(const std::string& eventId) const {
    std::set<std::string> seats;
    for (const auto& b : bookings_)
        if (b->eventId() == eventId && b->isConfirmed())
            for (const auto& t : b->tickets()) seats.insert(t->seatId());
    return seats;
}

bool BookingManager::isSeatBooked(const std::string& eventId, const std::string& seatId) const {
    return bookedSeats(eventId).count(seatId) > 0;
}

int BookingManager::bookingCount(const std::string& eventId) const {
    return static_cast<int>(bookingsFor(eventId).size());
}

EventSummary BookingManager::summary(const std::string& eventId) const {
    EventSummary s;
    const Venue* v = venueOf(eventId);
    if (!v) return s;
    s.capacity = v->capacity();
    s.vipCapacity = v->vipCapacity();
    int vipBooked = 0;
    for (const Booking* b : bookingsFor(eventId)) {
        if (!b->isConfirmed()) { ++s.cancelledBookings; continue; }
        ++s.confirmedBookings;
        s.confirmedValue += b->total();
        for (const auto& t : b->tickets()) {
            ++s.confirmedSeats;
            if (t->getCategory() == Category::VIP) ++vipBooked;
        }
    }
    s.remaining = s.capacity - s.confirmedSeats;
    s.vipOpen = s.vipCapacity - vipBooked;
    s.regularOpen = s.remaining - s.vipOpen;
    return s;
}

std::vector<const Booking*> BookingManager::search(const std::string& query) const {
    const std::string q = util::toLower(util::trim(query));
    std::vector<const Booking*> out;
    for (auto it = bookings_.rbegin(); it != bookings_.rend(); ++it) {
        const Booking* b = it->get();
        const Event* e = event(b->eventId());
        if (q.empty() || util::toLower(b->id()).find(q) != std::string::npos ||
            util::toLower(b->customer().name()).find(q) != std::string::npos ||
            (e && util::toLower(e->title()).find(q) != std::string::npos))
            out.push_back(b);
    }
    return out;
}

std::vector<std::string> BookingManager::bestTogether(const std::string& eventId, int quantity, SeatPreference pref) const {
    const Venue* v = venueOf(eventId);
    if (!v || quantity < 1) return {};
    const std::set<std::string> taken = bookedSeats(eventId);
    const double mid = (v->seatsPerRow() + 1) / 2.0;
    const int blocks[2][2] = {{1, v->aisleAfter()}, {v->aisleAfter() + 1, v->seatsPerRow()}};
    for (char row : v->preferredRows(pref)) {
        std::vector<std::string> best;
        double bestScore = 1e9;
        for (const auto& blk : blocks) {
            for (int start = blk[0]; start + quantity - 1 <= blk[1]; ++start) {
                std::vector<std::string> window;
                double score = 0;
                bool free = true;
                for (int n = start; n < start + quantity; ++n) {
                    const std::string id = std::string(1, row) + std::to_string(n);
                    if (taken.count(id)) { free = false; break; }
                    window.push_back(id);
                    score += std::fabs(n - mid);
                }
                if (free && score < bestScore) { bestScore = score; best = window; }
            }
        }
        if (!best.empty()) return best;
    }
    return {};
}

int BookingManager::highestNumber(const std::string& eventId, bool tickets) const {
    int high = 0;
    for (const Booking* b : bookingsFor(eventId)) {
        if (tickets) {
            for (const auto& t : b->tickets()) high = std::max(high, util::parseIdNumber(t->id(), "TKT"));
        } else {
            high = std::max(high, util::parseIdNumber(b->id(), "BKG"));
        }
    }
    return high;
}

std::string BookingManager::nextBookingId(const std::string& eventId) const {
    return util::formatId("BKG", highestNumber(eventId, false) + 1);
}

std::string BookingManager::nextTicketId(const std::string& eventId) const {
    return util::formatId("TKT", highestNumber(eventId, true) + 1);
}

// ---------------------------------------------------------------- commands

static std::string joinAnd(const std::vector<std::string>& items) {
    std::string out;
    for (std::size_t i = 0; i < items.size(); ++i) {
        if (i > 0) out += (i + 1 == items.size()) ? " and " : ", ";
        out += items[i];
    }
    return out;
}

Result BookingManager::createBooking(const std::string& eventId, const std::string& customerName,
                                     const std::vector<std::string>& seatIds, std::string* newBookingId) {
    const Event* e = event(eventId);
    if (!e) return Result::failure("That event could not be found.");
    if (!e->isOnSale()) return Result::failure("Tickets for " + e->title() + " are not on sale yet.");
    const Result nameOk = Customer::validateName(customerName);
    if (!nameOk.ok) return nameOk;
    if (seatIds.empty()) return Result::failure("Choose at least one seat to continue.");

    const Venue* v = venue(e->venueId());
    const std::set<std::string> taken = bookedSeats(eventId);
    std::set<std::string> seen;
    for (const std::string& s : seatIds) {
        if (!v->hasSeat(s)) return Result::failure("Seat " + s + " does not exist in " + v->name() + ".");
        if (!seen.insert(s).second) return Result::failure("Seat " + s + " was selected twice.");
        if (taken.count(s)) return Result::failure("Seat " + s + " is already booked. Please choose another seat.");
    }

    // Sort seats front-to-back, left-to-right so tickets read naturally.
    std::vector<std::string> ordered = seatIds;
    std::sort(ordered.begin(), ordered.end(), [v](const std::string& a, const std::string& b) {
        const int ra = v->rowIndex(a[0]), rb = v->rowIndex(b[0]);
        if (ra != rb) return ra < rb;
        return std::stoi(a.substr(1)) < std::stoi(b.substr(1));
    });

    const std::string id = nextBookingId(eventId);
    int ticketNo = highestNumber(eventId, true) + 1;
    std::unique_ptr<Booking> b(new Booking(id, eventId, Customer(util::trim(customerName))));
    for (const std::string& s : ordered) {
        const Category c = v->categoryOf(s);
        b->addTicket(Ticket::create(c, util::formatId("TKT", ticketNo++), s, e->priceFor(c)));
    }
    const int total = b->total();
    const std::string customer = b->customer().name();
    bookings_.push_back(std::move(b));

    const Result saved = persist();
    if (!saved.ok) {
        bookings_.pop_back();
        return Result::failure("The booking could not be saved, so it was not confirmed. " + saved.message);
    }
    if (newBookingId) *newBookingId = id;
    return Result::success("Booking " + id + " confirmed for " + customer + ": " + joinAnd(ordered) + " (" + util::formatMoney(total) + ").");
}

std::string BookingManager::nextEventId() const {
    int high = 0;
    for (const Event& e : events_) {
        int n = 0;
        if (e.id().size() > 3 && e.id().compare(0, 3, "EVT") == 0 && util::parseInt(e.id().substr(3), n)) high = std::max(high, n);
    }
    char buf[16];
    std::snprintf(buf, sizeof buf, "EVT%02d", high + 1);
    return buf;
}

Result BookingManager::createEvent(const Event& e) {
    const Result added = addEvent(e);
    if (!added.ok) return added;
    const Result saved = persist();
    if (!saved.ok) {
        events_.pop_back();
        return Result::failure("The new event could not be saved. " + saved.message);
    }
    return Result::success(e.title() + " was added as " + (e.isOnSale() ? "on sale." : "a draft."));
}

Result BookingManager::cancelBooking(const std::string& eventId, const std::string& bookingId) {
    Booking* b = bookingMutable(eventId, util::trim(bookingId));
    if (!b) return Result::failure("No booking " + util::trim(bookingId) + " was found for this event.");
    if (!b->isConfirmed()) return Result::failure("Booking " + b->id() + " is already cancelled.");
    b->setStatus(BookingStatus::Cancelled);
    const Result saved = persist();
    if (!saved.ok) {
        b->setStatus(BookingStatus::Confirmed);
        return Result::failure("The cancellation could not be saved, so the booking is unchanged. " + saved.message);
    }
    const std::vector<std::string> seats = b->seatIds();
    return Result::success("Booking " + b->id() + " cancelled. " + joinAnd(seats) +
                           (seats.size() > 1 ? " are" : " is") + " available again.");
}

} // namespace seatcraft
