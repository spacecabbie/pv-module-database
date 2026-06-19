# PV Module Database

**Version 0.1**

A structured, versioned database of photovoltaic (solar) module specifications.

Designed to support MPPT charge controller sizing tools with different data quality levels, full audit logging, and smart duplicate management.

## Credits

- **Overall database design:** HHaufe
- **Detailed technical schema structure:** AI Grok and Claude

## Repository Contents

- [Documentation](PV_Module_Database_Documentation.md)
- [SQLite Schema v0.1](schema_v0.1.sql)
- [Changelog](CHANGELOG.md)

## Features

- Three data tiers: Minimal, Optimal, Complete
- Complete audit trail
- Duplicate linking (no data loss)
- Production lifecycle tracking
- Future-proof with JSON extensibility

## Quick Start

```bash
git clone https://github.com/spacecabbie/pv-module-database.git
```

Then import `schema_v0.1.sql` into SQLite.

---

Maintained by @spacecabbie