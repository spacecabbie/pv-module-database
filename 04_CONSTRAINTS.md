# PV Module Database — Constraints, Indexes & Business Rules

**Version:** 0.2  
**Last Updated:** June 19, 2026

---

## Overview

The database enforces **business rules** at multiple levels:
1. **SQL Constraints** — Enforced by the database engine (CHECK, UNIQUE, NOT NULL, FK)
2. **Application Rules** — Logic in code that calls the database
3. **Audit Trail** — The `module_audit_log` provides accountability and rollback capability

This document explains each rule, its purpose, and why it matters.

---

---

## Constraint 1: UNIQUE(manufacturer_id, model)

**Table:** `modules`

**Definition:**
```sql
UNIQUE(manufacturer_id, model)
```

**Effect:** No two modules can have the same (manufacturer, model) pair.

---

### Business Rule

Each unique combination of manufacturer and model represents a distinct product. Different manufacturers can have a "100W" panel, but the same manufacturer can't have duplicate model numbers.

---

### Examples

✓ **Allowed:**
```sql
INSERT INTO modules (manufacturer_id, model, p_max, voc, isc)
VALUES (1, '115W-12V Mono', 115, 21.6, 6.62);  -- Victron

INSERT INTO modules (manufacturer_id, model, p_max, voc, isc)
VALUES (2, '115W-12V Mono', 113, 21.5, 6.60);  -- SunPower (different mfr)
```

✗ **Rejected by database:**
```sql
INSERT INTO modules (manufacturer_id, model, p_max, voc, isc)
VALUES (1, '115W-12V Mono', 115, 21.6, 6.62);  -- Duplicate!
-- Error: UNIQUE constraint failed: modules.manufacturer_id, modules.model
```

---

### When to Use

Use UNIQUE to query or update:
```sql
-- Find a specific module by (mfr, model)
SELECT * FROM modules
WHERE manufacturer_id = 1 AND model = '115W-12V Mono';
```

**Replace duplicate:** Mark old version as `merged`:
```sql
UPDATE modules
SET status = 'duplicate', merged_into_id = 42
WHERE manufacturer_id = 1 AND model = '115W-12V Mono' AND id != 42;
```

---

---

## Constraint 2: CHECK(data_level IN (...))

**Table:** `modules`

**Definition:**
```sql
CHECK(data_level IN ('minimal', 'optimal', 'complete'))
```

**Effect:** Only allowed values are 'minimal', 'optimal', or 'complete'.

---

### Business Rule

The data quality level signals how complete the record is:

| Level | Guaranteed Fields | Use Case |
|---|---|---|
| minimal | manufacturer, model, p_max, voc, isc | Quick imports, basic MPPT sizing |
| optimal | minimal + vmp, imp, temp coeff, technology | Accurate MPPT calculations |
| complete | optimal + efficiency, physical, certs | Full system design |

---

### Examples

✓ **Allowed:**
```sql
INSERT INTO modules (manufacturer_id, model, data_level, p_max, voc, isc)
VALUES (1, 'Panel-A', 'minimal', 100, 20, 6);  -- Minimal data
```

✗ **Rejected:**
```sql
INSERT INTO modules (manufacturer_id, model, data_level, p_max, voc, isc)
VALUES (1, 'Panel-A', 'unknown', 100, 20, 6);
-- Error: CHECK constraint failed: data_level
```

---

### Query Best Practices

**Only use panels with optimal or better data:**
```sql
SELECT m.model, m.p_max, m.temp_coeff_pmax
FROM modules m
WHERE m.data_level IN ('optimal', 'complete')
  AND m.status = 'active';
```

**Check data level before calculating:**
```sql
-- Verify we have temp coefficients before MPPT calc
IF data_level = 'minimal' THEN
    WARN "This panel lacks temperature coefficients"
END
```

---

---

## Constraint 3: CHECK(technology IN (...))

**Table:** `modules`

**Definition:**
```sql
CHECK(technology IN (
    'mono-Si', 'poly-Si', 'HJT', 'TOPCon', 
    'thin-film-CdTe', 'thin-film-CIGS', 'perovskite', 'other'
))
```

**Effect:** Technology field is restricted to predefined values.

---

### Business Rule

Normalizes solar cell technology to enable filtering and analysis. Prevents free-text chaos ("mono", "monocrystalline", "Mono-PERC", "M10").

---

### Technology Reference

| Code | Full Name | Typical Efficiency | Notes |
|---|---|---|---|
| mono-Si | Monocrystalline Silicon | 18-22% | Dominant, mature, cost-effective |
| poly-Si | Polycrystalline Silicon | 16-19% | Older technology, less efficient |
| HJT | Heterojunction | 20-23% | Premium, low temp coefficient, expensive |
| TOPCon | Tunnel Oxide Passivated Contact | 21-23% | Emerging mainstream, excellent efficiency |
| thin-film-CdTe | Cadmium Telluride | 11-17% | Low cost, works in low light, rare now |
| thin-film-CIGS | Copper Indium Gallium Selenide | 13-19% | Flexible, low temp coefficient |
| perovskite | Perovskite | 15-25% | Experimental, high efficiency, durability questions |
| other | Unclassified | — | Catch-all for novel technologies |

---

### Examples

✓ **Allowed:**
```sql
INSERT INTO modules (manufacturer_id, model, technology, p_max, voc, isc)
VALUES (1, 'Panel-HJT', 'HJT', 115, 21.6, 6.62);
```

✗ **Rejected:**
```sql
INSERT INTO modules (manufacturer_id, model, technology, p_max, voc, isc)
VALUES (1, 'Panel-A', 'Monocrystalline', 115, 21.6, 6.62);
-- Error: CHECK constraint failed: technology
-- Should be 'mono-Si' instead
```

---

### Query Patterns

**Find all HJT and TOPCon panels:**
```sql
SELECT m.model, m.p_max, m.efficiency
FROM modules m
WHERE m.technology IN ('HJT', 'TOPCon')
  AND m.status = 'active'
ORDER BY m.efficiency DESC;
```

**Group by technology:**
```sql
SELECT m.technology, 
       COUNT(*) AS count,
       AVG(m.efficiency) AS avg_efficiency
FROM modules m
WHERE m.status = 'active'
GROUP BY m.technology
ORDER BY avg_efficiency DESC;
```

---

---

## Constraint 4: CHECK(production_status IN (...))

**Table:** `modules`

**Definition:**
```sql
CHECK(production_status IN ('active', 'discontinued', 'limited', 'unknown'))
```

**Effect:** Production status is restricted to four values.

---

### Business Rule

Tracks manufacturer production status, important for sourcing and warranty decisions.

| Status | Meaning | Sourcing Impact |
|---|---|---|
| active | Currently in production | Generally available, reliable supply |
| discontinued | No longer manufactured | May be available used, less reliable supply |
| limited | Limited production run | Scarce, premium pricing |
| unknown | Status not determined | Investigate before committing |

---

### Examples

✓ **Allowed:**
```sql
UPDATE modules
SET production_status = 'discontinued'
WHERE model = 'Old-Panel-2010';
```

✗ **Rejected:**
```sql
UPDATE modules
SET production_status = 'out_of_stock'
WHERE id = 1;
-- Error: CHECK constraint failed
-- Should be 'discontinued' or 'limited'
```

---

### Query Patterns

**Find only currently available panels:**
```sql
SELECT m.model, m.p_max
FROM modules m
WHERE m.production_status IN ('active', 'limited')
  AND m.status = 'active'
ORDER BY m.p_max DESC;
```

**Alert on obsolete panels in designs:**
```sql
SELECT DISTINCT m.model
FROM modules m
WHERE m.production_status = 'discontinued'
  AND m.status = 'active'
  -- Assumes you track which modules are used in designs
ORDER BY m.model;
```

---

---

## Constraint 5: CHECK(status IN (...))

**Table:** `modules`

**Definition:**
```sql
CHECK(status IN ('active', 'duplicate', 'merged', 'archived'))
```

**Effect:** Record status is restricted to four lifecycle states.

---

### Business Rule

Tracks the data lifecycle and duplicate resolution.

| Status | Meaning | Usage |
|---|---|---|
| active | This is the authoritative record | Default; query this |
| duplicate | This record is a duplicate; see `merged_into_id` | Don't use for calculations |
| merged | This record has been superseded | Retained for audit trail |
| archived | Old, no longer in use, kept for history | Exclude from queries |

---

### Duplicate Resolution Workflow

**Step 1:** Two panels exist
```
id=10: model='115W-12V', status='active', merged_into_id=NULL
id=15: model='115W-12V', status='active', merged_into_id=NULL
```

**Step 2:** Mark id=10 as duplicate
```sql
UPDATE modules
SET status = 'duplicate', merged_into_id = 15
WHERE id = 10;
```

**Step 3:** Query safely (only gets id=15)
```sql
SELECT * FROM modules
WHERE model = '115W-12V' AND status = 'active';
-- Returns only id=15
```

**Step 4:** Audit log preserves old data
```sql
SELECT * FROM module_audit_log WHERE module_id = 10;
-- Shows original data before merging
```

---

### Examples

✓ **Allowed:**
```sql
UPDATE modules SET status = 'archived' WHERE introduced_year < 2010;
```

✗ **Rejected:**
```sql
UPDATE modules SET status = 'obsolete' WHERE id = 1;
-- Error: CHECK constraint failed
-- Should be 'archived'
```

---

### Query Patterns

**Always exclude non-active records:**
```sql
-- Safe query (excludes duplicates, merged, archived)
SELECT m.model, m.p_max, m.voc
FROM modules m
WHERE m.status = 'active'
ORDER BY m.p_max DESC;

-- Or be explicit:
SELECT m.model, m.p_max, m.voc
FROM modules m
WHERE m.status IN ('active')  -- Not 'duplicate', 'merged', 'archived'
ORDER BY m.p_max DESC;
```

**Find duplicates:**
```sql
SELECT id, model, merged_into_id
FROM modules
WHERE status = 'duplicate'
ORDER BY merged_into_id;
```

---

---

## Constraint 6: CHECK(bifacial IN (0, 1))

**Table:** `module_physical`

**Definition:**
```sql
CHECK(bifacial IN (0, 1))
```

**Effect:** Bifacial is a boolean (0=monofacial, 1=bifacial).

---

### Business Rule

Restricts bifacial to boolean, ensuring data consistency.

---

### Examples

✓ **Allowed:**
```sql
INSERT INTO module_physical (module_id, bifacial, bifaciality)
VALUES (42, 1, 75);  -- Bifacial, 75% efficiency on rear
```

✗ **Rejected:**
```sql
INSERT INTO module_physical (module_id, bifacial)
VALUES (42, 'yes');  -- Wrong type!
-- Error: CHECK constraint failed
```

---

### Business Rule

**If bifacial=0:** `bifaciality` should be NULL (no rear efficiency if monofacial).

```sql
-- Application code should enforce:
IF bifacial = 0 THEN
    bifaciality = NULL
ELSE IF bifacial = 1 THEN
    bifaciality > 0 AND bifaciality <= 100
END
```

---

---

## Constraint 7: CHECK(json_valid(...))

**Tables:** `modules`, `module_audit_log`

**Definition:**
```sql
CHECK(json_valid(extra_data) OR extra_data IS NULL)
CHECK(json_valid(old_data) OR old_data IS NULL)
CHECK(json_valid(new_data) OR new_data IS NULL)
```

**Effect:** JSON columns can only store valid JSON.

---

### Business Rule

Ensures JSON data can be queried with `json_extract()` and other JSON functions without errors.

---

### Examples

✓ **Allowed:**
```sql
INSERT INTO modules (manufacturer_id, model, extra_data)
VALUES (1, 'Panel-A', '{"warranty_extended": true, "mounting_rails": 2}');

INSERT INTO modules (manufacturer_id, model, extra_data)
VALUES (1, 'Panel-B', NULL);  -- NULL is always allowed
```

✗ **Rejected:**
```sql
INSERT INTO modules (manufacturer_id, model, extra_data)
VALUES (1, 'Panel-A', 'not valid json');
-- Error: CHECK constraint failed
```

---

### Query Patterns

**Extract JSON values:**
```sql
SELECT m.model,
       JSON_EXTRACT(m.extra_data, '$.warranty_extended') AS extended_warranty,
       JSON_EXTRACT(m.extra_data, '$.mounting_rails') AS num_rails
FROM modules m
WHERE m.extra_data IS NOT NULL;
```

**Query nested JSON:**
```sql
-- Track old temperature coefficient from audit log
SELECT mal.changed_at,
       JSON_EXTRACT(mal.old_data, '$.temp_coeff_voc_pct') AS old_coeff,
       JSON_EXTRACT(mal.new_data, '$.temp_coeff_voc_pct') AS new_coeff
FROM module_audit_log mal
WHERE mal.module_id = 42
  AND mal.action = 'update';
```

---

---

## NOT NULL Constraints

| Table | Column | Reason |
|---|---|---|
| manufacturers | name | Every manufacturer must have a name |
| modules | manufacturer_id | Every module must have a manufacturer |
| modules | model | Every module must have a model |
| modules | data_level | Data quality tier must be declared |
| modules | production_status | Status must be tracked |
| modules | status | Lifecycle state must be known |
| modules | created_at | Audit trail requires creation date |
| module_audit_log | module_id | Every log entry references a module |
| module_audit_log | action | Every log entry records an action |
| module_audit_log | changed_at | Every change is timestamped |

---

---

## Indexes

**Purpose:** Speed up queries and enforce uniqueness.

### Index 1: UNIQUE(name) on manufacturers

```sql
CREATE UNIQUE INDEX idx_manufacturers_name ON manufacturers(name);
```

**Effect:** Prevents duplicate manufacturer names; enables fast lookups by name.

**Query improved:**
```sql
-- Uses index
SELECT * FROM manufacturers WHERE name = 'Victron Energy';
```

---

### Index 2: UNIQUE(manufacturer_id, model) on modules

```sql
CREATE UNIQUE INDEX idx_modules_manufacturer_model 
ON modules(manufacturer_id, model);
```

**Effect:** Enforces uniqueness; enables fast (mfr, model) lookups.

**Query improved:**
```sql
-- Uses index
SELECT * FROM modules
WHERE manufacturer_id = 1 AND model = '115W-12V Mono';
```

---

### Index 3: data_level on modules

```sql
CREATE INDEX idx_modules_data_level ON modules(data_level);
```

**Query improved:**
```sql
-- Uses index to find all 'optimal' records quickly
SELECT COUNT(*) FROM modules WHERE data_level = 'optimal';
```

---

### Index 4: status on modules

```sql
CREATE INDEX idx_modules_status ON modules(status);
```

**Query improved:**
```sql
-- Uses index
SELECT * FROM modules WHERE status = 'active';
```

---

### Index 5: production_status on modules

```sql
CREATE INDEX idx_modules_production_status 
ON modules(production_status);
```

**Query improved:**
```sql
-- Uses index
SELECT * FROM modules 
WHERE production_status IN ('active', 'limited');
```

---

### Index 6: merged_into_id on modules

```sql
CREATE INDEX idx_modules_merged_into ON modules(merged_into_id);
```

**Query improved:**
```sql
-- Uses index to find all duplicates of a module
SELECT * FROM modules WHERE merged_into_id = 42;
```

---

### Index 7: module_id on module_audit_log

```sql
CREATE INDEX idx_module_audit_log_module_id 
ON module_audit_log(module_id);
```

**Query improved:**
```sql
-- Uses index to get change history
SELECT * FROM module_audit_log WHERE module_id = 42;
```

---

### Index 8: module_id on module_physical (implicit from UNIQUE FK)

```sql
CREATE UNIQUE INDEX idx_module_physical_module_id 
ON module_physical(module_id);
```

**Query improved:**
```sql
-- Uses index
SELECT * FROM module_physical WHERE module_id = 42;
```

---

---

## Foreign Key Cascade Behaviors

See [Relationships](03_RELATIONSHIPS.md) for full details.

| Relationship | ON DELETE | ON UPDATE |
|---|---|---|
| manufacturer → module | RESTRICT | CASCADE |
| module → module_physical | CASCADE | CASCADE |
| module → module_audit_log | CASCADE | CASCADE |
| module → module_certificates | CASCADE | CASCADE |
| module → module (SELF, merged_into_id) | SET NULL | CASCADE |

---

---

## Application-Level Rules

These rules are **not enforced by SQL** but must be checked in application code:

### Rule 1: Circular Merge Prevention

❌ Don't allow A → B → C → A (cycle).

```python
# Pseudocode
def merge_modules(source_id, target_id):
    # Check that target has no parent
    target = modules.find(target_id)
    if target.merged_into_id is not None:
        raise ValueError(f"Target {target_id} is already a duplicate")
    
    # Check that source would not create a cycle
    # (traverse merged_into_id chain and ensure source is not ancestor)
    current = target
    while current.merged_into_id:
        current = modules.find(current.merged_into_id)
        if current.id == source_id:
            raise ValueError(f"Merge {source_id} → {target_id} would create a cycle")
    
    # Safe to merge
    modules.update(source_id, {'status': 'duplicate', 'merged_into_id': target_id})
```

---

### Rule 2: Data Quality Progression

✓ Data can only move up: minimal → optimal → complete.

```python
def update_data_level(module_id, new_level):
    current = modules.find(module_id)
    levels = {'minimal': 0, 'optimal': 1, 'complete': 2}
    
    if levels[new_level] < levels[current.data_level]:
        raise ValueError(f"Data quality cannot downgrade")
    
    modules.update(module_id, {'data_level': new_level})
```

---

### Rule 3: Temperature Coefficient Validity

✓ voc_coeff must be negative, isc_coeff usually positive.

```python
def validate_temp_coeffs(voc_coeff, isc_coeff, pmax_coeff):
    if voc_coeff is not None and voc_coeff >= 0:
        raise ValueError(f"voc_coeff must be negative, got {voc_coeff}")
    
    if isc_coeff is not None and isc_coeff < -0.5:  # Sanity check
        raise ValueError(f"isc_coeff unusually negative: {isc_coeff}")
    
    if pmax_coeff is not None and (pmax_coeff > -0.2 or pmax_coeff < -0.6):
        raise ValueError(f"pmax_coeff out of typical range: {pmax_coeff}")
```

---

### Rule 4: Bifaciality Only If Bifacial

```python
def validate_bifacial_data(bifacial, bifaciality):
    if bifacial == 0 and bifaciality is not None:
        raise ValueError("Monofacial panels cannot have bifaciality")
    
    if bifacial == 1 and bifaciality is None:
        raise ValueError("Bifacial panels must have bifaciality value")
    
    if bifacial == 1 and (bifaciality < 0 or bifaciality > 100):
        raise ValueError(f"Bifaciality must be 0-100%, got {bifaciality}")
```

---

---

## Summary

**SQL Constraints** enforce data integrity.  
**Indexes** speed up queries.  
**Application rules** enforce business logic that SQL can't express.  
**Audit logs** provide accountability and rollback capability.

---

**Next:** Read [Data Flow](04_DATA_FLOW.md) for insertion and update workflows.
