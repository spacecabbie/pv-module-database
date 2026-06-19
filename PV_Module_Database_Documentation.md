# PV Module Database Documentation

**Version:** 0.1  
**Date:** 2026-06-19  
**Status:** Draft / Ready for Implementation  
**Owner:** Hans Haufe (Ribeiro das Cabras)

---

## 1. Overview

This document describes the design, structure, and usage of a custom **Photovoltaic (PV) Module Database** built to support MPPT charge controller sizing tools and general solar system planning.

The database is designed with the following goals:

- Support different levels of data completeness (Minimal → Optimal → Complete)
- Enable accurate and safe MPPT string sizing calculations
- Maintain full traceability and audit history
- Handle duplicates intelligently without data loss
- Remain future-proof and easy to extend
- Follow professional database design practices

---

## 2. Design Principles

| Principle                    | Implementation                                                                 | Reason |
|-----------------------------|----------------------------------------------------------------------------------|--------|
| **Data Quality Tiers**      | `data_level` column (`minimal`, `optimal`, `complete`)                          | Users/tools can filter based on required accuracy |
| **Auditability**            | Separate `module_audit_log` table + `created_by` / `updated_by` fields          | Full history of changes and who made them |
| **Duplicate Management**    | `status` + `merged_into_id` (soft linking, no hard deletes)                     | Preserve all data while clearly marking duplicates |
| **Future-proofing**         | `extra_data` JSON column + clear separation of core vs extended fields          | Easy to add new specifications without schema changes |
| **Simplicity & Compatibility** | SQLite with standard types + JSON support                                     | Excellent PHP compatibility and portability |
| **Provenance**              | `source` + `source_detail` fields                                               | Know exactly where every record came from |

---

## 3. Database Structure

The database consists of **two tables**:

1. **`modules`** — Main table containing all panel specifications
2. **`module_audit_log`** — Audit trail for all changes

### 3.1 Main Table: `modules`

This is the primary table. Every solar panel entry lives here.

#### Field Reference

| Field Name                    | Type      | Required | Level          | Description                                                                 | Example                          | Notes / Constraints |
|-------------------------------|-----------|----------|----------------|-----------------------------------------------------------------------------|----------------------------------|---------------------|
| `id`                          | INTEGER   | Yes      | All            | Unique identifier                                                           | 12345                            | Primary Key (AUTOINCREMENT) |
| `manufacturer`                | TEXT      | Yes      | All            | Name of the manufacturer                                                    | "Trina Solar", "JA Solar"        | - |
| `model`                       | TEXT      | Yes      | All            | Model name / designation                                                    | "TSM-400DE09.08"                 | Combined with manufacturer should be unique |
| `data_level`                  | TEXT      | Yes      | All            | Completeness tier of the data                                               | "minimal", "optimal", "complete" | CHECK constraint |
| `p_max`                       | REAL      | No*      | Minimal+       | Maximum power output at STC (Watts)                                         | 400.0                            | *Required for useful calculations |
| `voc`                         | REAL      | No*      | Minimal+       | Open Circuit Voltage at STC (Volts)                                         | 41.2                             | Critical for string voltage |
| `isc`                         | REAL      | No*      | Minimal+       | Short Circuit Current at STC (Amps)                                         | 12.8                             | Critical for current limits |
| `vmp`                         | REAL      | No       | Optimal+       | Voltage at Maximum Power (Volts)                                            | 33.8                             | - |
| `imp`                         | REAL      | No       | Optimal+       | Current at Maximum Power (Amps)                                             | 11.8                             | - |
| `temp_coeff_voc`              | REAL      | No       | Optimal+       | Temperature coefficient of Voc (%/°C)                                       | -0.29                            | Negative value |
| `temp_coeff_isc`              | REAL      | No       | Optimal+       | Temperature coefficient of Isc (%/°C)                                       | 0.05                             | Positive value |
| `technology`                  | TEXT      | No       | Optimal+       | Cell technology                                                             | "mono-Si", "poly-Si", "HJT"      | Standardized values recommended |
| `cells_in_series`             | INTEGER   | No       | Optimal+       | Number of cells connected in series                                         | 60, 72, 108, 144                 | Very useful for duplicate detection |
| `efficiency`                  | REAL      | No       | Complete       | Module efficiency (%)                                                       | 20.5                             | - |
| `bifacial`                    | INTEGER   | No       | Complete       | Is the module bifacial?                                                     | 0 or 1                           | 1 = bifacial |
| `bifaciality`                 | REAL      | No       | Complete       | Bifaciality factor                                                          | 0.70                             | Only relevant if bifacial = 1 |
| `temp_coeff_voc_abs`          | REAL      | No       | Complete       | Absolute temperature coefficient of Voc (V/°C)                              | -0.121                           | From professional databases (SAM/pvlib) |
| `temp_coeff_isc_abs`          | REAL      | No       | Complete       | Absolute temperature coefficient of Isc (A/°C)                              | 0.0045                           | - |
| `t_noct`                      | REAL      | No       | Complete       | Nominal Operating Cell Temperature (°C)                                     | 45.5                             | Real-world reference temperature |
| `ptc_power`                   | REAL      | No       | Complete       | Power under PTC conditions (Watts)                                          | 365.2                            | Optional North American rating |
| `length_mm`                   | REAL      | No       | Complete       | Module length in millimeters                                                | 1755                             | - |
| `width_mm`                    | REAL      | No       | Complete       | Module width in millimeters                                                 | 1038                             | - |
| `height_mm`                   | REAL      | No       | Complete       | Module height/thickness in millimeters                                      | 35                               | - |
| `weight_kg`                   | REAL      | No       | Complete       | Module weight in kilograms                                                  | 19.5                             | - |
| `connector_type`              | TEXT      | No       | Complete       | Connector type                                                              | "MC4", "MC4-EVO2"                | - |
| `datasheet_url`               | TEXT      | No       | Complete       | Link to official datasheet                                                  | https://...                      | - |
| `warranty_product_years`      | INTEGER   | No       | Complete       | Product warranty in years                                                   | 12                               | - |
| `warranty_performance_years`  | INTEGER   | No       | Complete       | Performance warranty in years                                               | 25                               | - |
| `introduced_year`             | INTEGER   | No       | Complete       | Year the model was first introduced                                         | 2022                             | - |
| `discontinued_year`           | INTEGER   | No       | Complete       | Year production ended (NULL = still active)                                 | 2024 or NULL                     | - |
| `production_status`           | TEXT      | No       | Complete       | Current production status                                                   | active, discontinued, limited    | CHECK constraint |
| `source`                      | TEXT      | No       | All            | High-level source of the data                                               | cec, manual, import, user        | - |
| `source_detail`               | TEXT      | No       | All            | Detailed source information                                                 | "CEC import 2026-06", "datasheet.pdf" | - |
| `created_by`                  | TEXT      | No       | All            | Who or what created the record                                              | admin, import_script, user:42    | - |
| `created_at`                  | TEXT      | Yes      | All            | Timestamp when record was created                                           | 2026-06-19T11:45:00Z             | ISO 8601 format |
| `updated_by`                  | TEXT      | No       | All            | Who last modified the record                                                | admin                            | - |
| `updated_at`                  | TEXT      | No       | All            | Timestamp of last modification                                              | 2026-06-19T14:22:00Z             | - |
| `modification_reason`         | TEXT      | No       | All            | Reason for the last modification                                            | "Updated temperature coefficient from new datasheet" | - |
| `status`                      | TEXT      | Yes      | All            | Current lifecycle status of the record                                      | active, duplicate, merged, archived | CHECK constraint + default 'active' |
| `merged_into_id`              | INTEGER   | No       | All            | If this is a duplicate, points to the master record                         | 1247                             | Self-referencing FK |
| `notes`                       | TEXT      | No       | All            | Free-text notes or comments                                                 | "This model has been rebranded"  | - |
| `extra_data`                  | TEXT      | No       | All            | JSON object for future or uncommon fields                                   | `{"frame_color": "black"}`       | JSON format |

### 3.2 Audit Log Table: `module_audit_log`

This table records every significant change to the `modules` table.

| Field          | Type     | Description                                      | Example |
|----------------|----------|--------------------------------------------------|--------|
| `id`           | INTEGER  | Primary key                                      | 987    |
| `module_id`    | INTEGER  | Reference to the affected module                 | 1247   |
| `action`       | TEXT     | Type of action performed                         | create, update, mark_duplicate, merge |
| `changed_by`   | TEXT     | Who performed the action                         | admin, duplicate_detection_script |
| `changed_at`   | TEXT     | When the change occurred                         | 2026-06-19T14:22:00Z |
| `reason`       | TEXT     | Explanation for the change                       | "Marked as duplicate of record #1247 (99.2% similarity)" |
| `old_data`     | TEXT     | JSON snapshot of the record before the change    | `{...}` |
| `new_data`     | TEXT     | JSON snapshot of the record after the change     | `{...}` |

---

## 4. Data Quality Levels

### 4.1 Minimal
**Purpose:** Quick estimates and basic MPPT calculations when limited data is available.

**Minimum expected fields:** `p_max`, `voc`, `isc`

**Warning:** Temperature coefficient may be estimated. Results should be treated as approximate.

### 4.2 Optimal (Recommended)
**Purpose:** Reliable MPPT string sizing and system design.

**Key additional fields:** `vmp`, `imp`, real `temp_coeff_voc`, `technology`, `cells_in_series`

This level is the **recommended minimum** for production use in the MPPT calculator.

### 4.3 Complete
**Purpose:** Full technical reference, advanced modeling, and long-term database value.

Includes all physical dimensions, absolute temperature coefficients, production lifecycle data, NOCT, bifacial information, and documentation links.

---

## 5. Duplicate & Version Control Strategy

- Records are **never hard deleted**.
- When a near-duplicate is detected (via script):
  - The new record is marked with `status = 'duplicate'`
  - `merged_into_id` points to the master (active) record
- The audit log records the decision and similarity score.
- This approach preserves all historical data while keeping the active dataset clean.

---

## 6. Future-Proofing

- New specifications should first be added to the `extra_data` JSON column.
- Only promote fields to dedicated columns once they become commonly used across many records.
- The `data_level` system allows gradual improvement of data quality over time.

---

## 7. Usage Guidelines

- Always populate `data_level` correctly.
- Prefer `optimal` or `complete` data when available for MPPT calculations.
- Use the audit log to understand the history of any record.
- When importing data, always record the `source` and `created_by`.

---

## 8. Technical Notes

- **Database Engine:** SQLite 3
- **JSON Support:** Uses SQLite JSON1 extension (available since 2015)
- **Date Format:** ISO 8601 (UTC) recommended for all timestamps
- **Unique Constraint:** `(manufacturer, model)` prevents exact duplicates on insert

---

*This documentation should be updated whenever the schema changes.*