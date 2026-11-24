// BookingManager — owns venues, events and bookings and enforces every
// booking rule. Screens call it; they never change bookings themselves.
#pragma once

#include "Booking.h"
#include "Event.h"
#include "Types.h"
#include "Venue.h"

#include <functional>
#include <memory>
#include <set>
#include <string>
#include <vector>

namespace seatcraft {

struct EventSummary {
    int capacity = 0;
    int confirmedSeats = 0;
    int remaining = 0;
    int vipCapacity = 0;
    int vipOpen = 0;
    int regularOpen = 0;
    int confirmedValue = 0;
    int confirmedBookings = 0;
    int cancelledBookings = 0;
};

class BookingManager {
public:
    // Called after every change. If it fails, the change is undone and the
    // command reports failure, so success is only shown after a real save.
    using SaveHook = std::function<Result(const BookingManager&)>;

    void setSaveHook(SaveHook hook) { saveHook_ = std::move(hook); }
    Result persist() const;

    // ---- setup (seed data and file loading) ----
    Result addVenue(const Venue& venue);
    Result addEvent(const Event& event);
    Result restoreBooking(std::unique_ptr<Booking> booking);

    // ---- queries ----
    const std::vector<Venue>& venues() const { return venues_; }
    const std::vector<Event>& events() const { return events_; }
    const Venue* venue(const std::string& id) const;
    const Event* event(const std::string& id) const;
    const Venue* venueOf(const std::string& eventId) const;

    std::vector<const Booking*> bookings() const;                         // oldest first
    std::vector<const Booking*> bookingsFor(const std::string& eventId) const;
    const Booking* booking(const std::string& eventId, const std::string& bookingId) const;

    // Booked seats are always rebuilt from confirmed bookings (one source of truth).
    std::set<std::string> bookedSeats(const std::string& eventId) const;
    bool isSeatBooked(const std::string& eventId, const std::string& seatId) const;
    int bookingCount(const std::string& eventId) const;                  // any status
    EventSummary summary(const std::string& eventId) const;

    // Case-insensitive match on booking ID, customer name or event title. Newest first.
    std::vector<const Booking*> search(const std::string& query) const;

    // Best block of `quantity` adjacent open seats (never across the aisle).
    std::vector<std::string> bestTogether(const std::string& eventId, int quantity, SeatPreference pref) const;

    // IDs continue after the highest saved ID for the event, cancelled ones included.
    std::string nextBookingId(const std::string& eventId) const;
    std::string nextTicketId(const std::string& eventId) const;

    // ---- commands ----
    Result createBooking(const std::string& eventId, const std::string& customerName,
                         const std::vector<std::string>& seatIds, std::string* newBookingId = nullptr);
    Result cancelBooking(const std::string& eventId, const std::string& bookingId);
    // Adds a new event (normally as a draft) and saves; undone if the save fails.
    Result createEvent(const Event& event);
    std::string nextEventId() const;

private:
    friend class ScheduleManager;
    Event* eventMutable(const std::string& id);
    Booking* bookingMutable(const std::string& eventId, const std::string& bookingId);
    int highestNumber(const std::string& eventId, bool tickets) const;

    std::vector<Venue> venues_;
    std::vector<Event> events_;
    std::vector<std::unique_ptr<Booking>> bookings_;
    SaveHook saveHook_;
};

} // namespace seatcraft
