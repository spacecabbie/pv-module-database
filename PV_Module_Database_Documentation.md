# PV Module Database Documentation

**Version:** 0.1  
**Date:** 2026-06-19  
**Status:** Draft / Ready for Implementation  
**Owner:** Hans Haufe

## Credits

- **Overall database design:** HHaufe
- **Detailed technical schema structure:** AI Grok and Claude
- **Technology aliases concept:** Suggested by HHaufe

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

**Note:** This schema was intentionally designed to be solid from the beginning, with the goal of minimizing the need for major changes in future versions.

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
2. `technologies` + `technology_aliases` — Technology classification with support for common names/aliases
3. `modules` — Main table containing core panel specifications (including physical dimensions)
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

### 3.2 Tables: `technologies` and `technology_aliases`

**Design decision by HHaufe:** The `technology` field uses a canonical technical name, while common or marketing names are supported through aliases.

#### `technologies` table

| Field Name     | Type      | Description                              |
|----------------|-----------|------------------------------------------|
| `id`           | INTEGER   | Primary key                              |
| `name`         | TEXT      | Canonical technical name (e.g. 'TOPCon') |
| `category`     | TEXT      | Broad category (e.g. 'mono-Si')          |
| `description`  | TEXT      | Optional description                     |

#### `technology_aliases` table

| Field Name      | Type      | Description                                      |
|-----------------|-----------|--------------------------------------------------|
| `technology_id` | INTEGER   | Reference to technologies table                  |
| `alias`         | TEXT      | Common or marketing name (e.g. 'N-type TOPCon')  |
| `is_primary`    | BOOLEAN   | Whether this is the preferred display name       |

### 3.3 Table: `modules`

**Note on physical dimensions:** Per decision by HHaufe, physical dimensions (`length_mm`, `width_mm`, `height_mm`, `weight_kg`) are stored directly in the `modules` table rather than in a separate table. This simplifies querying and filtering.

#### Key Fields

| Field Name                    | Type      | Level          | Description                                                                 | Notes |
|-------------------------------|-----------|----------|-----------------------------------------------------------------------------|-------|
| `manufacturer_id`             | INTEGER   | All            | Reference to manufacturers table                                            | Required |
| `model`                       | TEXT      | All            | Model name                                                                  | Required |
| `series`                      | TEXT      | All            | Product series / family                                                     | - |
| `data_level`                  | TEXT      | All            | Data completeness tier                                                      | minimal / optimal / complete |
| `p_max`, `voc`, `isc`         | REAL      | Minimal+       | Basic electrical specs                                                      | - |
| `vmp`, `imp`                  | REAL      | Optimal+       | Maximum power point specs                                                   | - |
| `temp_coeff_voc_pct`          | REAL      | Optimal+       | Temperature coefficient of Voc (%/°C)                                   | - |
| `temp_coeff_isc_pct`          | REAL      | Optimal+       | Temperature coefficient of Isc (%/°C)                                   | - |
| `temp_coeff_pmax`             | REAL      | Optimal+       | Temperature coefficient of Pmax (%/°C)                                  | Important for MPPT calculations |
| `technology_id`               | INTEGER   | Optimal+       | Reference to technologies table                                             | - |
| `cells_in_series`             | INTEGER   | Optimal+       | Number of cells in series                                                   | Useful for calculations and duplicate detection |
| `efficiency`, `t_noct`        | REAL      | Complete       | Efficiency and NOCT                                                         | - |
| `length_mm`, `width_mm`, `height_mm`, `weight_kg` | REAL | Complete | Physical dimensions and weight                                              | Stored in modules table per design decision |
| `connector_type`              | TEXT      | Complete       | Connector type                                                              | - |
| `datasheet_url`               | TEXT      | Complete       | Link to official datasheet                                                  | - |
| `warranty_product_years`      | INTEGER   | Complete       | Product warranty in years                                                   | - |
| `warranty_performance_years`  | INTEGER   | Complete       | Performance warranty in years                                               | - |
| `introduced_year`             | INTEGER   | Complete       | Year the model was first introduced                                         | - |
| `discontinued_year`           | INTEGER   | Complete       | Year production ended (NULL = still active)                                 | - |
| `production_status`           | TEXT      | Complete       | Current production status                                                   | active / discontinued / limited / unknown |
| `status`                      | TEXT      | All            | Record status for duplicate management                                      | active / duplicate / merged / archived |
| `merged_into_id`              | INTEGER   | All            | Points to master record if this is a duplicate                              | Self-referencing FK |
| `extra_data`                  | TEXT      | All            | JSON for future or uncommon fields                                          | With validation |

### 3.4 Table: `module_audit_log`

Full change history. Includes `table_name` to support auditing multiple tables in the future.

| Field Name     | Type      | Description                                      |
|----------------|-----------|--------------------------------------------------|
| `module_id`    | INTEGER   | Reference to the affected module                 |
| `table_name`   | TEXT      | Which table the change occurred in               |
| `action`       | TEXT      | Type of action (`insert`, `update`, `merge`, `archive`) |
| `changed_by`   | TEXT      | Who performed the change                         |
| `changed_at`   | TEXT      | Timestamp of change                              |
| `reason`       | TEXT      | Explanation for the change                       |
| `old_data`     | TEXT      | JSON snapshot before change                      |
| `new_data`     | TEXT      | JSON snapshot after change                       |

---

## 4. Data Quality Levels

- **Minimal**: Basic electrical data (`p_max`, `voc`, `isc`) for rough estimates
- **Optimal**: Recommended level for reliable MPPT sizing
- **Complete**: Full technical reference, including physical specs and production lifecycle

---

## 5. Key Design Decisions

- **Physical dimensions**: Stored directly in the `modules` table (decision by HHaufe) to simplify filtering and querying.
- **Technology handling**: Uses a canonical name in `technologies` + support for common aliases via `technology_aliases` (suggested by HHaufe).
- **Module certificates**: Deferred to a future version.
- **Audit strategy**: One central audit log with `table_name` for future scalability.

---

*This documentation should be updated with every schema change.*