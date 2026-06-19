# Changelog

## [0.1.0] - 2026-06-19

### Added
- Initial schema v0.1
- `manufacturers` table (suggested by Claude)
- `module_physical` table for dimensions and physical specs
- `temp_coeff_pmax` field
- `series` field
- `cells_in_series` and `t_noct`
- Proper self-referential FK on `merged_into_id`
- JSON validation on `extra_data` and audit log
- Full documentation

### Changed
- Temperature coefficient fields renamed for clarity (`_pct` / `_abs`)
- `technology` field now has CHECK constraint

### Notes
- Improvements suggested by Claude (Anthropic) were incorporated into this version.