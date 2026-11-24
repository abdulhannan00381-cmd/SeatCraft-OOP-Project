// Event — one scheduled performance in one venue.
#pragma once

#include "Types.h"

#include <string>

namespace seatcraft {

class Event {
public:
    Event(std::string id, std::string title, std::string category, std::string date,
          int startMinutes, int endMinutes, std::string venueId, int vipPrice, int regularPrice,
          EventStatus status);

    const std::string& id() const { return id_; }
    const std::string& title() const { return title_; }
    const std::string& category() const { return category_; }
    const std::string& date() const { return date_; }          // YYYY-MM-DD
    int start() const { return start_; }                        // minutes after midnight
    int end() const { return end_; }
    const std::string& venueId() const { return venueId_; }
    int vipPrice() const { return vipPrice_; }
    int regularPrice() const { return regularPrice_; }
    EventStatus status() const { return status_; }
    bool isOnSale() const { return status_ == EventStatus::OnSale; }

    int priceFor(Category c) const { return c == Category::VIP ? vipPrice_ : regularPrice_; }
    std::string timeRange() const;      // "15:00 – 17:00"
    std::string displayDate() const;    // "Thu 12 Nov 2026"

    // Scheduling rule: same venue, same date and overlapping half-open
    // intervals [start, end). Back-to-back events (17:00 end, 17:00 start) do not clash.
    bool clashesWith(const Event& other) const;

    Result validate() const;

private:
    friend class ScheduleManager;      // only the schedule may move or publish an event
    void moveTo(const std::string& venueId, int start, int end);
    void setStatus(EventStatus s) { status_ = s; }

    std::string id_;
    std::string title_;
    std::string category_;
    std::string date_;
    int start_;
    int end_;
    std::string venueId_;
    int vipPrice_;
    int regularPrice_;
    EventStatus status_;
};

} // namespace seatcraft
