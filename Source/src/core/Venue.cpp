#include "Venue.h"

#include <cmath>

namespace seatcraft {

namespace {
const double kPi = 3.14159265358979323846;

// Geometry constants match the approved design (see the engineering handoff).
const double kFanRadii[] = {430, 478, 546, 594, 642, 690, 738, 786};      // gap after B = cross aisle
const double kTierRadii[] = {230, 274, 318, 362, 406, 450, 494, 538};
} // namespace

Seat::Seat(char row, int number, Category category) : row_(row), number_(number), category_(category) {}

std::string Seat::id() const { return std::string(1, row_) + std::to_string(number_); }

Venue::Venue(std::string id, std::string name, LayoutType layout, std::string rows,
             int seatsPerRow, std::string vipRows, int aisleAfter)
    : id_(std::move(id)), name_(std::move(name)), layout_(layout), rows_(std::move(rows)),
      seatsPerRow_(seatsPerRow), vipRows_(std::move(vipRows)), aisleAfter_(aisleAfter) {
    for (char r : rows_) {
        const Category c = vipRows_.find(r) != std::string::npos ? Category::VIP : Category::Regular;
        for (int n = 1; n <= seatsPerRow_; ++n) seats_.emplace_back(r, n, c);
    }
}

bool Venue::parseSeatId(const std::string& seatId, char& row, int& number) {
    if (seatId.size() < 2 || seatId[0] < 'A' || seatId[0] > 'Z') return false;
    if (seatId[1] == '0') return false;
    if (!util::parseInt(seatId.substr(1), number)) return false;
    row = seatId[0];
    return number > 0;
}

int Venue::rowIndex(char row) const {
    const std::size_t i = rows_.find(row);
    return i == std::string::npos ? -1 : static_cast<int>(i);
}

bool Venue::hasSeat(const std::string& seatId) const {
    char r = 0;
    int n = 0;
    return parseSeatId(seatId, r, n) && rowIndex(r) >= 0 && n <= seatsPerRow_;
}

Category Venue::categoryOf(const std::string& seatId) const {
    return (!seatId.empty() && vipRows_.find(seatId[0]) != std::string::npos) ? Category::VIP : Category::Regular;
}

SeatPose Venue::pose(int rowIndex, int seatNo) const {
    if (layout_ == LayoutType::Flat) {
        const double mid = (seatsPerRow_ + 1) / 2.0;
        const double gap = seatNo <= aisleAfter_ ? -22.0 : 22.0;
        return SeatPose{460 + (seatNo - mid) * 54 + gap, 160.0 + rowIndex * 66, 0.0};
    }
    const bool fan = layout_ == LayoutType::Fan;
    const double r = fan ? kFanRadii[rowIndex] : kTierRadii[rowIndex];
    const double cy = fan ? -270 : -20;
    const double pitch = fan ? 44 : 36;
    const double halfAisle = fan ? 17 : 18;
    const int k = seatNo <= aisleAfter_ ? aisleAfter_ - seatNo : seatNo - aisleAfter_ - 1;
    const int side = seatNo <= aisleAfter_ ? -1 : 1;
    const double a = side * (halfAisle + (k + 0.5) * pitch) / r;
    return SeatPose{460 + r * std::sin(a), cy + r * std::cos(a), -a * 180.0 / kPi};
}

double Venue::distanceToStageMetres(char row) const {
    const int i = rowIndex(row);
    if (i < 0) return 0;
    switch (layout_) {
    case LayoutType::Fan: {
        static const double d[] = {4.0, 5.0, 6.4, 7.4, 8.4, 9.4, 10.4, 11.4};
        return d[i];
    }
    case LayoutType::Flat:
        return 3.0 + 1.2 * i;
    case LayoutType::Tiered:
        return 5.0 + 1.5 * i;
    }
    return 0;
}

std::string Venue::preferredRows(SeatPreference pref) const {
    if (pref == SeatPreference::VIP) return vipRows_;
    std::string regular;
    for (char r : rows_)
        if (vipRows_.find(r) == std::string::npos) regular += r;
    if (pref == SeatPreference::Regular) return regular;
    // Any: the first regular row is usually the sweet spot, then the VIP row
    // behind it, then the remaining regular rows, then the front VIP rows.
    std::string order;
    if (!regular.empty()) order += regular[0];
    if (!vipRows_.empty()) order += vipRows_.back();
    for (char r : regular)
        if (order.find(r) == std::string::npos) order += r;
    for (char r : vipRows_)
        if (order.find(r) == std::string::npos) order += r;
    return order;
}

Result Venue::validate() const {
    if (id_.empty() || name_.empty()) return Result::failure("Venue needs an ID and a name.");
    const int maxRows = 8;
    if (rows_.empty() || static_cast<int>(rows_.size()) > maxRows) return Result::failure("Venue " + id_ + " must have 1 to 8 rows.");
    for (std::size_t i = 0; i < rows_.size(); ++i) {
        if (rows_[i] < 'A' || rows_[i] > 'Z' || rows_.find(rows_[i], i + 1) != std::string::npos)
            return Result::failure("Venue " + id_ + " has invalid or repeated row letters.");
    }
    for (char r : vipRows_)
        if (rows_.find(r) == std::string::npos) return Result::failure("Venue " + id_ + " lists a VIP row that does not exist.");
    if (seatsPerRow_ < 2 || seatsPerRow_ > 20) return Result::failure("Venue " + id_ + " must have 2 to 20 seats per row.");
    if (aisleAfter_ < 1 || aisleAfter_ >= seatsPerRow_) return Result::failure("Venue " + id_ + " has its aisle outside the row.");
    return Result::success();
}

std::string Venue::layoutCode(LayoutType layout) {
    switch (layout) {
    case LayoutType::Fan: return "FAN";
    case LayoutType::Flat: return "FLAT";
    case LayoutType::Tiered: return "TIERED";
    }
    return "FLAT";
}

bool Venue::parseLayoutCode(const std::string& s, LayoutType& out) {
    if (s == "FAN") { out = LayoutType::Fan; return true; }
    if (s == "FLAT") { out = LayoutType::Flat; return true; }
    if (s == "TIERED") { out = LayoutType::Tiered; return true; }
    return false;
}

} // namespace seatcraft
