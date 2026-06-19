# Changelog

## [0.1.0] - 2026-06-19

### Added
- `manufacturers` table for normalized manufacturer data
- `technologies` + `technology_aliases` tables (canonical technical name + common aliases) — concept suggested by HHaufe
- `temp_coeff_pmax` field
- Absolute temperature coefficients (`temp_coeff_voc_abs`, `temp_coeff_isc_abs`)
- `series` field
- `cells_in_series` and `t_noct`
- `datasheet_url`, `warranty_product_years`, and `warranty_performance_years`
- Production lifecycle fields (`introduced_year`, `discontinued_year`, `production_status`)
- `table_name` column in audit log for future scalability
- `action` CHECK constraint on audit log
- JSON validation on `extra_data`, `old_data`, and `new_data`
- `PRAGMA foreign_keys = ON` and `PRAGMA journal_mode = WAL` recommendations

### Changed
- Physical dimensions (`length_mm`, `width_mm`, `height_mm`, `weight_kg`) kept in the `modules` table (decision by HHaufe)
- Temperature coefficient fields renamed for clarity (`_pct` / `_abs`)
- `technology` handling improved with alias support

### Notes
- `module_certificates` table deferred to a future version.
- Schema intentionally designed to be solid from the start.