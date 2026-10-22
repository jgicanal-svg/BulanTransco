# Bulan Transport Tracker – Bug Fix Report

## Scope

This revision keeps the existing Laravel + React + Inertia architecture, route mapping, database relationships, trip/assignment workflow, and map geometry format. The changes are targeted at the defects reported in the two supplied capstone bug-report documents. No `migrate:fresh` is required and no existing migration was rewritten.

## Main fixes

### 1. Admin dashboard / fleet summary

- Fixed **Stale/Inactive** so it no longer mirrors the Active Buses count.
- A bus is now counted as stale/inactive when it is explicitly INACTIVE/MAINTENANCE, or when an ACTIVE bus has no current GPS feed / its feed has exceeded the configured inactive threshold.
- Added a visible **Fleet Summary** with **Total Fleet** so the dashboard exposes the overall fleet count, not only operational counters.

Files: `app/Http/Controllers/Admin/DashboardController.php`, `resources/js/Pages/Admin/Dashboard/Index.jsx`

### 2. Vehicle edit did not save capacity 26

- The application previously capped bus capacity at 25 even though the database column can safely store higher values.
- Raised the application-level limit to 100 and kept the same validation structure.
- Added a regression test that updates 25 -> 26.

Files: `app/Models/Bus.php`, `app/Http/Requests/Admin/StoreBusRequest.php`, `app/Http/Requests/Admin/UpdateBusRequest.php`

### 3. Delete Driver missing from Assignment actions

- Added **Delete Driver** to the Assignment Action menu.
- Implemented it as a safe archive/soft-delete rather than destroying historical trip records.
- The active assignment is ended, driver login is disabled, and historical assignments/trips remain intact.
- The action is blocked while that driver has an ACTIVE trip.

Files: `app/Http/Controllers/Admin/AssignmentController.php`, `resources/js/Pages/Admin/Assignments/Index.jsx`, `routes/web.php`

### 4. Stale/offline buses appearing as live

- Admin and public live-location APIs now only expose positions that are within the configured inactive window, belong to an ACTIVE bus, and belong to an ACTIVE trip.
- This prevents very old GPS points from remaining on the live map as if they are current.
- Polling fallback was reduced to 5 seconds so map positions/status refresh without a manual reload even if Reverb/WebSocket is unavailable.

Files: `app/Http/Controllers/Admin/LiveTrackingController.php`, `app/Http/Controllers/Commuter/TrackingController.php`, `resources/js/Pages/Admin/LiveTracking/Index.jsx`, `resources/js/Pages/Commuter/LiveBuses.jsx`

### 5. Route management save reliability

- Route creation/update no longer fails just because the external OSRM road-routing service is temporarily unavailable.
- When OSRM cannot respond, the system creates a fallback route using the same existing `[latitude, longitude]` map geometry format and calculates fallback distance with the Haversine formula.
- This preserves the project's original mapping format and lets route records still save.

File: `app/Services/RoadRoutingService.php`

### 6. Monitoring report filter / generation / printable output

- Applied `bus_id` to **Monthly Bus Travel**, so selecting a vehicle actually filters the result.
- Changed the report action to an explicit **Generate Report** button.
- Added a visible generated-report state.
- Added **Print** support for generated reports and kept CSV export for location history.
- Trip reports now include route, trip date, and GPS point count.

Files: `app/Http/Controllers/Admin/ReportController.php`, `resources/js/Pages/Admin/Reports/Index.jsx`

### 7. Login validation errors not visible

- Explicitly shares session toast data through the Inertia middleware so controller feedback is consistently rendered.
- Existing Inertia validation errors remain displayed directly under Email/Password.
- Added strict full-domain email validation on both Laravel and the HTML form (`344@r` is rejected before authentication).
- Authentication failures, unknown email, and rate-limit messages continue to use the Email field error expected by the test cases.

Files: `app/Http/Middleware/HandleInertiaRequests.php`, `app/Http/Requests/Auth/LoginRequest.php`, `resources/js/Pages/Auth/Login.jsx`

### 8. Inactive/archived drivers could log in

- Login now checks the Driver profile including soft-deleted records.
- INACTIVE or archived drivers are logged out and denied access even if their User record was still marked active.
- Updating a driver synchronizes `users.is_active` with the driver's operational status.
- Archiving a driver disables login; restoring an ACTIVE driver re-enables it.

Files: `app/Http/Requests/Auth/LoginRequest.php`, `app/Http/Controllers/Admin/DriverController.php`

### 9. No-Travel "Other" remarks message

- Kept the backend rule requiring remarks for `Other`.
- Added immediate client-side validation so the exact explanation error is displayed before a request is made.

File: `resources/js/Pages/Driver/MyAssignment.jsx`

### 10. GPS tracking 429 / too many requests

- GPS transmission was moved from an Inertia page visit to a lightweight JSON/Axios request.
- Added an in-flight lock plus a one-request-per-second safety cap; normal tracking still sends when 5 seconds pass **or** the bus moves at least 15 meters.
- A successful point updates `Last Update` and Network/Send State without navigating/reloading the Inertia page.
- Ending a trip stops the geolocation watcher before the stop request, preventing leftover location requests from colliding with End Trip.

Files: `app/Http/Controllers/Driver/TrackingController.php`, `resources/js/Pages/Driver/Tracking.jsx`

### 11. Offline tracking state did not update

- Added browser `online`/`offline` listeners.
- GPS sending now immediately switches to an error state while offline and resumes on the next valid position after connectivity returns.
- Network loss no longer leaves the UI frozen indefinitely on `sending`.

File: `resources/js/Pages/Driver/Tracking.jsx`

### 12. Restored login tab showed raw Inertia JSON

- Authentication pages now send `no-store/no-cache` response headers through `HandleInertiaRequests`.
- This prevents a failed Inertia response from being reused by browser tab/session restoration as raw JSON.

File: `app/Http/Middleware/HandleInertiaRequests.php`

### 13. Vehicle could be deleted during an active trip

- Bus archive/permanent-delete now refuses deletion while an ACTIVE trip references the bus.
- A visible error toast explains that the trip must be ended first.
- If no active trip exists, an active assignment is safely ended before the bus is archived.

File: `app/Http/Controllers/Admin/BusController.php`

### 14. Incomplete trip/history information

- Trip list now includes route, date, GPS point count, departure, arrival, and status.
- Added fleet/trip summary cards so fleet size is visible beside actual trip counts.
- Tracking History now exposes trip status and received timestamp in addition to bus, driver, route, coordinates, accuracy, and recorded time.

Files: `app/Http/Controllers/Admin/TripController.php`, `resources/js/Pages/Admin/Trips/Index.jsx`, `resources/js/Pages/Admin/TrackingHistory/Index.jsx`

### 15. Public homepage/contact usability

- Made the published contact email a clickable `mailto:` link.
- Reduced oversized hero spacing so schedule/fare information becomes accessible earlier in the initial page flow without changing the content hierarchy.

File: `resources/js/Pages/Commuter/Home.jsx`

### 16. Driver mobile responsiveness

- Hardened the Driver layout for narrow screens: truncating header content, hiding the long terminal suffix on extra-small screens, full-width main content, and responsive one-column cards.
- Tracking status cards now collapse to one column on small phones.

Files: `resources/js/Layouts/DriverLayout.jsx`, `resources/js/Pages/Driver/MyAssignment.jsx`, `resources/js/Pages/Driver/Tracking.jsx`

## Genodia report coverage

The second report contains several duplicates/variants of the same underlying defects (live bus missing, GPS not refreshing, coordinate/status not current, login errors missing, assignment/trip/history details incomplete, and driver tracking failures). Those are handled by the shared fixes above rather than by adding separate code paths for every duplicate Bug ID.

Some entries in that report describe invalid/malformed test URLs or test accounts with no active assignment rather than a distinct application defect. The existing canonical routes remain unchanged (`/login`, `/driver/assignment`, `/driver/tracking`, `/admin/...`) so the project mapping is not broken just to accommodate a mistyped test URL.

## Regression tests added

`tests/Feature/BugReportRegressionTest.php` adds coverage for:

- capacity 25 -> 26 update;
- malformed login email;
- inactive driver login denial;
- archived driver login denial;
- Monthly Bus Travel bus filter;
- route save when OSRM is unavailable;
- blocking bus deletion during an active trip;
- Assignment -> Delete Driver safe archive behavior.

## Validation performed in this environment

- PHP syntax lint passed for **120 PHP files** under `app`, `routes`, `tests`, and `database`.
- All modified JSX files were parsed successfully using the installed TypeScript JSX parser.
- The full Laravel/Pest suite could **not** be executed in this sandbox because the uploaded project intentionally excludes `vendor/` and Composer is not installed/available here. `php artisan test` therefore cannot load `vendor/autoload.php` in this environment.
