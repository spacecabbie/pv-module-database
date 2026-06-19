-- PV Module Database Schema
-- Version: 0.1
-- Date: 2026-06-19
-- Documentation: See PV_Module_Database_Documentation.md

-- ============================================
-- MAIN TABLE: modules
-- ============================================
CREATE TABLE modules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Core identification
    manufacturer TEXT NOT NULL,
    model TEXT NOT NULL,
    data_level TEXT NOT NULL CHECK(data_level IN ('minimal', 'optimal', 'complete')),
    
    -- Minimal level
    p_max REAL,
    voc REAL,
    isc REAL,
    
    -- Optimal level
    vmp REAL,
    imp REAL,
    temp_coeff_voc REAL,
    temp_coeff_isc REAL,
    technology TEXT,
    cells_in_series INTEGER,
    
    -- Complete level
    efficiency REAL,
    bifacial INTEGER DEFAULT 0 CHECK(bifacial IN (0,1)),
    bifaciality REAL,
    temp_coeff_voc_abs REAL,
    temp_coeff_isc_abs REAL,
    t_noct REAL,
    ptc_power REAL,
    length_mm REAL,
    width_mm REAL,
    height_mm REAL,
    weight_kg REAL,
    connector_type TEXT,
    datasheet_url TEXT,
    warranty_product_years INTEGER,
    warranty_performance_years INTEGER,
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
    merged_into_id INTEGER,
    
    -- Extensibility
    notes TEXT,
    extra_data TEXT,
    
    UNIQUE(manufacturer, model)
);

-- Indexes
CREATE INDEX idx_modules_data_level ON modules(data_level);
CREATE INDEX idx_modules_status ON modules(status);
CREATE INDEX idx_modules_merged_into ON modules(merged_into_id);
CREATE INDEX idx_modules_production_status ON modules(production_status);
CREATE INDEX idx_modules_manufacturer_model ON modules(manufacturer, model);


-- ============================================
-- AUDIT LOG TABLE
-- ============================================
CREATE TABLE module_audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    module_id INTEGER NOT NULL,
    action TEXT NOT NULL,
    changed_by TEXT,
    changed_at TEXT DEFAULT (datetime('now')),
    reason TEXT,
    old_data TEXT,
    new_data TEXT,
    FOREIGN KEY (module_id) REFERENCES modules(id) ON DELETE CASCADE
);

CREATE INDEX idx_audit_module_id ON module_audit_log(module_id);