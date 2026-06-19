# PV Module Database — Relationships & Foreign Keys

**Version:** 0.2  
**Last Updated:** June 19, 2026

---

## Relationship Overview

The PV Module Database uses **foreign keys** to enforce data integrity across tables. This document explains how tables relate to each other and provides join patterns for common queries.

---

## Primary Keys

Every table has a surrogate primary key (auto-incrementing integer):

| Table | Primary Key | Type |
|-------|-------------|------|
| `manufacturers` | `id` | INTEGER AUTO |
| `modules` | `id` | INTEGER AUTO |
| `module_physical` | `id` | INTEGER AUTO |
| `module_certificates` | `id` | INTEGER AUTO |
| `module_audit_log` | `id` | INTEGER AUTO |
| `schema_meta` | `key` | TEXT (natural key) |

**Design rationale:** Surrogate keys are stable (never change), making them safe as foreign key targets. They enable easy record linking and referencing.

---

---

## Relationship 1: Manufacturers → Modules (1:N)

### Definition

```
manufacturers (1) ──────→ (N) modules
       id                    manufacturer_id [FK]
```

**Meaning:**
- One manufacturer can produce **zero or more** modules
- Each module belongs to **exactly one** manufacturer
- If you delete a manufacturer, all its modules become orphaned (prevented by constraint)

---

### Foreign Key Constraint

```sql
ALTER TABLE modules
ADD CONSTRAINT fk_modules_manufacturer
FOREIGN KEY (manufacturer_id) REFERENCES manufacturers(id)
ON DELETE RESTRICT
ON UPDATE CASCADE;
```

**ON DELETE RESTRICT:** Prevents deleting a manufacturer if modules reference it.  
**ON UPDATE CASCADE:** If a manufacturer ID changes (unlikely), all referencing modules update automatically.

---

### Join Pattern: All Panels from a Manufacturer

```sql
SELECT m.model, m.p_max, m.voc, m.isc
FROM modules m
JOIN manufacturers mfr ON m.manufacturer_id = mfr.id
WHERE mfr.name = 'Victron Energy'
ORDER BY m.p_max DESC;
```

**Result columns:**
- `m.model` — Panel model (e.g., "115W-12V Mono")
- `m.p_max` — Power rating (W)
- `m.voc` — Open-circuit voltage (V)
- `m.isc` — Short-circuit current (A)

---

### Join Pattern: Manufacturer Count by Country

```sql
SELECT mfr.country, COUNT(m.id) AS panel_count
FROM manufacturers mfr
LEFT JOIN modules m ON mfr.id = m.manufacturer_id
GROUP BY mfr.country
ORDER BY panel_count DESC;
```

**Notes:**
- **LEFT JOIN** ensures manufacturers with no modules are still counted (with 0)
- Groups results by country
- Useful for analyzing geographic distribution

---

---

## Relationship 2: Modules → Module_Physical (1:1)

### Definition

```
modules (1) ──────→ (0..1) module_physical
    id                      module_id [UNIQUE FK]
```

**Meaning:**
- Each module has **zero or one** physical record
- When a physical record exists, it belongs to **exactly one** module
- Not every module has a physical record (optional data)

---

### Foreign Key Constraint

```sql
ALTER TABLE module_physical
ADD CONSTRAINT fk_module_physical_module
FOREIGN KEY (module_id) REFERENCES modules(id)
ON DELETE CASCADE
ON UPDATE CASCADE;

CREATE UNIQUE INDEX idx_module_physical_module_id ON module_physical(module_id);
```

**ON DELETE CASCADE:** If a module is deleted, its physical record is also deleted.  
**UNIQUE(module_id):** Enforces one-to-one relationship (no duplicate module_ids).

---

### Join Pattern: Modules with Physical Specs

```sql
SELECT m.model, m.p_max, 
       mp.length_mm, mp.width_mm, mp.height_mm, mp.weight_kg,
       mp.bifacial, mp.bifaciality, mp.connector_type
FROM modules m
LEFT JOIN module_physical mp ON m.id = mp.module_id
WHERE m.manufacturer_id = 5;
```

**LEFT JOIN:** Includes modules even if they lack physical specs.

---

### Join Pattern: Find Bifacial Panels

```sql
SELECT m.model, m.p_max, mp.bifaciality
FROM modules m
INNER JOIN module_physical mp ON m.id = mp.module_id
WHERE mp.bifacial = 1
ORDER BY mp.bifaciality DESC;
```

**INNER JOIN:** Only returns modules with physical specs.

---

---

## Relationship 3: Modules → Module_Certificates (1:N)

### Definition

```
modules (1) ──────→ (N) module_certificates
    id                   module_id [FK]
```

**Meaning:**
- One module can have **zero or more** certificates
- Each certificate belongs to **exactly one** module
- If you delete a module, all its certificates are deleted

---

### Foreign Key Constraint

```sql
ALTER TABLE module_certificates
ADD CONSTRAINT fk_module_certificates_module
FOREIGN KEY (module_id) REFERENCES modules(id)
ON DELETE CASCADE
ON UPDATE CASCADE;

CREATE INDEX idx_module_certificates_module_id ON module_certificates(module_id);
```

**ON DELETE CASCADE:** Certificates follow their modules.

---

### Join Pattern: All Certifications for a Module

```sql
SELECT m.model, mc.standard, mc.certifier, 
       mc.valid_from, mc.valid_until
FROM modules m
LEFT JOIN module_certificates mc ON m.id = mc.module_id
WHERE m.id = 42
ORDER BY mc.valid_from DESC;
```

**Result:**
```
model              | standard      | certifier        | valid_from | valid_until
-------------------+---------------+------------------+------------+-----------
115W-12V Mono      | IEC 61215:2021| TÜV Rheinland    | 2022-06-15 | 2025-06-15
115W-12V Mono      | UL 1703       | UL               | 2022-01-01 | NULL
115W-12V Mono      | MCS           | MCS UK           | 2021-09-01 | 2024-09-01
```

---

### Join Pattern: Find All IEC 61215 Certified Modules

```sql
SELECT DISTINCT m.model, mfr.name
FROM modules m
JOIN manufacturers mfr ON m.manufacturer_id = mfr.id
JOIN module_certificates mc ON m.id = mc.module_id
WHERE mc.standard LIKE 'IEC 61215%'
  AND (mc.valid_until IS NULL OR mc.valid_until >= date('now'))
ORDER BY mfr.name, m.model;
```

---

---

## Relationship 4: Modules → Module_Audit_Log (1:N)

### Definition

```
modules (1) ──────→ (N) module_audit_log
    id                   module_id [FK]
```

**Meaning:**
- One module has **one or more** audit log entries (every insert creates an entry)
- Each log entry belongs to **exactly one** module
- Audit logs are immutable (write-only); they record all changes

---

### Foreign Key Constraint

```sql
ALTER TABLE module_audit_log
ADD CONSTRAINT fk_module_audit_log_module
FOREIGN KEY (module_id) REFERENCES modules(id)
ON DELETE CASCADE
ON UPDATE CASCADE;

CREATE INDEX idx_module_audit_log_module_id ON module_audit_log(module_id);
```

**ON DELETE CASCADE:** Deleting a module also deletes its audit history.

---

### Join Pattern: Full Change History for a Module

```sql
SELECT mal.changed_at, mal.action, mal.changed_by, 
       mal.reason, mal.old_data, mal.new_data
FROM module_audit_log mal
WHERE mal.module_id = 42
ORDER BY mal.changed_at DESC;
```

**Result:**
```
changed_at          | action | changed_by    | reason
--------------------+--------+---------------+---------------------------------------
2026-06-20 09:15:00 | update | alice@ex...   | Corrected temp_coeff_voc per datasheet
2026-06-19 14:32:00 | insert | import-tool-v1| Imported from Victron website
```

---

### Join Pattern: Who Made Changes and When?

```sql
SELECT changed_by, COUNT(*) AS change_count, 
       MIN(changed_at) AS first_change, MAX(changed_at) AS last_change
FROM module_audit_log
GROUP BY changed_by
ORDER BY change_count DESC;
```

**Useful for:** Understanding data stewardship and tracking contributor activity.

---

### Join Pattern: Show Specific Field Changes Over Time

```sql
SELECT mal.changed_at, 
       JSON_EXTRACT(mal.old_data, '$.temp_coeff_voc_pct') AS old_value,
       JSON_EXTRACT(mal.new_data, '$.temp_coeff_voc_pct') AS new_value,
       mal.reason
FROM module_audit_log mal
WHERE mal.module_id = 42
  AND (JSON_EXTRACT(mal.old_data, '$.temp_coeff_voc_pct') IS NOT NULL
       OR JSON_EXTRACT(mal.new_data, '$.temp_coeff_voc_pct') IS NOT NULL)
ORDER BY mal.changed_at DESC;
```

**Use:** Track corrections to a specific field over time.

---

---

## Relationship 5: Modules → Modules (Self-Reference, 1:1)

### Definition

```
modules (1) ──────→ (0..1) modules
    id                   merged_into_id [SELF FK]
```

**Meaning:**
- A module can point to another module as its "primary" (via `merged_into_id`)
- Handles duplicates without data loss
- If module A is a duplicate of module B, then A.merged_into_id = B.id

---

### Foreign Key Constraint

```sql
ALTER TABLE modules
ADD CONSTRAINT fk_modules_merged_into
FOREIGN KEY (merged_into_id) REFERENCES modules(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

CREATE INDEX idx_modules_merged_into ON modules(merged_into_id);
```

**ON DELETE SET NULL:** If the primary module is deleted, orphaned duplicates have merged_into_id set to NULL.  
**ON UPDATE CASCADE:** If the primary module's ID changes, references update automatically.

---

### Join Pattern: Find All Duplicates of a Module

```sql
SELECT id, model, status, merged_into_id
FROM modules
WHERE merged_into_id = 42
  AND status = 'duplicate';
```

**Result:** All records marked as duplicates, merged into module 42.

---

### Join Pattern: Resolve a Duplicate to Its Primary

```sql
SELECT m.id, m.model, m.status, 
       primary.id AS primary_id, primary.model AS primary_model
FROM modules m
LEFT JOIN modules primary ON m.merged_into_id = primary.id
WHERE m.status IN ('duplicate', 'merged')
ORDER BY m.merged_into_id;
```

---

### Duplicate Merge Workflow

**Step 1:** Identify duplicate
```sql
SELECT * FROM modules WHERE model = '115W-12V Mono';
-- Returns id=10 and id=15 (both are the same panel)
```

**Step 2:** Mark id=10 as duplicate, merged into id=15
```sql
UPDATE modules
SET status = 'duplicate',
    merged_into_id = 15,
    updated_by = 'alice@example.com',
    updated_at = datetime('now')
WHERE id = 10;
```

**Step 3:** Log the merge in audit trail
```sql
INSERT INTO module_audit_log (module_id, action, changed_by, reason, new_data)
VALUES (10, 'merge', 'alice@example.com', 
        'Duplicate of module 15', 
        JSON('{"status":"duplicate","merged_into_id":15}'));
```

**Step 4:** Query always uses the primary
```sql
SELECT m.id, m.model, m.p_max
FROM modules m
LEFT JOIN modules dup ON m.id = dup.merged_into_id
WHERE (m.status = 'active' OR dup.id IS NULL)
  AND m.model = '115W-12V Mono'
LIMIT 1;  -- Returns id=15
```

---

---

## Relationship Diagram (ERD)

```
┌─────────────────────────────┐
│    MANUFACTURERS (PK: id)   │
├─────────────────────────────┤
│ id [PK]                     │
│ name [UNIQUE]               │
│ country, website, notes     │
│ created_at                  │
└──────────────┬──────────────┘
               │ 1:N
               ↓
┌──────────────────────────────────────────────┐
│      MODULES (PK: id)                        │
├──────────────────────────────────────────────┤
│ id [PK]                                      │
│ manufacturer_id [FK → manufacturers]         │
│ model, series, data_level                    │
│ p_max, voc, isc, vmp, imp                   │
│ temp_coeff_*, cells_in_series                │
│ efficiency, t_noct, technology               │
│ introduced_year, discontinued_year           │
│ production_status, source, source_detail     │
│ created_by, created_at, updated_by, ...      │
│ status, merged_into_id [FK → modules SELF]   │
│ notes, extra_data [JSON]                     │
└──────┬─────────────┬────────────┬────────────┘
       │ 1:1         │ 1:N        │ 1:1 SELF
       │             │            │
       ↓             ↓            ↓
   [optional]   [optional]   [optional]
       │             │            │
   ┌───────────┐ ┌──────────┐ ┌──────────────┐
   │ MODULE_   │ │ MODULE_  │ │   MODULES    │
   │ PHYSICAL  │ │CERT.     │ │ (DUPLICATE)  │
   │           │ │          │ │              │
   │ • length  │ │ • std    │ │ merged_into_id
   │ • width   │ │ • cert.  │ │ [FK → SELF]
   │ • height  │ │ • dates  │ └──────────────┘
   │ • weight  │ └──────────┘
   │ • bifacial│
   └───────────┘
       ↑
       │ 1:N
       │
   ┌───────────────────────────────┐
   │  MODULE_AUDIT_LOG (1:N)       │
   ├───────────────────────────────┤
   │ id [PK]                       │
   │ module_id [FK → modules]      │
   │ action, changed_by, changed_at│
   │ reason                        │
   │ old_data [JSON], new_data [JSON]
   └───────────────────────────────┘
```

---

---

## Circular References (Prevented)

The database is designed to prevent invalid circular references:

❌ **Not allowed:** Module A merged into B, B merged into C, C merged into A (cycle)

This is prevented by:
1. **Application logic:** When merging, verify the target module's `merged_into_id` is NULL
2. **Soft constraint:** The schema allows self-reference but application code must validate

**Safe merge example:**
```sql
-- Before merge:
module 10: merged_into_id = NULL
module 15: merged_into_id = NULL

-- Merge 10 → 15 (safe, 15 has no parent):
UPDATE modules SET merged_into_id = 15 WHERE id = 10;

-- ✗ Don't do this (would create a cycle):
UPDATE modules SET merged_into_id = 10 WHERE id = 15;
```

---

---

## Cascade Behaviors

| Relationship | ON DELETE | ON UPDATE | Effect |
|---|---|---|---|
| manufacturer → module | RESTRICT | CASCADE | Can't delete manufacturer with modules; update cascades |
| module → module_physical | CASCADE | CASCADE | Delete physical when module deleted |
| module → module_certificate | CASCADE | CASCADE | Delete certs when module deleted |
| module → module_audit_log | CASCADE | CASCADE | Delete audit when module deleted |
| module → module (SELF) | SET NULL | CASCADE | Orphaned duplicates have NULL merged_into_id |

---

---

## Foreign Key Best Practices

### 1. Always Enable Foreign Keys

At the start of every database connection:
```sql
PRAGMA foreign_keys = ON;
```

SQLite doesn't enforce FKs by default!

### 2. Query Safety

Always use `LEFT JOIN` when the relationship is optional (like `module_physical`):
```sql
-- ✓ Correct: Includes modules without physical specs
SELECT m.*, mp.*
FROM modules m
LEFT JOIN module_physical mp ON m.id = mp.module_id;

-- ✗ Wrong: Excludes modules without physical specs
SELECT m.*, mp.*
FROM modules m
INNER JOIN module_physical mp ON m.id = mp.module_id;
```

### 3. Avoid Orphans

Never insert a `module_audit_log` without a valid `module_id`:
```sql
-- ✓ Safe: module_id=42 exists
INSERT INTO module_audit_log (module_id, action, ...)
VALUES (42, 'insert', ...);

-- ✗ Unsafe: FK constraint will reject this
INSERT INTO module_audit_log (module_id, action, ...)
VALUES (99999, 'insert', ...);  -- If 99999 doesn't exist
```

---

---

## Summary

| From | To | Type | Join | Constraint |
|---|---|---|---|---|
| manufacturers | modules | 1:N | INNER/LEFT | RESTRICT |
| modules | module_physical | 1:1 opt | LEFT | CASCADE |
| modules | module_certificates | 1:N opt | LEFT | CASCADE |
| modules | module_audit_log | 1:N | INNER | CASCADE |
| modules | modules (SELF) | 1:1 opt | LEFT | SET NULL |

**Next:** Read [Constraints & Rules](04_CONSTRAINTS.md) for business rule enforcement.
