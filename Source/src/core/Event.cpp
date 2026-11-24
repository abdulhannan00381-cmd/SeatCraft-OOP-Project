#include "Event.h"

namespace seatcraft {

Event::Event(std::string id, std::string title, std::string category, std::string date,
             int startMinutes, int endMinutes, std::string venueId, int vipPrice, int regularPrice,
             EventStatus status)
    : id_(std::move(id)), title_(std::move(title)), category_(std::move(category)), date_(std::move(date)),
      start_(startMinutes), end_(endMinutes), venueId_(std::move(venueId)), vipPrice_(vipPrice),
      regularPrice_(regularPrice), status_(status) {}

std::string Event::timeRange() const {
    return util::formatTime(start_) + " \xE2\x80\x93 " + util::formatTime(end_);
}

std::string Event::displayDate() const { return util::formatDate(date_); }

bool Event::clashesWith(const Event& other) const {
    return id_ != other.id_ && venueId_ == other.venueId_ && date_ == other.date_ &&
           start_ < other.end_ && other.start_ < end_;
}

void Event::moveTo(const std::string& venueId, int start, int end) {
    venueId_ = venueId;
    start_ = start;
    end_ = end;
}

Result Event::validate() const {
    if (id_.empty() || title_.empty()) return Result::failure("An event needs an ID and a title.");
    if (util::hasForbiddenChars(title_) || util::hasForbiddenChars(category_))
        return Result::failure("Event " + id_ + " contains a \"|\" or a line break.");
    if (!util::isValidDate(date_)) return Result::failure("Event " + id_ + " has an invalid date.");
    if (start_ < 0 || end_ > 24 * 60 || end_ <= start_) return Result::failure("Event " + id_ + " must end after it starts, on the same day.");
    if (vipPrice_ <= 0 || regularPrice_ <= 0) return Result::failure("Event " + id_ + " needs positive prices.");
    return Result::success();
}

} // namespace seatcraft
