-- =============================================================================
-- Anti-Spot Consumer Insights — Core SQL Pipeline
-- =============================================================================
-- This file documents the SQL pipeline used in the anti-spot decision signal
-- analysis. Run in order against a PostgreSQL database.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Raw table creation
-- -----------------------------------------------------------------------------
-- All columns initially typed as TEXT to handle messy raw data.
-- Type casting happens at the query layer, not at ingest time.

CREATE TABLE product_info (
    product_id TEXT, product_name TEXT, brand_id TEXT, brand_name TEXT,
    loves_count TEXT, rating TEXT, reviews TEXT, size TEXT,
    variation_type TEXT, variation_value TEXT, variation_desc TEXT,
    ingredients TEXT, price_usd TEXT, value_price_usd TEXT, sale_price_usd TEXT,
    limited_edition TEXT, new TEXT, online_only TEXT, out_of_stock TEXT,
    sephora_exclusive TEXT, highlights TEXT, primary_category TEXT,
    secondary_category TEXT, tertiary_category TEXT, child_count TEXT,
    child_max_price TEXT, child_min_price TEXT
);

CREATE TABLE reviews (
    author_id TEXT, rating TEXT, is_recommended TEXT, helpfulness TEXT,
    total_feedback_count TEXT, total_neg_feedback_count TEXT,
    total_pos_feedback_count TEXT, submission_time TEXT,
    review_text TEXT, review_title TEXT,
    skin_tone TEXT, eye_color TEXT, skin_type TEXT, hair_color TEXT,
    product_id TEXT, product_name TEXT, brand_name TEXT, price_usd TEXT
);

-- Load CSVs using \copy in psql (client-side, bypasses server file permissions):
-- \copy product_info FROM 'data/raw/product_info.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- \copy reviews FROM 'data/clean/reviews_0-250.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
-- (repeat for each cleaned review file)


-- -----------------------------------------------------------------------------
-- 2. Join quality diagnostic
-- -----------------------------------------------------------------------------
-- Verify that every review can be matched to a product. LEFT JOIN exposes
-- unmatched rows that an INNER JOIN would silently drop.

SELECT
    COUNT(*)                                                AS total_reviews,
    COUNT(p.primary_category)                               AS matched,
    COUNT(*) - COUNT(p.primary_category)                    AS unmatched,
    ROUND(COUNT(p.primary_category) * 100.0 / COUNT(*), 1)  AS match_pct
FROM reviews r
LEFT JOIN product_info p ON r.product_id = p.product_id;


-- -----------------------------------------------------------------------------
-- 3. Anti-spot subset filter (two-layer logic)
-- -----------------------------------------------------------------------------
-- A product qualifies if category matches OR ingredients contain anti-spot
-- actives. OR logic captures products miscategorized as generic 'Treatments'.

CREATE TABLE antispot_products AS
SELECT *
FROM product_info
WHERE
    tertiary_category IN (
        'Face Serums', 'Anti-Aging', 'Facial Peels',
        'Blemish & Acne Treatments', 'Exfoliators', 'Toners',
        'Eye Creams & Treatments', 'Face Masks', 'Face Sunscreen',
        'Face Oils', 'For Face', 'Face Sets', 'Tinted Moisturizer',
        'Moisturizer & Treatments', 'Eye Masks', 'BB & CC Cream'
    )
    OR ingredients ILIKE '%niacinamide%'
    OR ingredients ILIKE '%vitamin c%'
    OR ingredients ILIKE '%tranexamic%'
    OR ingredients ILIKE '%arbutin%'
    OR ingredients ILIKE '%kojic%'
    OR ingredients ILIKE '%azelaic%'
    OR ingredients ILIKE '%hydroquinone%'
    OR ingredients ILIKE '%retinol%'
    OR ingredients ILIKE '%ferulic acid%'
    OR ingredients ILIKE '%glycolic acid%'
    OR ingredients ILIKE '%lactic acid%';

-- Join filtered products with their reviews
CREATE TABLE antispot_reviews AS
SELECT
    r.*,
    p.ingredients,
    p.secondary_category,
    p.tertiary_category
FROM reviews r
JOIN antispot_products p ON r.product_id = p.product_id;


-- -----------------------------------------------------------------------------
-- 4. Aggregation query 1 — Overall signal mention rates
-- -----------------------------------------------------------------------------
-- AVG of a binary (0/1) column = the proportion that flagged as 1.

SELECT
    ROUND(AVG(ingredient)::numeric, 4) AS ingredient_rate,
    ROUND(AVG(price)::numeric, 4)      AS price_rate,
    ROUND(AVG(result)::numeric, 4)     AS result_rate,
    ROUND(AVG(authority)::numeric, 4)  AS authority_rate,
    ROUND(AVG(brand)::numeric, 4)      AS brand_rate,
    COUNT(*)                           AS total_reviews
FROM antispot_reviews_signals;


-- -----------------------------------------------------------------------------
-- 5. Aggregation query 2 — Signal rate by skin type (cross-tab)
-- -----------------------------------------------------------------------------

SELECT
    skin_type,
    ROUND(AVG(ingredient)::numeric, 4) AS ingredient_rate,
    ROUND(AVG(price)::numeric, 4)      AS price_rate,
    ROUND(AVG(result)::numeric, 4)     AS result_rate,
    ROUND(AVG(authority)::numeric, 4)  AS authority_rate,
    ROUND(AVG(brand)::numeric, 4)      AS brand_rate,
    COUNT(*)                           AS sample_size
FROM antispot_reviews_signals
WHERE skin_type IS NOT NULL
GROUP BY skin_type
ORDER BY sample_size DESC;


-- -----------------------------------------------------------------------------
-- 6. Aggregation query 3 — Ingredient × satisfaction with RANK() window function
-- -----------------------------------------------------------------------------
-- CTE tags each review with its mentioned ingredient (if any), then RANK() OVER
-- adds a ranking column without collapsing the aggregated rows.

WITH ingredient_mentions AS (
    SELECT
        CASE
            WHEN review_text ILIKE '%niacinamide%' THEN 'niacinamide'
            WHEN review_text ILIKE '%vitamin c%'   THEN 'vitamin_c'
            WHEN review_text ILIKE '%retinol%'     THEN 'retinol'
            WHEN review_text ILIKE '%glycolic%'    THEN 'glycolic_acid'
            WHEN review_text ILIKE '%tranexamic%'  THEN 'tranexamic_acid'
            ELSE NULL
        END AS mentioned_ingredient,
        rating::numeric,
        is_recommended::numeric
    FROM antispot_reviews_signals
)
SELECT
    mentioned_ingredient,
    ROUND(AVG(rating), 2)                       AS avg_rating,
    ROUND(AVG(is_recommended), 2)               AS recommend_rate,
    COUNT(*)                                    AS mention_count,
    RANK() OVER (ORDER BY AVG(rating) DESC)     AS satisfaction_rank
FROM ingredient_mentions
WHERE mentioned_ingredient IS NOT NULL
GROUP BY mentioned_ingredient
ORDER BY satisfaction_rank;


-- -----------------------------------------------------------------------------
-- 7. Aggregation query 4 — Primary driver classification
-- -----------------------------------------------------------------------------
-- A single review can trigger multiple signals. CASE WHEN assigns one primary
-- driver per review using an explicit hierarchy. Order matters — first match wins.

SELECT
    CASE
        WHEN ingredient = 1 AND brand = 0 AND authority = 0 THEN 'ingredient_driven'
        WHEN brand = 1 AND ingredient = 0 AND authority = 0 THEN 'brand_driven'
        WHEN authority = 1                                   THEN 'authority_influenced'
        WHEN price = 1 AND ingredient = 0                    THEN 'price_motivated'
        WHEN result = 1 AND ingredient = 0                   THEN 'result_focused'
        ELSE 'mixed_or_none'
    END                                            AS primary_driver,
    ROUND(AVG(rating::numeric), 2)                 AS avg_rating,
    ROUND(AVG(is_recommended::numeric), 2)         AS recommend_rate,
    COUNT(*)                                       AS review_count
FROM antispot_reviews_signals
GROUP BY primary_driver
ORDER BY recommend_rate DESC;
