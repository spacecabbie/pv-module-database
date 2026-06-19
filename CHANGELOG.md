# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-06-19

### Added
- Initial release of the PV Module Database (Version 0.1)
- Main `modules` table with comprehensive fields
- Separate `module_audit_log` table for full change history
- Three data quality levels: Minimal, Optimal, Complete
- Duplicate management system using `status` + `merged_into_id` (link instead of delete)
- Production lifecycle tracking (`introduced_year`, `discontinued_year`, `production_status`)
- Absolute temperature coefficients (`temp_coeff_voc_abs`, `temp_coeff_isc_abs`)
- `cells_in_series` and `t_noct` fields (inspired by NREL/SAM databases)
- `extra_data` JSON column for future extensibility
- Full professional documentation in Markdown
- SQLite schema file (`schema_v0.1.sql`)

### Changed
- N/A (initial release)

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A