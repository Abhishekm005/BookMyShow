# BookMyShow-Scale Ticketing Backend — P1 & P2

## Files
- `submission.docx`: polished submission document.
- `schema.sql`: executable MySQL 8.0+ DDL, indexes, constraints, seed data, P2 query and concurrency examples.

## Run
1. Install MySQL 8.0+.
2. Open MySQL Workbench or MySQL CLI and DBeaver CE.
3. Run `schema.sql`.
4. The script creates the `bookmyshow` database and all tables/sample data.
5. The P2 query is included at the bottom.

## Concurrency design
`show_seats` is the authoritative seat inventory: exactly one row exists per `(show_id, seat_id)`. A hold transaction locks requested rows with `SELECT ... FOR UPDATE`, in deterministic seat order, checks availability/expiry, then changes the rows to `HELD` and records an expiry. This prevents two concurrent buyers from successfully acquiring the same seat.

Expired holds are released by a worker/queue. The acquisition transaction must also validate expiry, so correctness does not depend on the cleanup worker running at the exact expiry time.

Payment webhooks use `payment_webhook_events` with a unique `(event_id, provider)` key. Duplicate delivery of the same provider event becomes a no-op.

## Normalization
The schema separates theatre, screen, seat, movie, show-date, show, show-seat, user, hold, booking, booking-seat, payment and webhook-event facts. Composite relationship tables use composite keys. Non-key attributes depend on their full candidate key and transitive dependencies are separated into their own relations.

## Indexing
Theatre/date lookup uses `show_dates(theatre_id, show_date)`. Schedule reads use `shows(show_date_id, screen_id, start_time)`. Seat availability/expiry workers use `show_seats(show_id,status)` and `show_seats(status,hold_expires_at)`. Booking and webhook access paths are indexed.

## Production notes
Use InnoDB, short transactions, deterministic lock ordering and retry on deadlock. Redis may be used as a fast TTL/hold layer, but the durable database transaction must protect the authoritative inventory unless a deliberately designed distributed consistency model is used.
