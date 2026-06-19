# PV Module Database Documentation

**Version:** 0.1  
**Date:** 2026-06-19  
**Status:** Draft / Ready for Implementation  
**Owner:** Hans Haufe

## Credits

- **Overall database design:** HHaufe
- **Detailed technical schema structure:** AI Grok and Claude

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

The database consists of **four tables**:

1. `manufacturers` — Lookup table for manufacturers
2. `modules` — Main table containing core panel specifications
3. `module_physical` — Physical dimensions and characteristics
4. `module_audit_log` — Audit trail for all changes

### 3.1 Table: `manufacturers`

| Field Name     | Type      | Description                          | Example                  |
|----------------|-----------|--------------------------------------|--------------------------|
| `id`           | INTEGER   | Primary key                          | 1                        |
| `name`         | TEXT      | Manufacturer name (unique)           | "Trina Solar"          |
| `country`      | TEXT      | Country of origin                    | "China"                |
| `website`      | TEXT      | Official website                     | https://www.trinasolar.com |
| `notes`        | TEXT      | Additional notes                     | -                        |
| `created_at`   | TEXT      | Record creation timestamp            | 2026-06-19T10:00:00Z     |

### 3.2 Table: `modules`

This is the core table.

#### Key Fields

| Field Name                    | Type      | Level          | Description                                                                 | Notes |
|-------------------------------|-----------|----------|-----------------------------------------------------------------------------|-------|
| `manufacturer_id`             | INTEGER   | All            | Reference to manufacturers table                                            | Required |
| `model`                       | TEXT      | All            | Model name                                                                  | Required |
| `series`                      | TEXT      | All            | Product series / family (e.g. "Maxeon 6", "Tiger Neo")                   | - |
| `data_level`                  | TEXT      | All            | Data completeness tier                                                      | minimal / optimal / complete |
| `p_max`, `voc`, `isc`         | REAL      | Minimal+       | Basic electrical specs                                                      | - |
| `vmp`, `imp`                  | REAL      | Optimal+       | Maximum power point specs                                                   | - |
| `temp_coeff_voc_pct`          | REAL      | Optimal+       | Temperature coefficient of Voc (%/°C)                                   | - |
| `temp_coeff_isc_pct`          | REAL      | Optimal+       | Temperature coefficient of Isc (%/°C)                                   | - |
| `temp_coeff_pmax`             | REAL      | Optimal+       | Temperature coefficient of Pmax (%/°C)                                  | Important for MPPT |
| `technology`                  | TEXT      | Optimal+       | Cell technology                                                             | Constrained values |
| `cells_in_series`             | INTEGER   | Optimal+       | Number of cells in series                                                   | Useful for calculations |
| `efficiency`, `t_noct`        | REAL      | Complete       | Efficiency and NOCT                                                         | - |
| `introduced_year`             | INTEGER   | Complete       | Year model was introduced                                                   | - |
| `discontinued_year`           | INTEGER   | Complete       | Year production ended                                                       | NULL = still active |
| `production_status`           | TEXT      | Complete       | Current production status                                                   | active / discontinued / limited |
| `status`                      | TEXT      | All            | Record status (for duplicate management)                                    | active / duplicate / merged |
| `merged_into_id`              | INTEGER   | All            | Points to master record if duplicate                                        | Self-referencing FK |
| `extra_data`                  | TEXT      | All            | JSON for future fields                                                      | With validation |

### 3.3 Table: `module_physical`

Physical characteristics are stored in a dedicated table for better querying and future flexibility.

| Field Name     | Type      | Description                          | Example   |
|----------------|-----------|--------------------------------------|-----------|
| `module_id`    | INTEGER   | Reference to modules table           | 1247      |
| `length_mm`    | REAL      | Length in millimeters                | 1755      |
| `width_mm`     | REAL      | Width in millimeters                 | 1038      |
| `height_mm`    | REAL      | Height/thickness in millimeters      | 35        |
| `weight_kg`    | REAL      | Weight in kilograms                  | 19.5      |
| `bifacial`     | INTEGER   | Is bifacial? (0/1)                   | 1         |
| `bifaciality`  | REAL      | Bifaciality factor                   | 0.70      |
| `connector_type` | TEXT    | Connector type                       | "MC4"   |

### 3.4 Table: `module_audit_log`

Full change history with JSON snapshots.

---

## 4. Data Quality Levels

- **Minimal**: Basic electrical data for rough estimates
- **Optimal**: Recommended level for MPPT sizing
- **Complete**: Full technical reference including physical specs and lifecycle data

---

## 5. Improvements from Claude

Several improvements in this version were inspired by suggestions from Claude:

- Separate `manufacturers` table
- Dedicated `module_physical` table
- Addition of `temp_coeff_pmax`
- Clearer temperature coefficient naming
- JSON validation on extensible fields

---

*This documentation should be updated with every schema change.*