# Clutter.Actor.get_accessible() is null (quick settings)

**Status:** ✔️ fixed — lazy local Atk peer on Actor.accessible  
**Hit:** 2026-09-08 (~19:56 nested)  
**Plan:** T-030 soft gap  

---

## Symptom

```
Failed to setup quick settings: TypeError: this.get_accessible() is null
_init@…/quickSettings.js:106  # add_relationship(DESCRIBED_BY, …)
```

UTF8/`get_icon_name` already clear; fail is next line in QuickToggle._init.

## Cause

GIR `Actor.get/set_accessible` denied. Override had `Atk.Object? accessible { get; set; }` defaulting to **null**. Stock Clutter mints on get; we did not.

## Fix

`Actor.override.vala` — lazy `Atk.GObjectAccessible.for_object(this)` in the getter; explicit set (e.g. `St.GenericAccessible`) still wins. Still temporary until server Atk peers are leased.

## Prove

Nested re-prove after rebuild — no `get_accessible() is null` on quick settings setup.
