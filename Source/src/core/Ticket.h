// Ticket hierarchy — the polymorphism showcase from the brief.
// A booking holds one ticket per seat. Code that totals a booking only
// ever talks to the abstract Ticket; the concrete class decides the category.
#pragma once

#include "Types.h"

#include <memory>
#include <string>

namespace seatcraft {

class Ticket {
public:
    Ticket(std::string id, std::string seatId, int price);
    virtual ~Ticket() = default;

    const std::string& id() const { return id_; }
    const std::string& seatId() const { return seatId_; }

    // The price is fixed when the booking is confirmed, so later price
    // changes never alter the total of an existing booking.
    virtual int calculatePrice() const;
    virtual Category getCategory() const = 0;
    virtual std::string categoryName() const = 0;

    // Factory used by BookingManager and the file loader.
    static std::unique_ptr<Ticket> create(Category category, const std::string& id,
                                          const std::string& seatId, int price);

protected:
    std::string id_;
    std::string seatId_;
    int price_;
};

class RegularTicket : public Ticket {
public:
    using Ticket::Ticket;
    Category getCategory() const override { return Category::Regular; }
    std::string categoryName() const override { return "Regular"; }
};

class VIPTicket : public Ticket {
public:
    using Ticket::Ticket;
    Category getCategory() const override { return Category::VIP; }
    std::string categoryName() const override { return "VIP"; }
};

} // namespace seatcraft
