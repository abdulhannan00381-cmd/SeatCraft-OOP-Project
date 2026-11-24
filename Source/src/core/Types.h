// SeatCraft — shared enums, result type and small text helpers.
// The core uses only the C++ standard library so it can be explained,
// tested and run without any GUI toolkit.
#pragma once

#include <string>
#include <vector>

namespace seatcraft {

enum class Category { Regular, VIP };
enum class BookingStatus { Confirmed, Cancelled };
enum class EventStatus { Draft, OnSale };
enum class LayoutType { Fan, Flat, Tiered };
enum class SeatPreference { Any, VIP, Regular };

// Outcome of a command. Commands never throw for user mistakes;
// they return a Result with a message the screen can show as-is.
struct Result {
    bool ok;
    std::string message;

    static Result success(const std::string& msg = std::string()) { return Result{true, msg}; }
    static Result failure(const std::string& msg) { return Result{false, msg}; }
};

namespace util {

std::string trim(const std::string& s);
std::string toLower(std::string s);
std::vector<std::string> split(const std::string& s, char sep);

// "BKG", 13 -> "BKG-0013"
std::string formatId(const std::string& prefix, int number);
// "BKG-0013", "BKG" -> 13 ; returns -1 when the text is not a valid ID
int parseIdNumber(const std::string& id, const std::string& prefix);

bool parseInt(const std::string& s, int& out);
// "15:00" -> 900 minutes after midnight
bool parseTime(const std::string& hhmm, int& minutes);
std::string formatTime(int minutes);
// Accepts YYYY-MM-DD with a real calendar day.
bool isValidDate(const std::string& ymd);
// 2026-11-12 -> "Thu 12 Nov 2026"
std::string formatDate(const std::string& ymd);

// 1600 -> "Rs 1,600"
std::string formatMoney(int rupees);

// Text stored in the data file must not contain the field separator or line breaks.
bool hasForbiddenChars(const std::string& s);

std::string categoryName(Category c);
std::string categoryCode(Category c); // REGULAR / VIP (file format)
bool parseCategoryCode(const std::string& s, Category& out);

} // namespace util
} // namespace seatcraft
