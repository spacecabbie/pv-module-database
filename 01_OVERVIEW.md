# PV Module Database — Tables & Columns

**Version:** 0.2  
**Last Updated:** June 19, 2026

---

## TABLE: `manufacturers`

**Purpose:** Single source of truth for all solar panel manufacturers. Prevents duplicate and inconsistent manufacturer names ("SunPower" vs "sunpower" vs "SunPower Corp").

**A single row represents:** One manufacturer/brand of solar panels.

---

### Columns

| Column | Type | Null | Default | Example | Notes |
|--------|------|------|---------|---------|-------|
| `id` | INTEGER | ✗ | AUTO | 1 | Primary Key. Auto-incremented. |
| `name` | TEXT | ✗ | — | "Victron Energy" | **Unique.** The official brand name. Case-sensitive. |
| `country` | TEXT | ✓ | NULL | "NL" | ISO 2-letter country code (NL, DE, CN, etc.) or full name. |
| `website` | TEXT | ✓ | NULL | "https://victronenergy.com" | Official manufacturer website. |
| `notes` | TEXT | ✓ | NULL | "Primarily marine/RV focus" | Any additional context (market segment, divisions, etc.). |
| `created_at` | TEXT | ✗ | NOW | "2026-06-19 14:32:00" | ISO 8601 timestamp. Set automatically. |

---

### Indexes

```sql
CREATE UNIQUE INDEX idx_manufacturers_name ON manufacturers(name);
```

**Rationale:** Prevents duplicate manufacturers; enables fast lookups by name.

---

### Constraints & Rules

- **UNIQUE(name)** — No two manufacturers can have the same name
- **name is NOT NULL** — Every manufacturer record must have a name
- **created_at is auto-timestamped** — For audit trail of when manufacturer records were added

---

### Example Rows

```sql
INSERT INTO manufacturers (name, country, website, notes) VALUES
('Victron Energy', 'NL', 'https://victronenergy.com', 'Off-grid and marine specialist'),
('SunPower', 'US', 'https://sunpower.com', 'High-efficiency residential and commercial'),
('Jinko Solar', 'CN', 'https://jinkosolar.com', 'Leading module manufacturer');
```

---

---

## TABLE: `modules`

**Purpose:** Core table storing all photovoltaic panel specifications and metadata.

**A single row represents:** One unique solar panel model from one manufacturer.

**Uniqueness:** Each (manufacturer_id, model) pair is unique — the same model number from different manufacturers is stored as separate records.

---

### Column Groups

#### **Identification Columns**

| Column | Type | Null | Example |
|--------|------|------|---------|
| `id` | INTEGER | ✗ | 1 |
| `manufacturer_id` | INTEGER | ✗ | 5 |
| `model` | TEXT | ✗ | "115W-12V Mono" |
| `series` | TEXT | ✓ | "PV Series 12V" |

**Notes:**
- `id` is the primary key
- `manufacturer_id` must exist in the `manufacturers` table
- `model` is case-sensitive and often includes wattage and voltage info
- `series` groups related models (e.g., "Maxeon 6", "Tiger Neo")

---

#### **Data Quality Level**

| Column | Type | Null | Check | Example |
|--------|------|------|-------|---------|
| `data_level` | TEXT | ✗ | ('minimal', 'optimal', 'complete') | 'optimal' |

**Defines what fields are reliably populated:**

- **minimal** — Only p_max, voc, isc guaranteed
- **optimal** — Minimal + vmp, imp, temp_coeff, technology, cells_in_series
- **complete** — Optimal + efficiency, physical dimensions, weight, connector, datasheet

**When querying:** Filter by `data_level` to ensure fields you need are populated.

---

#### **Electrical Specifications — Minimal Level**

| Column | Type | Unit | Null | Example | Purpose |
|--------|------|------|------|---------|---------|
| `p_max` | REAL | Watts (W) | ✓ | 115 | Maximum power at STC (Standard Test Condition: 1000 W/m², 25°C) |
| `voc` | REAL | Volts (V) | ✓ | 21.6 | Open-circuit voltage at STC. **Critical for MPPT voltage rating.** |
| `isc` | REAL | Amps (A) | ✓ | 6.62 | Short-circuit current at STC. |

**Usage:** Always check `voc` to ensure MPPT can handle the panel string voltage, especially in cold climates.

---

#### **Electrical Specifications — Optimal Level**

| Column | Type | Unit | Null | Example | Purpose |
|--------|------|------|------|---------|---------|
| `vmp` | REAL | Volts (V) | ✓ | 17.4 | Operating voltage at maximum power point (STC) |
| `imp` | REAL | Amps (A) | ✓ | 6.61 | Operating current at maximum power point (STC) |
| `cells_in_series` | INTEGER | Count | ✓ | 36 | Number of cells in series. Common: 36 (12V nominal), 60 (24V nominal), 72 (36V nominal) |

**Notes:**
- Vmp × Imp ≈ Pmax (may differ slightly due to rounding)
- cells_in_series affects temperature coefficient behavior

---

#### **Temperature Coefficients — Optimal & Complete Levels**

| Column | Type | Unit | Null | Example | Purpose |
|--------|------|------|------|---------|---------|
| `temp_coeff_voc_pct` | REAL | %/°C | ✓ | -0.29 | Change in Voc per degree Celsius. **Must be negative.** Used to calculate cold-weather Voc for MPPT sizing. |
| `temp_coeff_isc_pct` | REAL | %/°C | ✓ | 0.06 | Change in Isc per degree Celsius. Usually slightly positive. |
| `temp_coeff_pmax` | REAL | %/°C | ✓ | -0.42 | **Most important:** Change in power per °C. **Critical for MPPT calculations.** Usually around -0.4 to -0.5%/°C. |

**Why these matter:**
- Cold climate → Voc rises above STC rating → must derate MPPT voltage
- MPPT calculator formula: `Voc_cold = Voc × (1 + temp_coeff_voc_pct × (T_min - 25))`

**Example:** If Voc=21.6V, temp_coeff=-0.29%/°C, and minimum temp is -10°C:
```
Voc_cold = 21.6 × (1 + (-0.0029) × (-10 - 25))
         = 21.6 × (1 + (-0.0029) × (-35))
         = 21.6 × 1.1015
         = 23.79V
```

---

#### **Technology & Design — Optimal Level**

| Column | Type | Null | Check | Example | Purpose |
|--------|------|------|-------|---------|---------|
| `technology` | TEXT | ✓ | ('mono-Si', 'poly-Si', 'HJT', 'TOPCon', 'thin-film-CdTe', 'thin-film-CIGS', 'perovskite', 'other') | 'mono-Si' | Cell technology. Affects efficiency, temperature coefficient, cost, durability. |

**Typical efficiency by technology:**
- mono-Si: 18-22%
- poly-Si: 16-19%
- HJT: 20-23% (newer, expensive)
- TOPCon: 21-23% (increasingly common)
- thin-film: 11-17%

---

#### **Thermal & Performance — Complete Level**

| Column | Type | Unit | Null | Example | Purpose |
|--------|------|------|------|---------|---------|
| `efficiency` | REAL | % | ✓ | 17.5 | Module efficiency = (Pmax / (Area × 1000 W/m²)) × 100% |
| `t_noct` | REAL | °C | ✓ | 45 | Nominal Operating Cell Temperature. Real-world operating temp under 800 W/m², 20°C ambient, 1 m/s wind. Used for performance estimations. |

**Why NOCT matters:**
- STC rating is unrealistically cool (1000 W/m², 25°C)
- Real-world NOCT (≈45°C typical) gives more realistic output
- Some calculators use NOCT to derate power estimates

---

#### **Physical Specifications — Complete Level (via `module_physical` table)**

See the `module_physical` table section below for dimensions, weight, bifaciality, and connector type.

---

#### **Production Lifecycle**

| Column | Type | Null | Check | Example | Purpose |
|--------|------|------|-------|---------|---------|
| `introduced_year` | INTEGER | ✓ | — | 2018 | Year panel was first released |
| `discontinued_year` | INTEGER | ✓ | — | 2023 | Year production ended (if applicable) |
| `production_status` | TEXT | ✗ | ('active', 'discontinued', 'limited', 'unknown') | 'active' | Current manufacturing status |

**Usage:**
- **active** — Currently in production, widely available
- **discontinued** — No longer made, may still be available secondhand
- **limited** — Production limited, supply scarce
- **unknown** — Status not determined

---

#### **Data Provenance & Audit (for audit trail)**

| Column | Type | Null | Example | Purpose |
|--------|------|------|---------|---------|
| `source` | TEXT | ✓ | 'victron-website' | Data origin (datasheet, website, importer, etc.) |
| `source_detail` | TEXT | ✓ | 'https://victronenergy.com/solar-pv-panels' | URL or document reference |
| `created_by` | TEXT | ✓ | 'alice@example.com' | User who created the record |
| `created_at` | TEXT | ✗ | '2026-06-19 14:32:00' | ISO 8601 timestamp. Auto-set. |
| `updated_by` | TEXT | ✓ | 'bob@example.com' | User who last updated the record |
| `updated_at` | TEXT | ✓ | '2026-06-20 09:15:00' | ISO 8601 timestamp. Updated on record modification. |
| `modification_reason` | TEXT | ✓ | 'Corrected temp coeff from datasheet v2' | Why the record was changed |

---

#### **Data Status & Duplicate Management**

| Column | Type | Null | Check | Example | Purpose |
|--------|------|------|-------|---------|---------|
| `status` | TEXT | ✗ | ('active', 'duplicate', 'merged', 'archived') | 'active' | Record status. See below. |
| `merged_into_id` | INTEGER | ✓ | FOREIGN KEY | 42 | If this is a duplicate, ID of the primary record it merged into. **Enforces referential integrity.** |

**Status meanings:**
- **active** — This is the current, authoritative record
- **duplicate** — This record is a duplicate; see `merged_into_id` for the primary
- **merged** — This record has been merged with others; see `merged_into_id` for successor
- **archived** — This record is no longer in active use but retained for historical reasons

**Example:** If panels with id=10 and id=15 represent the same model, mark id=10 as `merged` with `merged_into_id=15`. Old data on id=10 is preserved in `module_audit_log`.

---

#### **Extensibility**

| Column | Type | Null | Check | Example | Purpose |
|--------|------|------|-------|---------|---------|
| `notes` | TEXT | ✓ | — | 'Bifacial capable, but bifaciality not specified' | Free-text notes for edge cases or caveats |
| `extra_data` | TEXT | ✓ | JSON VALID | `{"octoplus_capable":true,"frame":"anodized"}` | JSON for future fields without schema changes |

**extra_data** is validated as valid JSON (or NULL), allowing flexible extensibility.

---

### Constraints

```sql
UNIQUE(manufacturer_id, model)          -- No duplicate (mfr, model) pairs
CHECK(data_level IN (...))              -- Restricted values
CHECK(production_status IN (...))       -- Restricted values
CHECK(status IN (...))                  -- Restricted values
CHECK(technology IN (...))              -- Restricted values
FOREIGN KEY(manufacturer_id)            -- Points to valid manufacturer
FOREIGN KEY(merged_into_id)             -- Points to valid modules record (or NULL)
```

---

### Indexes

```sql
CREATE INDEX idx_modules_data_level ON modules(data_level);
CREATE INDEX idx_modules_status ON modules(status);
CREATE INDEX idx_modules_merged_into ON modules(merged_into_id);
CREATE INDEX idx_modules_production_status ON modules(production_status);
CREATE INDEX idx_modules_manufacturer_model ON modules(manufacturer_id, model);
```

**Why:** Speed up filtering by quality level, finding duplicates, and (mfr, model) lookups.

---

### Example Row

```sql
INSERT INTO modules (
    manufacturer_id, model, series, data_level,
    p_max, voc, isc, vmp, imp,
    temp_coeff_voc_pct, temp_coeff_isc_pct, temp_coeff_pmax,
    technology, cells_in_series, efficiency, t_noct,
    introduced_year, production_status,
    source, created_by
) VALUES (
    1, '115W-12V Mono', 'PV Series 12V', 'optimal',
    115, 21.6, 6.62, 17.4, 6.61,
    -0.29, 0.06, -0.42,
    'mono-Si', 36, 17.5, 45,
    2015, 'active',
    'victron-website', 'import-tool-v1'
);
```

---

---

## TABLE: `module_physical`

**Purpose:** Store optional physical/mechanical specifications. Separated from `modules` because not all data levels require this information.

**A single row represents:** Physical dimensions and connector info for one module.

**Relationship:** One-to-one with `modules` (one module has zero or one physical record).

---

### Columns

| Column | Type | Unit | Null | Example | Notes |
|--------|------|------|------|---------|-------|
| `id` | INTEGER | — | ✗ | 1 | Primary Key |
| `module_id` | INTEGER | — | ✗ | 42 | **Unique Foreign Key** to modules(id). One physical record per module. |
| `length_mm` | REAL | mm | ✓ | 1960 | Outer dimension (usually longer side) |
| `width_mm` | REAL | mm | ✓ | 992 | Outer dimension (usually shorter side) |
| `height_mm` | REAL | mm | ✓ | 40 | Frame depth / thickness |
| `weight_kg` | REAL | kg | ✓ | 19.8 | Total module weight |
| `bifacial` | INTEGER | 0\|1 | ✗ | 0 | **CHECK(bifacial IN (0,1))** — Is the module bifacial (both sides generate power)? |
| `bifaciality` | REAL | % | ✓ | 75 | If bifacial, the rear-side efficiency as % of front-side |
| `connector_type` | TEXT | — | ✓ | "MC4" | Electrical connector (MC4, MC3, H4, etc.) |

---

### Example Data

**Monofacial module:**
```sql
INSERT INTO module_physical VALUES
(NULL, 42, 1960, 992, 40, 19.8, 0, NULL, 'MC4');
```

**Bifacial module (75% bifaciality):**
```sql
INSERT INTO module_physical VALUES
(NULL, 43, 2000, 1000, 35, 18.5, 1, 75, 'MC4');
```

---

### Usage Notes

- **optional:** A module can exist without a physical record (e.g., if dimensions are unknown)
- **bifaciality:** Only meaningful if `bifacial=1`; should be NULL if `bifacial=0`
- **Useful for:** System design (fitting on roof), installation planning, and performance modeling with albedo effects

---

---

## TABLE: `module_certificates`

**Purpose:** Track certifications and compliance standards for each module.

**A single row represents:** One certification standard for one module.

**Relationship:** Many-to-one with `modules` (one module can have multiple certificates).

---

### Columns

| Column | Type | Null | Example | Purpose |
|--------|------|------|---------|---------|
| `id` | INTEGER | ✗ | 1 | Primary Key |
| `module_id` | INTEGER | ✗ | 42 | Foreign Key to modules(id) |
| `standard` | TEXT | ✗ | 'IEC 61215:2021' | Certification standard (IEC, UL, MCS, etc.) |
| `certifier` | TEXT | ✓ | 'TÜV Rheinland' | Testing/certifying lab |
| `valid_from` | TEXT | ✓ | '2022-06-15' | ISO date when certificate became valid |
| `valid_until` | TEXT | ✓ | '2025-06-15' | ISO date when certificate expires |

---

### Example Data

```sql
INSERT INTO module_certificates (module_id, standard, certifier, valid_from, valid_until) VALUES
(42, 'IEC 61215:2021', 'TÜV Rheinland', '2022-06-15', '2025-06-15'),
(42, 'UL 1703', 'UL', '2022-01-01', NULL),  -- No expiration
(42, 'MCS', 'Microgeneration Certification Scheme', '2021-09-01', '2024-09-01');
```

---

### Usage Notes

- **Future expansion:** Not yet required in v0.2; prepared for future use
- **Useful for:** Warranty eligibility, regional compliance (EU, US, UK), and tracking certification currency
- **valid_until=NULL:** Certificate never expires (e.g., UL)

---

---

## TABLE: `module_audit_log`

**Purpose:** Complete immutable audit trail of every change to the database.

**A single row represents:** One action taken on one module (insert, update, merge, archive).

**Relationship:** Many-to-one with `modules` (one module has many audit events).

---

### Columns

| Column | Type | Null | Example | Purpose |
|--------|------|------|---------|---------|
| `id` | INTEGER | ✗ | 1 | Primary Key. Monotonically increasing. |
| `module_id` | INTEGER | ✗ | 42 | Which module was affected |
| `action` | TEXT | ✗ | 'update' | **CHECK(action IN ('insert', 'update', 'delete', 'merge', 'archive'))** |
| `changed_by` | TEXT | ✓ | 'alice@example.com' | Who made the change |
| `changed_at` | TEXT | ✗ | '2026-06-20 09:15:00' | ISO 8601 timestamp. Auto-set. |
| `reason` | TEXT | ✓ | 'Corrected temp coeff per datasheet v2' | Why the change was made |
| `old_data` | TEXT | ✓ | `{"voc":21.5,"isc":6.61}` | **JSON.** Previous values (snapshot of changed columns only). |
| `new_data` | TEXT | ✓ | `{"voc":21.6,"isc":6.62}` | **JSON.** New values (snapshot of changed columns only). |

---

### Constraints

```sql
CHECK(json_valid(old_data) OR old_data IS NULL)
CHECK(json_valid(new_data) OR new_data IS NULL)
CHECK(action IN ('insert', 'update', 'delete', 'merge', 'archive'))
FOREIGN KEY(module_id) REFERENCES modules(id) ON DELETE CASCADE
```

**ON DELETE CASCADE:** If a module is deleted, its audit log is also deleted (data integrity).

---

### Example Data

**Insertion event:**
```sql
INSERT INTO module_audit_log (module_id, action, changed_by, reason, old_data, new_data)
VALUES (
    42,
    'insert',
    'import-tool-v1',
    'Imported from Victron website',
    NULL,
    JSON('{"p_max":115,"voc":21.6,"isc":6.62,"technology":"mono-Si"}')
);
```

**Update event (temperature coefficient correction):**
```sql
INSERT INTO module_audit_log (module_id, action, changed_by, reason, old_data, new_data)
VALUES (
    42,
    'update',
    'alice@example.com',
    'Corrected temp_coeff_voc from -0.28 to -0.29 per datasheet v2',
    JSON('{"temp_coeff_voc_pct":-0.28}'),
    JSON('{"temp_coeff_voc_pct":-0.29}')
);
```

**Merge event (duplicate management):**
```sql
INSERT INTO module_audit_log (module_id, action, changed_by, reason, new_data)
VALUES (
    10,  -- Old record
    'merge',
    'bob@example.com',
    'Merged duplicate records; id=10 merged into id=15',
    JSON('{"status":"merged","merged_into_id":15}')
);
```

---

### Usage

**Query:** "Show all changes to this module"
```sql
SELECT changed_at, action, changed_by, reason, old_data, new_data
FROM module_audit_log
WHERE module_id = 42
ORDER BY changed_at DESC;
```

**Query:** "Who imported data, and when?"
```sql
SELECT DISTINCT changed_by, MIN(changed_at) AS first_change
FROM module_audit_log
GROUP BY changed_by
ORDER BY first_change DESC;
```

---

### Design Notes

- **Immutable:** Once inserted, audit log records should never be updated or deleted
- **JSON columns:** Allows flexible field capture; not every change touches all columns
- **Snapshot:** old_data/new_data contain only the fields that changed, making diffs clear
- **No sensitive data:** Passwords, API keys, etc. must never be logged

---

---

## TABLE: `schema_meta`

**Purpose:** Metadata about the database schema itself (version, creation date, etc.).

**A single row represents:** One schema metadata key-value pair.

---

### Columns

| Column | Type | Notes |
|--------|------|-------|
| `key` | TEXT | Primary Key. Schema metadata key (e.g., 'version', 'created_at') |
| `value` | TEXT | Metadata value |

---

### Initial Data

```sql
INSERT INTO schema_meta VALUES ('version', '0.2');
INSERT INTO schema_meta VALUES ('created_at', datetime('now'));
INSERT INTO schema_meta VALUES ('description', 'PV Module Database');
INSERT INTO schema_meta VALUES ('last_updated', datetime('now'));
```

---

### Usage

**Query:** "What schema version is this?"
```sql
SELECT value FROM schema_meta WHERE key = 'version';
```

---

---

## Summary

| Table | Rows | Purpose |
|-------|------|---------|
| `manufacturers` | 100s | Lookup table for consistent manufacturer names |
| `modules` | 100,000+ | Core module specifications and metadata |
| `module_physical` | 100,000+ (partial) | Optional physical/mechanical specs |
| `module_certificates` | 200,000+ (future) | Certification tracking per module |
| `module_audit_log` | 500,000+ | Complete change history |
| `schema_meta` | ~5 | Database schema metadata |

---

**Next:** Read [Relationships](03_RELATIONSHIPS.md) for foreign key patterns and joins.
