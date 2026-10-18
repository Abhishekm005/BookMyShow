-- BookMyShow-scale ticketing backend | MySQL 8.0+
DROP DATABASE IF EXISTS bookmyshow;
CREATE DATABASE bookmyshow;
USE bookmyshow;
SET NAMES utf8mb4;

CREATE TABLE theatres (
 theatre_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 theatre_name VARCHAR(150) NOT NULL,
 city VARCHAR(100) NOT NULL,
 address VARCHAR(255) NOT NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 INDEX idx_theatres_city_name(city,theatre_name)
) ENGINE=InnoDB;

CREATE TABLE screens (
 screen_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 theatre_id BIGINT UNSIGNED NOT NULL,
 screen_name VARCHAR(100) NOT NULL,
 capacity INT UNSIGNED NOT NULL,
 UNIQUE KEY uq_screen_name_per_theatre(theatre_id,screen_name),
 FOREIGN KEY(theatre_id) REFERENCES theatres(theatre_id),
 CHECK(capacity > 0)
) ENGINE=InnoDB;

CREATE TABLE seats (
 seat_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 screen_id BIGINT UNSIGNED NOT NULL,
 row_label VARCHAR(10) NOT NULL,
 seat_number INT UNSIGNED NOT NULL,
 seat_type ENUM('REGULAR','PREMIUM','RECLINER') NOT NULL DEFAULT 'REGULAR',
 UNIQUE KEY uq_seat_position(screen_id,row_label,seat_number),
 INDEX idx_seats_screen(screen_id),
 FOREIGN KEY(screen_id) REFERENCES screens(screen_id),
 CHECK(seat_number > 0)
) ENGINE=InnoDB;

CREATE TABLE movies (
 movie_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 title VARCHAR(200) NOT NULL,
 language VARCHAR(50) NOT NULL,
 duration_minutes SMALLINT UNSIGNED NOT NULL,
 certificate VARCHAR(20) NOT NULL,
 release_date DATE NULL,
 INDEX idx_movies_title(title),
 CHECK(duration_minutes > 0)
) ENGINE=InnoDB;

CREATE TABLE show_dates (
 show_date_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 theatre_id BIGINT UNSIGNED NOT NULL,
 show_date DATE NOT NULL,
 UNIQUE KEY uq_theatre_show_date(theatre_id,show_date),
 INDEX idx_show_dates_theatre_date(theatre_id,show_date),
 FOREIGN KEY(theatre_id) REFERENCES theatres(theatre_id)
) ENGINE=InnoDB;

CREATE TABLE shows (
 show_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 movie_id BIGINT UNSIGNED NOT NULL,
 screen_id BIGINT UNSIGNED NOT NULL,
 show_date_id BIGINT UNSIGNED NOT NULL,
 start_time DATETIME NOT NULL,
 end_time DATETIME NOT NULL,
 status ENUM('SCHEDULED','CANCELLED','COMPLETED') NOT NULL DEFAULT 'SCHEDULED',
 INDEX idx_shows_date_screen_time(show_date_id,screen_id,start_time),
 INDEX idx_shows_movie_date(movie_id,show_date_id),
 FOREIGN KEY(movie_id) REFERENCES movies(movie_id),
 FOREIGN KEY(screen_id) REFERENCES screens(screen_id),
 FOREIGN KEY(show_date_id) REFERENCES show_dates(show_date_id),
 CHECK(end_time > start_time)
) ENGINE=InnoDB;

CREATE TABLE show_seats (
 show_id BIGINT UNSIGNED NOT NULL,
 seat_id BIGINT UNSIGNED NOT NULL,
 status ENUM('AVAILABLE','HELD','BOOKED') NOT NULL DEFAULT 'AVAILABLE',
 hold_id CHAR(36) NULL,
 hold_expires_at DATETIME(6) NULL,
 booking_id BIGINT UNSIGNED NULL,
 version BIGINT UNSIGNED NOT NULL DEFAULT 0,
 PRIMARY KEY(show_id,seat_id),
 INDEX idx_show_seats_status(show_id,status),
 INDEX idx_show_seats_hold_expiry(status,hold_expires_at),
 INDEX idx_show_seats_booking(booking_id),
 FOREIGN KEY(show_id) REFERENCES shows(show_id),
 FOREIGN KEY(seat_id) REFERENCES seats(seat_id)
) ENGINE=InnoDB;

CREATE TABLE users (
 user_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 full_name VARCHAR(150) NOT NULL,
 email VARCHAR(254) NOT NULL UNIQUE,
 phone VARCHAR(30) NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE holds (
 hold_id CHAR(36) PRIMARY KEY,
 user_id BIGINT UNSIGNED NOT NULL,
 show_id BIGINT UNSIGNED NOT NULL,
 status ENUM('ACTIVE','EXPIRED','CONVERTED','CANCELLED') NOT NULL DEFAULT 'ACTIVE',
 expires_at DATETIME(6) NOT NULL,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 INDEX idx_holds_expiry_status(status,expires_at),
 INDEX idx_holds_user_show(user_id,show_id),
 FOREIGN KEY(user_id) REFERENCES users(user_id),
 FOREIGN KEY(show_id) REFERENCES shows(show_id)
) ENGINE=InnoDB;

CREATE TABLE bookings (
 booking_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 booking_reference VARCHAR(32) NOT NULL UNIQUE,
 user_id BIGINT UNSIGNED NOT NULL,
 show_id BIGINT UNSIGNED NOT NULL,
 hold_id CHAR(36) NOT NULL UNIQUE,
 status ENUM('PENDING_PAYMENT','CONFIRMED','CANCELLED','PAYMENT_FAILED') NOT NULL DEFAULT 'PENDING_PAYMENT',
 total_amount DECIMAL(10,2) NOT NULL,
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 INDEX idx_bookings_show_status(show_id,status),
 INDEX idx_bookings_user_created(user_id,created_at),
 FOREIGN KEY(user_id) REFERENCES users(user_id),
 FOREIGN KEY(show_id) REFERENCES shows(show_id),
 FOREIGN KEY(hold_id) REFERENCES holds(hold_id),
 CHECK(total_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE booking_seats (
 booking_id BIGINT UNSIGNED NOT NULL,
 seat_id BIGINT UNSIGNED NOT NULL,
 price DECIMAL(10,2) NOT NULL,
 PRIMARY KEY(booking_id,seat_id),
 FOREIGN KEY(booking_id) REFERENCES bookings(booking_id),
 FOREIGN KEY(seat_id) REFERENCES seats(seat_id),
 CHECK(price >= 0)
) ENGINE=InnoDB;

CREATE TABLE payments (
 payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 booking_id BIGINT UNSIGNED NOT NULL,
 provider VARCHAR(50) NOT NULL,
 provider_payment_id VARCHAR(150) NULL,
 amount DECIMAL(10,2) NOT NULL,
 status ENUM('CREATED','AUTHORIZED','CAPTURED','FAILED','REFUNDED') NOT NULL DEFAULT 'CREATED',
 created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
 UNIQUE KEY uq_provider_payment(provider,provider_payment_id),
 INDEX idx_payments_booking_status(booking_id,status),
 FOREIGN KEY(booking_id) REFERENCES bookings(booking_id),
 CHECK(amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE payment_webhook_events (
 event_id VARCHAR(150) NOT NULL,
 provider VARCHAR(50) NOT NULL,
 event_type VARCHAR(100) NOT NULL,
 received_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
 processed_at DATETIME(6) NULL,
 status ENUM('RECEIVED','PROCESSED','IGNORED','FAILED') NOT NULL DEFAULT 'RECEIVED',
 PRIMARY KEY(event_id,provider),
 INDEX idx_webhook_status_time(status,received_at)
) ENGINE=InnoDB;

INSERT INTO theatres(theatre_name,city,address) VALUES
('PVR Pacific Mall','Dehradun','Pacific Mall, Jakhan, Dehradun'),
('INOX City Centre','Dehradun','City Centre, Rajpur Road, Dehradun');

INSERT INTO screens(theatre_id,screen_name,capacity) VALUES
(1,'Audi 1',120),(1,'Audi 2',100),(2,'Screen 1',150);

INSERT INTO seats(screen_id,row_label,seat_number,seat_type) VALUES
(1,'A',1,'PREMIUM'),(1,'A',2,'PREMIUM'),(1,'A',3,'PREMIUM'),
(1,'B',1,'PREMIUM'),(1,'B',2,'PREMIUM'),(1,'B',3,'PREMIUM'),
(1,'C',1,'REGULAR'),(1,'C',2,'REGULAR'),(1,'C',3,'REGULAR'),
(1,'D',1,'REGULAR'),(1,'D',2,'REGULAR'),(1,'D',3,'REGULAR'),
(2,'A',1,'PREMIUM'),(2,'A',2,'PREMIUM'),(2,'B',1,'REGULAR'),
(3,'A',1,'PREMIUM'),(3,'A',2,'PREMIUM');

INSERT INTO movies(title,language,duration_minutes,certificate,release_date) VALUES
('The Last Horizon','English',132,'UA','2026-09-25'),
('Metro Dreams','Hindi',145,'UA','2026-09-20'),
('Ocean Planet','English',118,'U','2026-09-10');

INSERT INTO show_dates(theatre_id,show_date) VALUES
(1,'2026-10-01'),(1,'2026-10-02'),(1,'2026-10-03'),(2,'2026-10-01');

INSERT INTO shows(movie_id,screen_id,show_date_id,start_time,end_time) VALUES
(1,1,1,'2026-10-01 10:00:00','2026-10-01 12:12:00'),
(2,1,1,'2026-10-01 13:00:00','2026-10-01 15:25:00'),
(3,1,1,'2026-10-01 16:00:00','2026-10-01 17:58:00'),
(1,1,1,'2026-10-01 18:30:00','2026-10-01 20:42:00'),
(2,1,2,'2026-10-02 12:00:00','2026-10-02 14:25:00'),
(1,1,3,'2026-10-03 19:00:00','2026-10-03 21:12:00'),
(3,3,4,'2026-10-01 20:00:00','2026-10-01 21:58:00');

INSERT INTO show_seats(show_id,seat_id)
SELECT sh.show_id,s.seat_id FROM shows sh JOIN seats s ON s.screen_id=sh.screen_id;

INSERT INTO users(full_name,email,phone) VALUES
('Aarav Sharma','aarav@example.com','9000000001'),
('Priya Verma','priya@example.com','9000000002');

INSERT INTO holds(hold_id,user_id,show_id,status,expires_at)
VALUES('11111111-1111-1111-1111-111111111111',1,1,'ACTIVE','2026-10-01 09:15:00');

-- P2: replace the two parameters with values, e.g. theatre_id=1 and date='2026-10-01'
SELECT sh.show_id,m.title AS movie_name,m.language,m.certificate,
       TIME(sh.start_time) AS show_time,TIME(sh.end_time) AS end_time,
       sc.screen_name,sh.status
FROM shows sh
JOIN movies m ON m.movie_id=sh.movie_id
JOIN screens sc ON sc.screen_id=sh.screen_id
JOIN show_dates sd ON sd.show_date_id=sh.show_date_id
WHERE sd.theatre_id = 1
  AND sd.show_date = '2026-10-01'
  AND sh.status = 'SCHEDULED'
ORDER BY sh.start_time;

-- Concurrency example: inside START TRANSACTION:
-- SELECT * FROM show_seats
-- WHERE show_id=:show_id AND seat_id IN (:seat1,:seat2)
-- ORDER BY seat_id FOR UPDATE;
-- Validate each row is AVAILABLE (or its hold is expired), then update to HELD.
-- Keep this transaction short and retry the whole transaction on deadlock.
--
-- Expiry worker:
-- UPDATE show_seats SET status='AVAILABLE',hold_id=NULL,hold_expires_at=NULL,version=version+1
-- WHERE status='HELD' AND hold_expires_at < NOW(6);
--
-- Webhook idempotency:
-- INSERT INTO payment_webhook_events(event_id,provider,event_type)
-- VALUES(:event_id,:provider,:event_type)
-- ON DUPLICATE KEY UPDATE event_id=event_id;
