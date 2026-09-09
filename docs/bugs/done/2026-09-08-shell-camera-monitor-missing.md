# Shell.CameraMonitor missing — quick settings camera indicator

**Status:** ✔️ minimal Soft port (`cameras-in-use` false)  
**Hit:** 2026-09-08 (~19:59 nested)  
**Plan:** T-030 soft gap  

---

## Symptom

```
Failed to setup quick settings: TypeError: (intermediate value).CameraMonitor is not a constructor
Indicator@…/status/camera.js:15
```

After `get_accessible` cleared.

## Fix

`src/shell-gi/CameraMonitor.vala` — stock GIR surface (`GObject` + `cameras-in-use`). PipeWire watch deferred; property default false.

## Follow-on

Full PipeWire port when privacy indicator must reflect live camera use.
