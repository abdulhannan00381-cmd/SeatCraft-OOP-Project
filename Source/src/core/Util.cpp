#include "Types.h"

#include <cctype>
#include <cstdio>

namespace seatcraft {
namespace util {

std::string trim(const std::string& s) {
    std::size_t b = 0, e = s.size();
    while (b < e && std::isspace(static_cast<unsigned char>(s[b]))) ++b;
    while (e > b && std::isspace(static_cast<unsigned char>(s[e - 1]))) --e;
    return s.substr(b, e - b);
}

std::string toLower(std::string s) {
    for (char& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return s;
}

std::vector<std::string> split(const std::string& s, char sep) {
    std::vector<std::string> parts;
    std::string cur;
    for (char c : s) {
        if (c == sep) { parts.push_back(cur); cur.clear(); }
        else cur += c;
    }
    parts.push_back(cur);
    return parts;
}

std::string formatId(const std::string& prefix, int number) {
    char buf[32];
    std::snprintf(buf, sizeof buf, "%s-%04d", prefix.c_str(), number);
    return buf;
}

int parseIdNumber(const std::string& id, const std::string& prefix) {
    const std::string head = prefix + "-";
    if (id.size() <= head.size() || id.compare(0, head.size(), head) != 0) return -1;
    int n = 0;
    if (!parseInt(id.substr(head.size()), n) || n <= 0) return -1;
    return n;
}

bool parseInt(const std::string& s, int& out) {
    if (s.empty() || s.size() > 9) return false;
    int v = 0;
    for (char c : s) {
        if (c < '0' || c > '9') return false;
        v = v * 10 + (c - '0');
    }
    out = v;
    return true;
}

bool parseTime(const std::string& hhmm, int& minutes) {
    if (hhmm.size() != 5 || hhmm[2] != ':') return false;
    int h = 0, m = 0;
    if (!parseInt(hhmm.substr(0, 2), h) || !parseInt(hhmm.substr(3, 2), m)) return false;
    if (h > 23 || m > 59) return false;
    minutes = h * 60 + m;
    return true;
}

std::string formatTime(int minutes) {
    char buf[8];
    std::snprintf(buf, sizeof buf, "%02d:%02d", (minutes / 60) % 24, minutes % 60);
    return buf;
}

static bool isLeap(int y) { return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0; }

static int daysInMonth(int y, int m) {
    static const int d[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    return (m == 2 && isLeap(y)) ? 29 : d[m - 1];
}

bool isValidDate(const std::string& ymd) {
    if (ymd.size() != 10 || ymd[4] != '-' || ymd[7] != '-') return false;
    int y = 0, m = 0, d = 0;
    if (!parseInt(ymd.substr(0, 4), y) || !parseInt(ymd.substr(5, 2), m) || !parseInt(ymd.substr(8, 2), d)) return false;
    if (y < 2000 || y > 2100 || m < 1 || m > 12) return false;
    return d >= 1 && d <= daysInMonth(y, m);
}

std::string formatDate(const std::string& ymd) {
    if (!isValidDate(ymd)) return ymd;
    int y = 0, m = 0, d = 0;
    parseInt(ymd.substr(0, 4), y);
    parseInt(ymd.substr(5, 2), m);
    parseInt(ymd.substr(8, 2), d);
    // Zeller-style weekday (Sakamoto's method); 0 = Sunday.
    static const int t[] = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};
    int yy = y - (m < 3 ? 1 : 0);
    int wd = (yy + yy / 4 - yy / 100 + yy / 400 + t[m - 1] + d) % 7;
    static const char* days[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
    static const char* months[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
    char buf[32];
    std::snprintf(buf, sizeof buf, "%s %d %s %d", days[wd], d, months[m - 1], y);
    return buf;
}

std::string formatMoney(int rupees) {
    std::string digits = std::to_string(rupees < 0 ? -rupees : rupees);
    std::string out;
    int count = 0;
    for (std::size_t i = digits.size(); i > 0; --i) {
        out.insert(out.begin(), digits[i - 1]);
        if (++count % 3 == 0 && i > 1) out.insert(out.begin(), ',');
    }
    return std::string(rupees < 0 ? "-Rs " : "Rs ") + out;
}

bool hasForbiddenChars(const std::string& s) {
    return s.find('|') != std::string::npos || s.find('\n') != std::string::npos || s.find('\r') != std::string::npos;
}

std::string categoryName(Category c) { return c == Category::VIP ? "VIP" : "Regular"; }
std::string categoryCode(Category c) { return c == Category::VIP ? "VIP" : "REGULAR"; }

bool parseCategoryCode(const std::string& s, Category& out) {
    if (s == "VIP") { out = Category::VIP; return true; }
    if (s == "REGULAR") { out = Category::Regular; return true; }
    return false;
}

} // namespace util
} // namespace seatcraft
