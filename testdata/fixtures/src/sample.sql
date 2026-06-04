-- sample.sql — comprehensive SQL syntax fixture for parser testing.
-- Covers: DDL (CREATE, ALTER, DROP), DML (INSERT, UPDATE, DELETE, MERGE),
-- DQL (SELECT with JOINs, CTEs, window functions, subqueries, aggregates),
-- indexes, views, procedures, functions, triggers, transactions, grants.

-- -------------------------------------------------------------------------- --
-- Schema: DDL                                                                 --
-- -------------------------------------------------------------------------- --

CREATE SCHEMA IF NOT EXISTS app;

CREATE TYPE app.status_enum AS ENUM (
    'pending', 'running', 'done', 'failed'
);

CREATE TABLE IF NOT EXISTS app.users (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(255) NOT NULL UNIQUE,
    role        VARCHAR(50)  NOT NULL DEFAULT 'member',
    status      app.status_enum NOT NULL DEFAULT 'pending',
    metadata    JSONB,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_users_name_length CHECK (char_length(name) >= 1),
    CONSTRAINT chk_users_email_format CHECK (email ~ '^[^@]+@[^@]+$')
);

CREATE TABLE IF NOT EXISTS app.products (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    sku         VARCHAR(64)  NOT NULL UNIQUE,
    name        VARCHAR(200) NOT NULL,
    price       NUMERIC(12, 2) NOT NULL,
    stock       INTEGER      NOT NULL DEFAULT 0,
    tags        TEXT[]       NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_products_price_positive CHECK (price > 0),
    CONSTRAINT chk_products_stock_non_negative CHECK (stock >= 0)
);

CREATE TABLE IF NOT EXISTS app.orders (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID         NOT NULL REFERENCES app.users(id) ON DELETE RESTRICT,
    status      app.status_enum NOT NULL DEFAULT 'pending',
    total       NUMERIC(14, 2) NOT NULL DEFAULT 0,
    notes       TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app.order_items (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id    UUID         NOT NULL REFERENCES app.orders(id) ON DELETE CASCADE,
    product_id  UUID         NOT NULL REFERENCES app.products(id),
    quantity    INTEGER      NOT NULL,
    unit_price  NUMERIC(12, 2) NOT NULL,

    CONSTRAINT chk_order_items_quantity CHECK (quantity > 0),
    UNIQUE (order_id, product_id)
);

-- -------------------------------------------------------------------------- --
-- Indexes                                                                     --
-- -------------------------------------------------------------------------- --

CREATE INDEX idx_users_email    ON app.users (email);
CREATE INDEX idx_users_status   ON app.users (status) WHERE status != 'done';
CREATE INDEX idx_orders_user    ON app.orders (user_id, created_at DESC);
CREATE INDEX idx_products_tags  ON app.products USING GIN (tags);
CREATE INDEX idx_users_metadata ON app.users USING GIN (metadata);

-- -------------------------------------------------------------------------- --
-- ALTER TABLE                                                                 --
-- -------------------------------------------------------------------------- --

ALTER TABLE app.users
    ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
    ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

ALTER TABLE app.orders
    ADD CONSTRAINT chk_orders_total_non_negative CHECK (total >= 0);

-- -------------------------------------------------------------------------- --
-- Views                                                                       --
-- -------------------------------------------------------------------------- --

CREATE OR REPLACE VIEW app.active_users AS
SELECT
    id,
    name,
    email,
    role,
    created_at
FROM app.users
WHERE status = 'running';

CREATE OR REPLACE VIEW app.order_summary AS
SELECT
    o.id          AS order_id,
    u.name        AS user_name,
    u.email       AS user_email,
    o.status,
    o.total,
    COUNT(oi.id)  AS item_count,
    o.created_at
FROM app.orders  o
JOIN app.users   u  ON o.user_id   = u.id
JOIN app.order_items oi ON oi.order_id = o.id
GROUP BY o.id, u.name, u.email, o.status, o.total, o.created_at;

-- -------------------------------------------------------------------------- --
-- DML: INSERT                                                                 --
-- -------------------------------------------------------------------------- --

INSERT INTO app.users (name, email, role)
VALUES
    ('Alice',   'alice@example.com',   'admin'),
    ('Bob',     'bob@example.com',     'member'),
    ('Carol',   'carol@example.com',   'member'),
    ('Dave',    'dave@example.com',    'guest')
ON CONFLICT (email)
DO UPDATE SET
    name       = EXCLUDED.name,
    updated_at = NOW();

INSERT INTO app.products (sku, name, price, stock, tags)
VALUES
    ('WIDGET-001', 'Blue Widget',  9.99,  100, ARRAY['widget', 'blue']),
    ('GADGET-001', 'Smart Gadget', 49.99,  50, ARRAY['gadget', 'smart']),
    ('GIZMO-001',  'Mini Gizmo',   4.99,  200, ARRAY['gizmo', 'mini']);

-- -------------------------------------------------------------------------- --
-- DML: UPDATE                                                                 --
-- -------------------------------------------------------------------------- --

UPDATE app.users
SET
    status     = 'running',
    updated_at = NOW()
WHERE role = 'admin'
  AND status  = 'pending';

-- Conditional UPDATE using CASE
UPDATE app.products
SET price = CASE
    WHEN stock > 100 THEN price * 0.9
    WHEN stock = 0   THEN price * 1.2
    ELSE price
END
WHERE price > 5;

-- -------------------------------------------------------------------------- --
-- DML: DELETE                                                                 --
-- -------------------------------------------------------------------------- --

DELETE FROM app.users
WHERE status = 'failed'
  AND created_at < NOW() - INTERVAL '90 days';

-- -------------------------------------------------------------------------- --
-- DML: MERGE (SQL:2003 / PostgreSQL 15+)                                     --
-- -------------------------------------------------------------------------- --

MERGE INTO app.users AS target
USING (
    VALUES
        ('eve@example.com', 'Eve',   'member'),
        ('frank@example.com', 'Frank', 'guest')
) AS source (email, name, role)
ON target.email = source.email
WHEN MATCHED THEN
    UPDATE SET name = source.name, updated_at = NOW()
WHEN NOT MATCHED THEN
    INSERT (name, email, role) VALUES (source.name, source.email, source.role);

-- -------------------------------------------------------------------------- --
-- DQL: SELECT — JOINs                                                         --
-- -------------------------------------------------------------------------- --

SELECT
    u.id,
    u.name,
    u.email,
    COUNT(o.id)           AS order_count,
    COALESCE(SUM(o.total), 0) AS lifetime_value
FROM app.users u
LEFT  JOIN app.orders o ON o.user_id = u.id AND o.status = 'done'
GROUP BY u.id, u.name, u.email
HAVING COUNT(o.id) > 0
ORDER BY lifetime_value DESC
LIMIT 10;

-- -------------------------------------------------------------------------- --
-- DQL: CTEs & window functions                                                --
-- -------------------------------------------------------------------------- --

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.created_at) AS month,
        SUM(o.total)                      AS revenue,
        COUNT(DISTINCT o.user_id)         AS unique_buyers
    FROM app.orders o
    WHERE o.status = 'done'
    GROUP BY DATE_TRUNC('month', o.created_at)
),
ranked AS (
    SELECT
        month,
        revenue,
        unique_buyers,
        ROW_NUMBER()   OVER (ORDER BY revenue DESC) AS rank,
        LAG(revenue)   OVER (ORDER BY month)        AS prev_revenue,
        SUM(revenue)   OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
    FROM monthly_revenue
)
SELECT
    month,
    revenue,
    unique_buyers,
    rank,
    ROUND(100.0 * (revenue - prev_revenue) / NULLIF(prev_revenue, 0), 2) AS pct_change,
    running_total
FROM ranked
ORDER BY month;

-- -------------------------------------------------------------------------- --
-- DQL: Subqueries                                                             --
-- -------------------------------------------------------------------------- --

SELECT name, email
FROM app.users
WHERE id IN (
    SELECT DISTINCT user_id
    FROM app.orders
    WHERE total > (
        SELECT AVG(total) FROM app.orders WHERE status = 'done'
    )
);

-- EXISTS
SELECT p.sku, p.name, p.price
FROM app.products p
WHERE EXISTS (
    SELECT 1 FROM app.order_items oi WHERE oi.product_id = p.id
);

-- Lateral join
SELECT u.name, recent.order_id, recent.created_at
FROM app.users u
CROSS JOIN LATERAL (
    SELECT id AS order_id, created_at
    FROM app.orders
    WHERE user_id = u.id
    ORDER BY created_at DESC
    LIMIT 1
) recent;

-- -------------------------------------------------------------------------- --
-- Stored procedure                                                             --
-- -------------------------------------------------------------------------- --

CREATE OR REPLACE PROCEDURE app.place_order(
    p_user_id   UUID,
    p_items     JSONB   -- [{"product_id":"...", "quantity":2}, ...]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id UUID;
    v_item     JSONB;
    v_price    NUMERIC(12, 2);
BEGIN
    INSERT INTO app.orders (user_id) VALUES (p_user_id)
    RETURNING id INTO v_order_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        SELECT price INTO v_price
        FROM app.products
        WHERE id = (v_item->>'product_id')::UUID
          FOR UPDATE;

        IF v_price IS NULL THEN
            RAISE EXCEPTION 'Product % not found', v_item->>'product_id';
        END IF;

        INSERT INTO app.order_items (order_id, product_id, quantity, unit_price)
        VALUES (
            v_order_id,
            (v_item->>'product_id')::UUID,
            (v_item->>'quantity')::INTEGER,
            v_price
        );

        UPDATE app.products
        SET stock = stock - (v_item->>'quantity')::INTEGER
        WHERE id  = (v_item->>'product_id')::UUID;
    END LOOP;

    UPDATE app.orders
    SET total = (
        SELECT SUM(quantity * unit_price) FROM app.order_items WHERE order_id = v_order_id
    )
    WHERE id = v_order_id;

    COMMIT;
END;
$$;

-- -------------------------------------------------------------------------- --
-- Function                                                                    --
-- -------------------------------------------------------------------------- --

CREATE OR REPLACE FUNCTION app.user_lifetime_value(p_user_id UUID)
RETURNS NUMERIC(14, 2)
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(SUM(total), 0)
    FROM app.orders
    WHERE user_id = p_user_id
      AND status  = 'done';
$$;

-- -------------------------------------------------------------------------- --
-- Trigger                                                                     --
-- -------------------------------------------------------------------------- --

CREATE OR REPLACE FUNCTION app.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_users_updated_at
BEFORE UPDATE ON app.users
FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();

CREATE OR REPLACE TRIGGER trg_orders_updated_at
BEFORE UPDATE ON app.orders
FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();

-- -------------------------------------------------------------------------- --
-- Transactions                                                                --
-- -------------------------------------------------------------------------- --

BEGIN;
    SAVEPOINT before_price_update;

    UPDATE app.products SET price = price * 1.05 WHERE 'sale' = ANY(tags);

    -- Rollback to savepoint if total exceeds threshold
    DO $$
    BEGIN
        IF (SELECT COUNT(*) FROM app.products WHERE price > 1000) > 10 THEN
            ROLLBACK TO SAVEPOINT before_price_update;
        END IF;
    END;
    $$;

COMMIT;

-- -------------------------------------------------------------------------- --
-- Permissions                                                                 --
-- -------------------------------------------------------------------------- --

CREATE ROLE app_reader;
CREATE ROLE app_writer;

GRANT USAGE ON SCHEMA app TO app_reader, app_writer;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_reader;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO app_writer;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO app_writer;

-- -------------------------------------------------------------------------- --
-- Cleanup (run in tests only)                                                 --
-- -------------------------------------------------------------------------- --

-- DROP TABLE IF EXISTS app.order_items CASCADE;
-- DROP TABLE IF EXISTS app.orders CASCADE;
-- DROP TABLE IF EXISTS app.products CASCADE;
-- DROP TABLE IF EXISTS app.users CASCADE;
-- DROP TYPE  IF EXISTS app.status_enum CASCADE;
-- DROP SCHEMA IF EXISTS app CASCADE;
