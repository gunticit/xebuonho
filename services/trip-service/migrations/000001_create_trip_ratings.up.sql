-- 000001_create_trip_ratings.up.sql
-- Trip ratings: customer & driver ratings per completed order.
-- Owned by trip-service; trips themselves are a read-model over the unified orders table.

CREATE TABLE IF NOT EXISTS trip_ratings (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id     UUID NOT NULL,
    customer_id  UUID,
    driver_id    UUID,
    rated_by     UUID NOT NULL,
    rated_role   VARCHAR(20) NOT NULL CHECK (rated_role IN ('rider', 'driver')),
    rating       SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    tip_amount   NUMERIC(12,2) DEFAULT 0,
    comment      TEXT,
    created_at   TIMESTAMPTZ DEFAULT NOW(),

    -- One rating per rater per order (upsert target)
    CONSTRAINT uq_trip_ratings_order_rater UNIQUE (order_id, rated_by)
);

CREATE INDEX idx_trip_ratings_driver ON trip_ratings(driver_id, rated_role);
CREATE INDEX idx_trip_ratings_order ON trip_ratings(order_id);
