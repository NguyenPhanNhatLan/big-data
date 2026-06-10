PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS booking_guests;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS hotels;
DROP TABLE IF EXISTS meals;
DROP TABLE IF EXISTS countries;
DROP TABLE IF EXISTS market_segments;
DROP TABLE IF EXISTS distribution_channels;
DROP TABLE IF EXISTS room_types;
DROP TABLE IF EXISTS deposit_types;
DROP TABLE IF EXISTS customer_types;
DROP TABLE IF EXISTS reservation_statuses;
DROP TABLE IF EXISTS agents;
DROP TABLE IF EXISTS companies;

CREATE TABLE countries (
    country_id INTEGER PRIMARY KEY,
    country_code TEXT NOT NULL UNIQUE CHECK (length(country_code) BETWEEN 2 AND 3),
    country_name TEXT
);

CREATE TABLE hotels (
    hotel_id INTEGER PRIMARY KEY,
    hotel_name TEXT NOT NULL UNIQUE,
    address TEXT,
    city TEXT,
    country_id INTEGER,
    phone TEXT,
    email TEXT,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

CREATE TABLE room_types (
    room_type_id INTEGER PRIMARY KEY,
    room_type_code TEXT NOT NULL UNIQUE,
    room_type_name TEXT,
    max_adults INTEGER NOT NULL DEFAULT 2 CHECK (max_adults >= 0),
    max_children INTEGER NOT NULL DEFAULT 0 CHECK (max_children >= 0),
    base_price REAL NOT NULL DEFAULT 0 CHECK (base_price >= 0)
);

CREATE TABLE rooms (
    room_id INTEGER PRIMARY KEY,
    hotel_id INTEGER NOT NULL,
    room_number TEXT NOT NULL,
    room_type_id INTEGER NOT NULL,
    floor INTEGER,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    UNIQUE (hotel_id, room_number),
    FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id),
    FOREIGN KEY (room_type_id) REFERENCES room_types(room_type_id)
);

CREATE TABLE meals (
    meal_id INTEGER PRIMARY KEY,
    meal_code TEXT NOT NULL UNIQUE,
    meal_name TEXT
);

CREATE TABLE market_segments (
    market_segment_id INTEGER PRIMARY KEY,
    segment_name TEXT NOT NULL UNIQUE
);

CREATE TABLE distribution_channels (
    distribution_channel_id INTEGER PRIMARY KEY,
    channel_name TEXT NOT NULL UNIQUE
);

CREATE TABLE deposit_types (
    deposit_type_id INTEGER PRIMARY KEY,
    deposit_type_name TEXT NOT NULL UNIQUE
);

CREATE TABLE customer_types (
    customer_type_id INTEGER PRIMARY KEY,
    customer_type_name TEXT NOT NULL UNIQUE
);

CREATE TABLE reservation_statuses (
    reservation_status_id INTEGER PRIMARY KEY,
    status_name TEXT NOT NULL UNIQUE
);

CREATE TABLE agents (
    agent_id INTEGER PRIMARY KEY,
    agent_name TEXT,
    phone TEXT,
    email TEXT
);

CREATE TABLE companies (
    company_id INTEGER PRIMARY KEY,
    company_name TEXT,
    tax_code TEXT,
    phone TEXT,
    email TEXT
);

CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE,
    phone TEXT,
    country_id INTEGER,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

CREATE TABLE bookings (
    booking_id INTEGER PRIMARY KEY AUTOINCREMENT,
    booking_reference TEXT NOT NULL UNIQUE,
    customer_id INTEGER NOT NULL,
    hotel_id INTEGER NOT NULL,

    booking_created_date TEXT NOT NULL DEFAULT (date('now')) CHECK (booking_created_date LIKE '____-__-__'),
    check_in_date TEXT NOT NULL CHECK (check_in_date LIKE '____-__-__'),
    check_out_date TEXT NOT NULL CHECK (check_out_date LIKE '____-__-__'),
    stays_in_weekend_nights INTEGER NOT NULL DEFAULT 0 CHECK (stays_in_weekend_nights >= 0),
    stays_in_week_nights INTEGER NOT NULL DEFAULT 0 CHECK (stays_in_week_nights >= 0),
    total_nights INTEGER GENERATED ALWAYS AS (
        CAST(julianday(check_out_date) - julianday(check_in_date) AS INTEGER)
    ) STORED,

    adults INTEGER NOT NULL DEFAULT 1 CHECK (adults >= 0),
    children INTEGER NOT NULL DEFAULT 0 CHECK (children >= 0),
    babies INTEGER NOT NULL DEFAULT 0 CHECK (babies >= 0),

    reserved_room_type_id INTEGER NOT NULL,
    assigned_room_type_id INTEGER,
    assigned_room_id INTEGER,
    meal_id INTEGER,
    market_segment_id INTEGER,
    distribution_channel_id INTEGER,
    deposit_type_id INTEGER,
    customer_type_id INTEGER,
    agent_id INTEGER,
    company_id INTEGER,

    is_repeated_guest INTEGER NOT NULL DEFAULT 0 CHECK (is_repeated_guest IN (0, 1)),
    previous_cancellations INTEGER NOT NULL DEFAULT 0 CHECK (previous_cancellations >= 0),
    previous_bookings_not_canceled INTEGER NOT NULL DEFAULT 0 CHECK (previous_bookings_not_canceled >= 0),
    adr REAL NOT NULL DEFAULT 0,
    required_car_parking_spaces INTEGER NOT NULL DEFAULT 0 CHECK (required_car_parking_spaces >= 0),
    total_of_special_requests INTEGER NOT NULL DEFAULT 0 CHECK (total_of_special_requests >= 0),
    special_requests TEXT,
    booking_changes INTEGER NOT NULL DEFAULT 0 CHECK (booking_changes >= 0),
    days_in_waiting_list INTEGER NOT NULL DEFAULT 0 CHECK (days_in_waiting_list >= 0),

    reservation_status_id INTEGER NOT NULL DEFAULT 1,
    reservation_status_date TEXT NOT NULL DEFAULT (date('now')) CHECK (reservation_status_date LIKE '____-__-__'),

    CHECK (julianday(check_out_date) >= julianday(check_in_date)),
    CHECK (total_nights = stays_in_weekend_nights + stays_in_week_nights),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id),
    FOREIGN KEY (reserved_room_type_id) REFERENCES room_types(room_type_id),
    FOREIGN KEY (assigned_room_type_id) REFERENCES room_types(room_type_id),
    FOREIGN KEY (assigned_room_id) REFERENCES rooms(room_id),
    FOREIGN KEY (meal_id) REFERENCES meals(meal_id),
    FOREIGN KEY (market_segment_id) REFERENCES market_segments(market_segment_id),
    FOREIGN KEY (distribution_channel_id) REFERENCES distribution_channels(distribution_channel_id),
    FOREIGN KEY (deposit_type_id) REFERENCES deposit_types(deposit_type_id),
    FOREIGN KEY (customer_type_id) REFERENCES customer_types(customer_type_id),
    FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    FOREIGN KEY (company_id) REFERENCES companies(company_id),
    FOREIGN KEY (reservation_status_id) REFERENCES reservation_statuses(reservation_status_id)
);

CREATE TABLE booking_guests (
    booking_guest_id INTEGER PRIMARY KEY AUTOINCREMENT,
    booking_id INTEGER NOT NULL,
    guest_name TEXT NOT NULL,
    guest_type TEXT NOT NULL DEFAULT 'Adult' CHECK (guest_type IN ('Adult', 'Child', 'Baby')),
    is_primary_guest INTEGER NOT NULL DEFAULT 0 CHECK (is_primary_guest IN (0, 1)),
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE
);

CREATE INDEX idx_rooms_hotel_id ON rooms(hotel_id);
CREATE INDEX idx_rooms_room_type_id ON rooms(room_type_id);
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_bookings_customer_id ON bookings(customer_id);
CREATE INDEX idx_bookings_hotel_dates ON bookings(hotel_id, check_in_date, check_out_date);
CREATE INDEX idx_bookings_status_id ON bookings(reservation_status_id);
CREATE INDEX idx_bookings_agent_id ON bookings(agent_id);
CREATE INDEX idx_bookings_company_id ON bookings(company_id);
CREATE INDEX idx_booking_guests_booking_id ON booking_guests(booking_id);

INSERT INTO hotels (hotel_id, hotel_name) VALUES
    (1, 'City Hotel'),
    (2, 'Resort Hotel');

INSERT INTO meals (meal_id, meal_code, meal_name) VALUES
    (1, 'BB', 'Bed and Breakfast'),
    (2, 'FB', 'Full Board'),
    (3, 'HB', 'Half Board'),
    (4, 'SC', 'Self Catering'),
    (5, 'Undefined', 'Undefined');

INSERT INTO room_types (room_type_id, room_type_code, room_type_name) VALUES
    (1, 'A', 'Room Type A'),
    (2, 'B', 'Room Type B'),
    (3, 'C', 'Room Type C'),
    (4, 'D', 'Room Type D'),
    (5, 'E', 'Room Type E'),
    (6, 'F', 'Room Type F'),
    (7, 'G', 'Room Type G'),
    (8, 'H', 'Room Type H'),
    (9, 'I', 'Room Type I'),
    (10, 'K', 'Room Type K'),
    (11, 'L', 'Room Type L'),
    (12, 'P', 'Room Type P');

INSERT INTO market_segments (market_segment_id, segment_name) VALUES
    (1, 'Direct'),
    (2, 'Corporate'),
    (3, 'Online TA'),
    (4, 'Offline TA/TO'),
    (5, 'Groups'),
    (6, 'Complementary'),
    (7, 'Aviation'),
    (8, 'Undefined');

INSERT INTO distribution_channels (distribution_channel_id, channel_name) VALUES
    (1, 'Direct'),
    (2, 'Corporate'),
    (3, 'TA/TO'),
    (4, 'GDS'),
    (5, 'Undefined');

INSERT INTO deposit_types (deposit_type_id, deposit_type_name) VALUES
    (1, 'No Deposit'),
    (2, 'Non Refund'),
    (3, 'Refundable');

INSERT INTO customer_types (customer_type_id, customer_type_name) VALUES
    (1, 'Transient'),
    (2, 'Contract'),
    (3, 'Transient-Party'),
    (4, 'Group');

INSERT INTO reservation_statuses (reservation_status_id, status_name) VALUES
    (1, 'Booked'),
    (2, 'Canceled'),
    (3, 'Check-Out'),
    (4, 'No-Show');
