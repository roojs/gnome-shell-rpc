# valac GIR emits `GLib.DesktopAppInfo` — that type does not exist in GI

**Who:** **our** `Shell-16` typelib. GJS reads it (`gi://Shell`). Not RPC, not a GJS bug.

**Status:** ✔️ **closed** (2026-09-21) — user: death / stop on app-info is gone.
`xsltproc` + `gir-inject.xsl` rewrites `App.get_app_info` / `app-info` to
`Gio.DesktopAppInfo`. Gate `H-appinfo-gir` / `H-appinfo-gir-typelib` /
`H-appinfo-call` **ok** (2026-09-21). `app-search-empty-gate` still FAILs
`H-queue-relayout` — that is not this type miss.

**Search overlay:** [`2026-09-19-overview-app-search-empty.md`](2026-09-19-overview-app-search-empty.md)
**Plan:** [`0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md)

**Upstream (do not file again):** Vala [!454](https://gitlab.gnome.org/GNOME/vala/-/merge_requests/454) — same GJS `Unable to resolve arg type 'DesktopAppInfo'`, same valac GIR `GLib.DesktopAppInfo`. Closed unmerged 2026-03-19 (ricotz). No Vala **issue** titled DesktopAppInfo. Later Vala main (`16791f5a0`, 2026-05-27) generates `gio-unix-2.0.vapi` from `GioUnix-2.0.gir` → `gir_namespace = "GioUnix"` (not `Gio`). Distro valac here is still 0.56 / `GLib.DesktopAppInfo`. GNOME Shell [!3855](https://gitlab.gnome.org/GNOME/gnome-shell/-/merge_requests/3855) switches JS to `GioUnix.DesktopAppInfo` (49+); our vendor/stock `Shell-16.gir` is still `Gio.DesktopAppInfo`.

---

## GJS

```js
// vendor/gnome-shell/js/ui/appDisplay.js:2205
if (!this._parentalControlsManager.shouldShowApp(app.get_app_info()))
```

```text
JS ERROR: Error: Unable to resolve arg type 'DesktopAppInfo'
addAppId@resource:///org/gnome/shell/ui/appDisplay.js:2205:66
_loadApps@resource:///org/gnome/shell/ui/appDisplay.js:2215:20
FolderView@…
```

## Input (Vala)

```vala
// src/shell-gi/App.vala
public GLib.DesktopAppInfo? app_info { get; construct; default = null; }
```

```vala
// /usr/share/vala-0.56/vapi/gio-2.0.vapi  (AppInfo → GIR Gio.AppInfo)
[CCode (cprefix = "G", gir_namespace = "Gio", gir_version = "2.0", lower_case_cprefix = "g_")]
namespace GLib {
```

```vala
// /usr/share/vala-0.56/vapi/gio-unix-2.0.vapi  (DesktopAppInfo — no gir_namespace)
[CCode (cprefix = "G", lower_case_cprefix = "g_")]
namespace GLib {
	public class DesktopAppInfo : GLib.Object, GLib.AppInfo {
```

## Output (GIR)

**Ours** `build/src/Shell-16.gir` (vala_gir, before inject):

```xml
<property name="app-info" writable="1" construct-only="1">
  <type name="GLib.DesktopAppInfo" c:type="GDesktopAppInfo*"/>
</property>
<method name="get_app_info" c:identifier="shell_app_get_app_info">
  <return-value transfer-ownership="none" nullable="1">
    <type name="GLib.DesktopAppInfo" c:type="GDesktopAppInfo*"/>
```

**Stock** `/usr/share/gnome-shell/Shell-16.gir`:

```xml
<method name="get_app_info" c:identifier="shell_app_get_app_info" glib:get-property="app-info">
  <return-value transfer-ownership="none">
    <type name="Gio.DesktopAppInfo" c:type="GDesktopAppInfo*"/>
…
<property name="app-info" … getter="get_app_info">
  <type name="Gio.DesktopAppInfo"/>
```

Same C type. `GLib-2.0.gir` has no `DesktopAppInfo`. `Gio-2.0.gir` has `<class name="DesktopAppInfo" c:type="GDesktopAppInfo">`.

**Same valac, working:** `get_installed` → `Gio.AppInfo` (from gio-2.0.vapi).

```xml
<method name="get_installed" c:identifier="shell_app_system_get_installed">
  <return-value transfer-ownership="container">
    <type name="GLib.List" c:type="GList*">
      <type name="Gio.AppInfo" c:type="GAppInfo*"/>
```

## Landed

Product override: `xsltproc` + `scripts/gir-inject.xsl` replaces `App.get_app_info` / `app-info` with `src/shell-gi/app-info.gir` (`Gio.DesktopAppInfo`) and drops `App.new`. **🚫** fake subclass vapi. **🚫** internal. **🚫** Vala dummy placeholders. **🚫** new upstream Vala issue.

```bash
meson test -C build --print-errorlogs app-search-empty-gate
# H-appinfo-gir / H-appinfo-call must be ok — not GLib.DesktopAppInfo
GSR_NESTED_STAYUP=1 ./scripts/weston-gsr-session.sh
# no: Unable to resolve arg type 'DesktopAppInfo'
```
