#include "Ticket.h"

namespace seatcraft {

Ticket::Ticket(std::string id, std::string seatId, int price)
    : id_(std::move(id)), seatId_(std::move(seatId)), price_(price) {}

int Ticket::calculatePrice() const { return price_; }

std::unique_ptr<Ticket> Ticket::create(Category category, const std::string& id,
                                       const std::string& seatId, int price) {
    if (category == Category::VIP)
        return std::unique_ptr<Ticket>(new VIPTicket(id, seatId, price));
    return std::unique_ptr<Ticket>(new RegularTicket(id, seatId, price));
}

} // namespace seatcraft
