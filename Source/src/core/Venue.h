// Venue and Seat — composition: a venue has seats.
// The venue also knows its seat geometry so every screen (and the terminal
// fallback) draws the same plan from one source of truth.
#pragma once

#include "Types.h"

#include <string>
#include <vector>

namespace seatcraft {

class Seat {
public:
    Seat(char row, int number, Category category);

    std::string id() const;            // "C5"
    char row() const { return row_; }
    int number() const { return number_; }
    Category category() const { return category_; }

private:
    char row_;
    int number_;
    Category category_;
};

// Position of one seat centre inside a 920 x 470 plan, plus the rotation
// that makes the seat face the stage.
struct SeatPose {
    double x;
    double y;
    double rotationDeg;
};

class Venue {
public:
    Venue(std::string id, std::string name, LayoutType layout, std::string rows,
          int seatsPerRow, std::string vipRows, int aisleAfter);

    const std::string& id() const { return id_; }
    const std::string& name() const { return name_; }
    LayoutType layout() const { return layout_; }
    const std::string& rows() const { return rows_; }
    int seatsPerRow() const { return seatsPerRow_; }
    const std::string& vipRows() const { return vipRows_; }
    int aisleAfter() const { return aisleAfter_; }
    int capacity() const { return static_cast<int>(seats_.size()); }
    int vipCapacity() const { return static_cast<int>(vipRows_.size()) * seatsPerRow_; }
    const std::vector<Seat>& seats() const { return seats_; }

    bool hasSeat(const std::string& seatId) const;
    Category categoryOf(const std::string& seatId) const;   // call hasSeat first
    int rowIndex(char row) const;                           // -1 if unknown

    SeatPose pose(int rowIndex, int seatNo) const;
    double distanceToStageMetres(char row) const;

    // Rows in the order "Best seats together" tries them for a preference.
    std::string preferredRows(SeatPreference pref) const;

    // Validates the definition (rows unique A–Z, VIP rows exist, aisle inside row).
    Result validate() const;

    static bool parseSeatId(const std::string& seatId, char& row, int& number);
    static std::string layoutCode(LayoutType layout);       // FAN / FLAT / TIERED
    static bool parseLayoutCode(const std::string& s, LayoutType& out);

private:
    std::string id_;
    std::string name_;
    LayoutType layout_;
    std::string rows_;
    int seatsPerRow_;
    std::string vipRows_;
    int aisleAfter_;
    std::vector<Seat> seats_;
};

} // namespace seatcraft
