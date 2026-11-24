// ScheduleManager — venue scheduling for multiple events.
// Rule: two events conflict when they share a venue and date and their
// [start, end) intervals overlap. Different venues may run at the same time.
#pragma once

#include "BookingManager.h"

#include <string>
#include <vector>

namespace seatcraft {

struct Conflict {
    std::string firstEventId;
    std::string secondEventId;
    std::string venueId;
    std::string date;
    int overlapStart;
    int overlapEnd;
    int minutes() const { return overlapEnd - overlapStart; }
};

struct ScheduleFix {
    std::string eventId;     // event that would move
    std::string venueId;
    int start;
    int end;
    std::string description;
};

class ScheduleManager {
public:
    explicit ScheduleManager(BookingManager& manager) : m_(manager) {}

    std::vector<Conflict> findConflicts() const;
    std::vector<Conflict> conflictsFor(const std::string& eventId) const;

    // An event with any bookings is locked: its time and venue are promised to guests.
    bool isLocked(const std::string& eventId) const;

    // Ways to clear one conflict by moving the event that is not locked.
    std::vector<ScheduleFix> suggestFixes(const Conflict& conflict) const;

    // Would `eventId` clash with anything if it ran here? Returns the clashing event IDs.
    std::vector<std::string> clashesFor(const std::string& eventId, const std::string& venueId,
                                        int start, int end) const;

    Result reschedule(const std::string& eventId, const std::string& venueId, int start, int end);
    Result apply(const ScheduleFix& fix) { return reschedule(fix.eventId, fix.venueId, fix.start, fix.end); }
    Result publish(const std::string& eventId);

private:
    BookingManager& m_;
};

} // namespace seatcraft
