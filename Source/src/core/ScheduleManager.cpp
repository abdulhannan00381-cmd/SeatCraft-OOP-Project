#include "ScheduleManager.h"

#include <algorithm>

namespace seatcraft {

std::vector<Conflict> ScheduleManager::findConflicts() const {
    std::vector<Conflict> out;
    const std::vector<Event>& ev = m_.events();
    for (std::size_t i = 0; i < ev.size(); ++i)
        for (std::size_t j = i + 1; j < ev.size(); ++j)
            if (ev[i].clashesWith(ev[j]))
                out.push_back(Conflict{ev[i].id(), ev[j].id(), ev[i].venueId(), ev[i].date(),
                                       std::max(ev[i].start(), ev[j].start()), std::min(ev[i].end(), ev[j].end())});
    return out;
}

std::vector<Conflict> ScheduleManager::conflictsFor(const std::string& eventId) const {
    std::vector<Conflict> out;
    for (const Conflict& c : findConflicts())
        if (c.firstEventId == eventId || c.secondEventId == eventId) out.push_back(c);
    return out;
}

bool ScheduleManager::isLocked(const std::string& eventId) const { return m_.bookingCount(eventId) > 0; }

std::vector<std::string> ScheduleManager::clashesFor(const std::string& eventId, const std::string& venueId,
                                                     int start, int end) const {
    std::vector<std::string> out;
    const Event* me = m_.event(eventId);
    if (!me) return out;
    for (const Event& other : m_.events()) {
        if (other.id() == eventId || other.venueId() != venueId || other.date() != me->date()) continue;
        if (start < other.end() && other.start() < end) out.push_back(other.id());
    }
    return out;
}

std::vector<ScheduleFix> ScheduleManager::suggestFixes(const Conflict& c) const {
    std::vector<ScheduleFix> fixes;
    const Event* a = m_.event(c.firstEventId);
    const Event* b = m_.event(c.secondEventId);
    if (!a || !b) return fixes;

    // Move the event without bookings; if both are free, move the draft (or the later one).
    const Event* mover = nullptr;
    const Event* anchor = nullptr;
    if (isLocked(a->id()) && isLocked(b->id())) return fixes;   // needs a manual decision
    if (isLocked(a->id())) { mover = b; anchor = a; }
    else if (isLocked(b->id())) { mover = a; anchor = b; }
    else if (!b->isOnSale() || (a->isOnSale() && b->start() >= a->start())) { mover = b; anchor = a; }
    else { mover = a; anchor = b; }

    const int duration = mover->end() - mover->start();
    const Venue* here = m_.venue(mover->venueId());

    // 1) Same venue, first free slot after the anchor event ends.
    int start = anchor->end();
    for (int guard = 0; guard < 20 && start + duration <= 24 * 60; ++guard) {
        const std::vector<std::string> hit = clashesFor(mover->id(), mover->venueId(), start, start + duration);
        if (hit.empty()) {
            fixes.push_back(ScheduleFix{mover->id(), mover->venueId(), start, start + duration,
                "Start " + mover->title() + " at " + util::formatTime(start) + " in " + here->name() + " (" +
                util::formatTime(start) + "\xE2\x80\x93" + util::formatTime(start + duration) + "), right after " +
                anchor->title() + " ends."});
            break;
        }
        int next = start;
        for (const std::string& id : hit) next = std::max(next, m_.event(id)->end());
        if (next == start) break;
        start = next;
    }

    // 2) Same time, any other venue that is free.
    for (const Venue& v : m_.venues()) {
        if (v.id() == mover->venueId()) continue;
        if (clashesFor(mover->id(), v.id(), mover->start(), mover->end()).empty())
            fixes.push_back(ScheduleFix{mover->id(), v.id(), mover->start(), mover->end(),
                "Move " + mover->title() + " to " + v.name() + " at the same time (" + mover->timeRange() +
                ") \xE2\x80\x94 " + std::to_string(v.capacity()) + " seats."});
    }

    // 3) Same venue, finishing just before the anchor starts (if the day allows).
    const int earlyStart = anchor->start() - duration;
    if (earlyStart >= 8 * 60 && clashesFor(mover->id(), mover->venueId(), earlyStart, anchor->start()).empty())
        fixes.push_back(ScheduleFix{mover->id(), mover->venueId(), earlyStart, anchor->start(),
            "Start " + mover->title() + " earlier, " + util::formatTime(earlyStart) + "\xE2\x80\x93" +
            util::formatTime(anchor->start()) + ", before " + anchor->title() + "."});
    return fixes;
}

Result ScheduleManager::reschedule(const std::string& eventId, const std::string& venueId, int start, int end) {
    Event* e = m_.eventMutable(eventId);
    if (!e) return Result::failure("That event could not be found.");
    if (isLocked(eventId)) return Result::failure(e->title() + " already has bookings, so its time and venue can't be changed.");
    const Venue* v = m_.venue(venueId);
    if (!v) return Result::failure("That venue could not be found.");
    if (start < 0 || end > 24 * 60 || end <= start) return Result::failure("The event must end after it starts, on the same day.");
    const std::vector<std::string> hit = clashesFor(eventId, venueId, start, end);
    if (!hit.empty()) return Result::failure("That time clashes with " + m_.event(hit[0])->title() + " in " + v->name() + ".");

    const std::string oldVenue = e->venueId();
    const int oldStart = e->start(), oldEnd = e->end();
    e->moveTo(venueId, start, end);
    const Result saved = m_.persist();
    if (!saved.ok) {
        e->moveTo(oldVenue, oldStart, oldEnd);
        return Result::failure("The schedule change could not be saved. " + saved.message);
    }
    return Result::success(e->title() + " now runs " + e->timeRange() + " in " + v->name() + ".");
}

Result ScheduleManager::publish(const std::string& eventId) {
    Event* e = m_.eventMutable(eventId);
    if (!e) return Result::failure("That event could not be found.");
    if (e->isOnSale()) return Result::failure(e->title() + " is already on sale.");
    const std::vector<Conflict> c = conflictsFor(eventId);
    if (!c.empty()) {
        const std::string other = c[0].firstEventId == eventId ? c[0].secondEventId : c[0].firstEventId;
        return Result::failure("Resolve the clash with " + m_.event(other)->title() + " before publishing.");
    }
    e->setStatus(EventStatus::OnSale);
    const Result saved = m_.persist();
    if (!saved.ok) {
        e->setStatus(EventStatus::Draft);
        return Result::failure("Publishing could not be saved. " + saved.message);
    }
    return Result::success(e->title() + " is now on sale.");
}

} // namespace seatcraft
