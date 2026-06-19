-- PV Module Database Schema
-- Version: 0.1
-- Date: 2026-06-19
-- Documentation: See PV_Module_Database_Documentation.md

-- ============================================
-- TABLE: manufacturers
-- ============================================
CREATE TABLE manufacturers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    country TEXT,
    website TEXT,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

-- ============================================
-- TABLE: modules
-- ============================================
CREATE TABLE modules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Core identification
    manufacturer_id INTEGER NOT NULL REFERENCES manufacturers(id),
    model TEXT NOT NULL,
    series TEXT,
    data_level TEXT NOT NULL CHECK(data_level IN ('minimal', 'optimal', 'complete')),
    
    -- Minimal level
    p_max REAL,
    voc REAL,
    isc REAL,
    
    -- Optimal level
    vmp REAL,
    imp REAL,
    temp_coeff_voc_pct REAL,      -- %/°C
    temp_coeff_isc_pct REAL,      -- %/°C
    temp_coeff_pmax REAL,         -- %/°C (important for MPPT)
    technology TEXT CHECK(technology IN ('mono-Si', 'poly-Si', 'HJT', 'TOPCon', 'thin-film-CdTe', 'thin-film-CIGS', 'perovskite', 'other')),
    cells_in_series INTEGER,
    
    -- Complete level
    efficiency REAL,
    t_noct REAL,
    
    -- Production lifecycle
    introduced_year INTEGER,
    discontinued_year INTEGER,
    production_status TEXT CHECK(production_status IN ('active', 'discontinued', 'limited', 'unknown')),
    
    -- Provenance & Audit
    source TEXT,
    source_detail TEXT,
    created_by TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_by TEXT,
    updated_at TEXT,
    modification_reason TEXT,
    
    -- Duplicate management
    status TEXT DEFAULT 'active' CHECK(status IN ('active', 'duplicate', 'merged', 'archived')),
    merged_into_id INTEGER REFERENCES modules(id) ON DELETE SET NULL,
    
    -- Extensibility
    notes TEXT,
    extra_data TEXT CHECK(json_valid(extra_data) OR extra_data IS NULL),
    
    UNIQUE(manufacturer_id, model)
);

-- ============================================
-- TABLE: module_physical
-- ============================================
CREATE TABLE module_physical (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    module_id INTEGER NOT NULL UNIQUE REFERENCES modules(id) ON DELETE CASCADE,
    length_mm REAL,
    width_mm REAL,
    height_mm REAL,
    weight_kg REAL,
    bifacial INTEGER DEFAULT 0 CHECK(bifacial IN (0,1)),
    bifaciality REAL,
    connector_type TEXT
);

-- ============================================
-- TABLE: module_audit_log
-- ============================================
CREATE TABLE module_audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    module_id INTEGER NOT NULL,
    action TEXT NOT NULL,
    changed_by TEXT,
    changed_at TEXT DEFAULT (datetime('now')),
    reason TEXT,
    old_data TEXT CHECK(json_valid(old_data) OR old_data IS NULL),
    new_data TEXT CHECK(json_valid(new_data) OR new_data IS NULL),
    FOREIGN KEY (module_id) REFERENCES modules(id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX idx_modules_data_level ON modules(data_level);
CREATE INDEX idx_modules_status ON modules(status);
CREATE INDEX idx_modules_merged_into ON modules(merged_into_id);
CREATE INDEX idx_modules_production_status ON modules(production_status);
CREATE INDEX idx_modules_manufacturer_model ON modules(manufacturer_id, model);
CREATE INDEX idx_audit_module_id ON module_audit_log(module_id);