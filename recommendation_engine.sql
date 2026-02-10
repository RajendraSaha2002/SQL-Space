-- 1. CLEANUP
DROP TABLE IF EXISTS interactions CASCADE;
DROP TABLE IF EXISTS movies CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_user_similarity;

-- 2. SCHEMA DEFINITION

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50),
    segment VARCHAR(20) -- e.g., 'Casual', 'Cinephile'
);

CREATE TABLE movies (
    movie_id SERIAL PRIMARY KEY,
    title VARCHAR(100),
    genre VARCHAR(50)
);

CREATE TABLE interactions (
    interaction_id BIGSERIAL PRIMARY KEY,
    user_id INT REFERENCES users(user_id),
    movie_id INT REFERENCES movies(movie_id),
    rating INT CHECK (rating BETWEEN 1 AND 5),
    watched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uniq_user_movie UNIQUE (user_id, movie_id)
);

-- 3. INDEXING (Crucial for Joining massive interaction tables)
CREATE INDEX idx_interactions_user ON interactions(user_id);
CREATE INDEX idx_interactions_movie ON interactions(movie_id);

-- 4. THE ENGINE: CALCULATE SIMILARITY MATRIX (SQL-Based AI)
-- We calculate "Jaccard Similarity" between users based on shared movies.
-- Similarity = (Intersection of Movies) / (Union of Movies)
CREATE MATERIALIZED VIEW mv_user_similarity AS
SELECT 
    a.user_id as user_a,
    b.user_id as user_b,
    COUNT(a.movie_id) as shared_movies,
    (
        COUNT(a.movie_id)::decimal / 
        (
            (SELECT COUNT(*) FROM interactions WHERE user_id = a.user_id) + 
            (SELECT COUNT(*) FROM interactions WHERE user_id = b.user_id) - 
            COUNT(a.movie_id)
        )
    ) as similarity_score
FROM interactions a
JOIN interactions b ON a.movie_id = b.movie_id AND a.user_id != b.user_id
GROUP BY a.user_id, b.user_id
HAVING COUNT(a.movie_id) >= 2; -- Must share at least 2 movies to be "similar"

CREATE INDEX idx_similarity ON mv_user_similarity(user_a, similarity_score);

-- 5. RECOMMENDATION PROCEDURE
-- Input: Target User. Output: Top 5 movies watched by Similar Users (that Target User hasn't seen).
CREATE OR REPLACE FUNCTION get_recommendations(target_user_id INT)
RETURNS TABLE (
    movie_title VARCHAR,
    genre VARCHAR,
    predicted_score DECIMAL,
    reasoning VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH SimilarUsers AS (
        SELECT user_b, similarity_score
        FROM mv_user_similarity
        WHERE user_a = target_user_id
        ORDER BY similarity_score DESC
        LIMIT 10 -- Look at top 10 look-alike users
    )
    SELECT 
        m.title,
        m.genre,
        ROUND(AVG(i.rating), 2) as predicted_score,
        'Recommended because ' || COUNT(DISTINCT su.user_b) || ' similar users liked it' as reasoning
    FROM SimilarUsers su
    JOIN interactions i ON su.user_b = i.user_id
    JOIN movies m ON i.movie_id = m.movie_id
    WHERE i.movie_id NOT IN (SELECT movie_id FROM interactions WHERE user_id = target_user_id) -- Filter watched
    GROUP BY m.title, m.genre
    ORDER BY predicted_score DESC, COUNT(DISTINCT su.user_b) DESC
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;

-- 6. DATA GENERATION (Synthetic Netflix Data)
INSERT INTO users (username, segment) 
SELECT 'User_' || generate_series, 'Viewer' FROM generate_series(1, 50);

INSERT INTO movies (title, genre) VALUES 
('Inception', 'Sci-Fi'), ('The Matrix', 'Sci-Fi'), ('Interstellar', 'Sci-Fi'),
('The Godfather', 'Crime'), ('Pulp Fiction', 'Crime'), ('Goodfellas', 'Crime'),
('Toy Story', 'Animation'), ('Finding Nemo', 'Animation'), ('Shrek', 'Animation'),
('Notebook', 'Romance'), ('Titanic', 'Romance'), ('La La Land', 'Romance');

-- Generate Interactions
-- Logic: Users 1-15 love Sci-Fi, 16-30 love Crime, 31-40 love Animation
DO $$
DECLARE
    u_id INT;
    m_id INT;
BEGIN
    FOR i IN 1..400 LOOP
        u_id := floor(random() * 40 + 1);
        
        -- Bias selection based on user ID logic
        IF u_id <= 15 THEN m_id := floor(random() * 3 + 1); -- SciFi IDs 1-3
        ELSIF u_id <= 30 THEN m_id := floor(random() * 3 + 4); -- Crime IDs 4-6
        ELSE m_id := floor(random() * 6 + 1); -- Random mix
        END IF;

        -- Insert interaction (ignore duplicates)
        BEGIN
            INSERT INTO interactions (user_id, movie_id, rating) 
            VALUES (u_id, m_id, floor(random() * 2 + 4)); -- Mostly 4 or 5 stars
        EXCEPTION WHEN unique_violation THEN 
            -- Skip duplicate
        END;
    END LOOP;
END $$;

-- Refresh the similarity matrix
REFRESH MATERIALIZED VIEW mv_user_similarity;