#include "Booking.h"

namespace seatcraft {

Result Customer::validateName(const std::string& name) {
    const std::string t = util::trim(name);
    if (t.empty()) return Result::failure("Please enter the customer name.");
    if (t.size() > 60) return Result::failure("The customer name can be at most 60 characters.");
    if (util::hasForbiddenChars(t)) return Result::failure("Please remove the \"|\" character or line breaks from the name.");
    return Result::success();
}

Booking::Booking(std::string id, std::string eventId, Customer customer, BookingStatus status)
    : id_(std::move(id)), eventId_(std::move(eventId)), customer_(std::move(customer)), status_(status) {}

std::vector<std::string> Booking::seatIds() const {
    std::vector<std::string> ids;
    for (const auto& t : tickets_) ids.push_back(t->seatId());
    return ids;
}

std::string Booking::seatList(const std::string& separator) const {
    std::string out;
    for (const auto& t : tickets_) {
        if (!out.empty()) out += separator;
        out += t->seatId();
    }
    return out;
}

int Booking::total() const {
    int sum = 0;
    for (const auto& t : tickets_) sum += t->calculatePrice();
    return sum;
}

void Booking::addTicket(std::unique_ptr<Ticket> ticket) { tickets_.push_back(std::move(ticket)); }

} // namespace seatcraft
