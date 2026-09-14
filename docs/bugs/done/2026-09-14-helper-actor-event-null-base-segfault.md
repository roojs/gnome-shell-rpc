# Helper.Actor.event: `base.event` NULL → SIGSEGV on pointer motion

**Status:** ✔️ FIXED  
**Hit:** 2026-09-14 nest stay-up (after spawnv FD PASS)  
**Plan:** [`0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md)  
**Roles:** **consumer** Helper.Actor

---

## Symptom

Nest reaches READY + `WaylandClient.spawnv` with `stdout_fd>=0 buffer=yes`.
Mutter dies **ec=139** when the pointer moves over chrome. Stay-up without
mouse motion holds; motion kills it.

## Evidence

gdb (`scripts/mutter-rpc-catchsegv.sh`):

```
#0  0x0
#1  Helper.Actor.real_event  ClutterActor.vala:292  (call *parent->event)
#6  clutter_actor_event
#9  clutter_stage_update_device
#11 clutter_stage_handle_event
```

Disasm: after `measure_event` returns false (or hook null), Vala `base.event`
loads `ClutterActorClass.event` from `parent_class` at `+0x100` and
`call *%rbx` with **rbx=0**. St.Widget does not install that class handler;
Clutter treats a NULL slot as “no default” — not a callable.

## Root cause

```vala
public override bool event(Clutter.Event clutter_event) {
    var hook = this.vfuncs.get("event");
    if (hook == null) {
        return base.event(clutter_event);  // → NULL call
    }
    if (LayoutHooks.measure_event(...)) {
        return true;
    }
    return base.event(clutter_event);      // → NULL call
}
```

Any pointer motion that picks a `Helper.Actor` (all GJS St peers) hits this.

## Fix

Fall through with `return false` (EVENT_PROPAGATE). Do **not** call
`base.event` when the parent class slot is unused.

**🚫** Idle / suppress_emit. **🚫** Soft-CRITICAL. **🚫** Skip hook emit for motion
as the “fix” (separate perf question after stay-up).
