-- ==========================================
-- PROJECT: AMR Telemetry & Predictive Maintenance
-- ==========================================

-- ------------------------------------------
-- STEP 1: ENVIRONMENT SETUP & SCHEMA DEFINITION
-- ------------------------------------------
CREATE DATABASE IF NOT EXISTS activity;
USE activity;

DROP TABLE IF EXISTS amr_telemetry;

CREATE TABLE amr_telemetry (
    telemetry_id INT AUTO_INCREMENT PRIMARY KEY,
    robot_id INT NOT NULL,
    status_timestamp DATETIME NOT NULL,
    battery_percentage DECIMAL(4,1),
    motor_temperature DECIMAL(5,2),
    error_code VARCHAR(15) DEFAULT '0',
    
    -- Prevents duplicate entries for the exact same second
    CONSTRAINT unique_robot_time UNIQUE (robot_id, status_timestamp),
    
    -- Constraints for valid data ranges 
    CONSTRAINT check_battery CHECK (battery_percentage BETWEEN 0.0 AND 100.0),
    CONSTRAINT check_temp CHECK (motor_temperature BETWEEN -20.0 AND 150.0)
);

-- Optimize high-frequency analytical windowing and partition queries
CREATE INDEX idx_robot_time ON amr_telemetry (robot_id, status_timestamp DESC);


-- ------------------------------------------
-- STEP 2: MOCK TELEMETRY SEED DATA
-- ------------------------------------------
INSERT INTO amr_telemetry (robot_id, status_timestamp, battery_percentage, motor_temperature, error_code)
VALUES 
(101, NOW() - INTERVAL 4 MINUTE, 85.5, 42.1, '0'),
(101, NOW() - INTERVAL 3 MINUTE, 84.2, 55.0, '0'),
(101, NOW() - INTERVAL 2 MINUTE, 83.0, 78.4, '0'),
(101, NOW() - INTERVAL 1 MINUTE, 81.5, 84.6, 'ERR_MOTOR_STALL'),
(102, NOW() - INTERVAL 2 MINUTE, 99.0, 35.2, '0'),
(102, NOW() - INTERVAL 1 MINUTE, 98.1, 36.4, '0');


-- ------------------------------------------
-- STEP 3: ANALYTICS PAYLOAD 1 — ROLLING AVERAGE & THERMAL ALERTS
-- ------------------------------------------
SELECT 
    robot_id,
    status_timestamp,
    motor_temperature,
    AVG(motor_temperature) OVER (
        PARTITION BY robot_id 
        ORDER BY status_timestamp 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_avg_temp,
    CASE 
        WHEN motor_temperature > 80.0 THEN 'CRITICAL OVERHEAT'
        WHEN motor_temperature > 65.0 THEN 'WARNING'
        ELSE 'NORMAL'
    END AS alert_level 
FROM amr_telemetry
ORDER BY robot_id, status_timestamp DESC;


-- ------------------------------------------
-- STEP 4: ANALYTICS PAYLOAD 2 — NORMALIZED BATTERY DISCHARGE TRACKING
-- ------------------------------------------
WITH battery_tracking AS (
    SELECT 
        robot_id,
        status_timestamp,
        battery_percentage,
        LAG(battery_percentage) OVER (
            PARTITION BY robot_id 
            ORDER BY status_timestamp
        ) AS previous_battery,
        LAG(status_timestamp) OVER (
            PARTITION BY robot_id 
            ORDER BY status_timestamp
        ) AS previous_timestamp
    FROM amr_telemetry
),
metrics_calculated AS (
    SELECT 
        robot_id,
        status_timestamp,
        battery_percentage,
        (previous_battery - battery_percentage) AS battery_drop_amount,
        TIMESTAMPDIFF(MINUTE, previous_timestamp, status_timestamp) AS minutes_elapsed
    FROM battery_tracking
    WHERE previous_battery IS NOT NULL 
      AND previous_timestamp IS NOT NULL
)
SELECT 
    robot_id,
    status_timestamp,
    battery_percentage,
    battery_drop_amount,
    minutes_elapsed,
    ROUND(battery_drop_amount / NULLIF(minutes_elapsed, 0), 2) AS drop_rate_per_minute
FROM metrics_calculated
WHERE battery_drop_amount > 0 AND minutes_elapsed <= 5
ORDER BY drop_rate_per_minute DESC;