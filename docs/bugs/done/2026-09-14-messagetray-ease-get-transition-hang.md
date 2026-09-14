# MessageTray banner never auto-hides (`Transition::stopped` not relayed)

**Status:** ⏳ fix in flight  
**Hit:** 2026-09-14 nest — banners stay until dismiss / nest death  
**Plan:** [`0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)  
**Roles:** **consumer** Actor + Runtime subscribe demux

---

## Symptom

Notification banners show and stay. Stock expects ~4s
(`NOTIFICATION_TIMEOUT`) then `_hideNotification` via `bannerBin.ease`.

## Root cause

Stock `ui/environment.js` `Actor.ease()`:

1. `set_easing_*` + `actor.set({opacity, y, …})` (RPC → server animates)
2. `get_transition(prop)` → leased Transition
3. `transition.connect('stopped', onComplete)`

`Transition::stopped` was never subscribed / re-emitted on the client proxy,
so ease waited forever → `_showNotificationCompleted` never ran →
no `NOTIFICATION_TIMEOUT`.

**🚫** Override `get_transition` to `return null` (fake “no transition”
shortcut). Real method must stay; wire subscribe instead.

## Fix

1. `Actor.get_transition` — still RPC; on non-null result call
   `Runtime.ensure_signal_subscribe(transition, "stopped")`.
2. `Runtime` — `RPC-Live-Subscribe.rpc_signal`; on Notification
   `method=stopped` → `g_signal_emit_by_name(proxy, "stopped", true)`.

ℹ️ OPC `Subscription.emit` packs no signal args — finished assumed true
(normal completion). IdleMonitor user-active gate is separate if banners
still stick after ease completes with pointer idle at show.

**🚫** Vendor `messageTray.js`. **🚫** Null `get_transition` stub.
