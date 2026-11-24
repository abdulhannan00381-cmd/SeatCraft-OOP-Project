// Seed data used on first run (when no data file exists yet).
// Matches the approved design: 3 venues, 6 events (one draft that clashes),
// and existing bookings so every screen has realistic content.
#pragma once

#include "BookingManager.h"

namespace seatcraft {

// Production edition: the three venues only — no events, no bookings.
Result populateVenues(BookingManager& manager);

// Demo edition: venues plus the sample programme and its bookings.
Result populateSeedData(BookingManager& manager);

} // namespace seatcraft
