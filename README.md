# Autonomous Mobile Robot (AMR) Telemetry Analytics

An advanced SQL-based analytics framework designed to monitor and evaluate the health, performance, and battery efficiency of Autonomous Mobile Robots (AMRs) in real-time. 

This project demonstrates how to structure time-series sensor data, enforce domain-specific data constraints, and write complex analytical queries utilizing **Window Functions**, **Common Table Expressions (CTEs)**, and **Conditional Logic** in MySQL.

---

## Features and Capabilities

* **Data Integrity Enforcement:** Implements strict validation checks preventing impossible data entries (e.g., faulty battery readings outside 0-100% or extreme motor temperatures).
* **Moving Window Calculations:** Computes a 3-interval rolling average of motor temperatures to smooth out brief sensor spikes and detect long-term overheating trends.
* **Automated Alerting Tiers:** Classifies hardware health into dynamic warning tiers (`NORMAL`, `WARNING`, `CRITICAL OVERHEAT`) using state-evaluating conditional branches.
* **Normalized Performance Metrics:** Uses `LAG()` windowing to calculate precise battery discharge amounts and normalize power depletion down to a `% dropped per minute` metric, filtering out stale or irregular data gaps.

---

## Schema Architecture

The telemetry pipeline centers around a highly indexed time-series table layout:

* **Primary Key:** `telemetry_id` (Auto-incremented)
* **Unique Composite Constraint:** `(robot_id, status_timestamp)` ensures data is not double-counted or duplicated down to the second.
* **Indexation:** Multi-column composite index `idx_robot_time` optimizes high-frequency `PARTITION BY` and `ORDER BY DESC` analytical read operations.

---

## Getting Started

### Prerequisites
* MySQL 8.0+ or MariaDB 10.2+ (Required for Window Functions and CTE support).

### Setup and Execution
1. Create your database environment:
   ```sql
   CREATE DATABASE activity;
   USE activity;
