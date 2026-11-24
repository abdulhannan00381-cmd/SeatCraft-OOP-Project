// Customer and Booking. A booking owns its customer details and one
// ticket per selected seat (composition). Cancellation is whole-booking only.
#pragma once

#include "Ticket.h"
#include "Types.h"

#include <memory>
#include <string>
#include <vector>

namespace seatcraft {

class Customer {
public:
    explicit Customer(std::string name) : name_(std::move(name)) {}
    const std::string& name() const { return name_; }

    // Non-blank, at most 60 characters, and no "|" or line breaks.
    static Result validateName(const std::string& name);

private:
    std::string name_;
};

class Booking {
public:
    Booking(std::string id, std::string eventId, Customer customer,
            BookingStatus status = BookingStatus::Confirmed);

    Booking(const Booking&) = delete;
    Booking& operator=(const Booking&) = delete;
    Booking(Booking&&) = default;
    Booking& operator=(Booking&&) = default;

    const std::string& id() const { return id_; }
    const std::string& eventId() const { return eventId_; }
    const Customer& customer() const { return customer_; }
    BookingStatus status() const { return status_; }
    bool isConfirmed() const { return status_ == BookingStatus::Confirmed; }

    const std::vector<std::unique_ptr<Ticket>>& tickets() const { return tickets_; }
    std::vector<std::string> seatIds() const;
    std::string seatList(const std::string& separator = ", ") const;

    // Total through the abstract Ticket interface (polymorphism).
    int total() const;

    void addTicket(std::unique_ptr<Ticket> ticket);

private:
    friend class BookingManager;     // only the manager may cancel or restore
    void setStatus(BookingStatus s) { status_ = s; }

    std::string id_;
    std::string eventId_;
    Customer customer_;
    BookingStatus status_;
    std::vector<std::unique_ptr<Ticket>> tickets_;
};

} // namespace seatcraft
