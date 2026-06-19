# PV Module Database

**Version 0.1**

A structured, versioned database of photovoltaic (solar) module specifications designed primarily to support MPPT charge controller sizing calculations.

## Contents

- [Documentation](PV_Module_Database_Documentation.md)
- [Schema (SQLite)](schema_v0.1.sql)

## Features

- Three data quality levels: Minimal, Optimal, Complete
- Full audit logging and change history
- Intelligent duplicate management (link instead of delete)
- Future-proof design with JSON extensibility
- Production lifecycle tracking (introduced/discontinued)

## Quick Start

```bash
git clone https://github.com/spacecabbie/pv-module-database.git
```

Then import `schema_v0.1.sql` into SQLite.

## License

To be decided. Currently for personal and collaborative development use.

---

Maintained by Hans Haufe (@spacecabbie)