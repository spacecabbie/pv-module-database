# PV Module Database

**Version 0.1**

A structured, versioned database of photovoltaic (solar) module specifications.

Designed to support MPPT charge controller sizing tools with different data quality levels, full audit logging, and smart duplicate management.

## Repository Contents

- [Documentation](PV_Module_Database_Documentation.md)
- [SQLite Schema v0.1](schema_v0.1.sql)

## Quick Links

- Full Documentation: [PV_Module_Database_Documentation.md](PV_Module_Database_Documentation.md)
- Schema: [schema_v0.1.sql](schema_v0.1.sql)

## Features

- Three data tiers: Minimal, Optimal, Complete
- Complete audit trail
- Duplicate linking (no data loss)
- Production lifecycle tracking
- Future-proof with JSON extensibility

Maintained by @spacecabbie