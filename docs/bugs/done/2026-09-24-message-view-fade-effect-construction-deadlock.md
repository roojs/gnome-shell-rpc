# MessageView construction stops before `Helper-GLSLEffect.create`

**User goal:** nested mutter-rpc + gnome-shell-rpc completes boot and reaches
`READY=1`. From [`../../plans/0.8-init-complete-and-interaction.md`](../../plans/0.8-init-complete-and-interaction.md).

**Status:** ✔️ archived 2026-09-25 — user: archive. Local GIR strip lets
`message-view-construct-smoke` pass and stock boot passes the id-2955 wall.
2026-09-25 11:10 prove reaches `READY=1` and `prepare-started`. Follow-on:
[`../2026-09-25-unsubscribe-handler-not-on-instance.md`](../2026-09-25-unsubscribe-handler-not-on-instance.md).
Upstream `live-interface-gir-gate` stays FAIL.

## Seen

`org.gnome.ShellRpc.debug.log` ends with:

```text
id=2952 method=Clutter-Actor.new          replied id=2952
id=2953 method=Clutter-Actor.set_reactive replied id=2953
id=2954 method=Clutter-Actor.set_name     replied id=2954
id=2955 method=Clutter-Actor.hide         replied id=2955
```

The server receives and replies to all four calls. It remains responsive to
pointer motion. There is no in-flight RPC, connection reset, `JS ERROR`, or
`Helper-GLSLEffect.create`.

That sequence uniquely matches `MessageView` in stock `messageList.js`:

```js
const overlay = new Clutter.Actor({
    reactive: true,
    name: 'overlay',
    visible: false,
});

super({
    style_class: 'message-view',
    layout_manager: new MessageViewLayout(overlay),
    effect: new FadeEffect({name: 'highlight'}),
    x_expand: true,
    y_expand: true,
});
```

JavaScript evaluates the property values before calling `super()`. The stop is
therefore after `overlay` construction and before the `St.Viewport` constructor:

1. `new MessageViewLayout(overlay)`, whose constructor only calls `super()` and
   stores the overlay; or
2. local GObject initialization of `new FadeEffect(...)`, before
   `Shell.GLSLEffect` reaches its Vala `construct` block.

It is not blocked in `Clutter-Actor.hide`; that RPC replied.

## Last known good comparison

The 2026-09-23 08:53 boot ran the identical sequence:

```text
id=3131 method=Clutter-Actor.new
id=3132 method=Clutter-Actor.set_reactive
id=3133 method=Clutter-Actor.set_name
id=3134 method=Clutter-Actor.hide          replied id=3134
id=3135 method=Helper-GLSLEffect.create
id=3136 method=Clutter-ActorMeta.set_name
id=3137 method=Clutter-ActorMeta.set_enabled
id=3138 method=Helper-GLSLEffect.add_glsl_snippet
```

That boot later reached `READY=1`. The expected next call after the final
`hide` is therefore `Helper-GLSLEffect.create`.

## Reduced result

The missing call is `Helper-GLSLEffect.create`. That route belongs to
[`2026-09-21-shell-glsleffect-bin-alias.md`](2026-09-21-shell-glsleffect-bin-alias.md):
the client `Shell.GLSLEffect` constructor sends it, then `register_handle`.
The 20:22 boot never sends it.

`src/gjs-embed/message-view-construct-smoke.js` reproduces outside full Shell:

```text
layout after new MessageViewLayout
base effect before new
```

Direct `new Shell.GLSLEffect()` stops before its Vala `construct` block.
The `MessageViewLayout` constructor returns. A GJS `FadeEffect` subclass is not
required.

gdb proves this is a SIGSEGV rather than a constructor RPC deadlock:

```text
#0 g_interface_info_find_method
#1 g_object_info_find_method_using_interfaces
#2 libgjs.so.0
```

`Shell-16.gir` advertises
`<implements name="OLLMrpc.LiveInterface"/>` without an OLLMrpc include or
typelib. The independent
`tests/call-sync-repro/live-interface-gir-gate` builds a plain
`Peer : Object, OLLMrpc.Live.Interface`; GJS construction fails with the same
GIRepository assertion and SIGSEGV.

The OPC report is
`OLLMchat/docs/bugs/2026-09-25-live-interface-leaks-into-consumer-gir.md`.

## Gate

`scripts/gir-inject.xsl` removes only:

```xml
<implements name="OLLMrpc.LiveInterface"/>
```

from the generated consumer GIR before `g-ir-compiler`. The compiled GType
still implements `OLLMrpc.Live.Interface`.

After rebuilding `Shell-16.typelib`, `message-view-construct-smoke` passes:

```text
layout after new MessageViewLayout
base effect after new Shell_GLSLEffect
effect build_pipeline
effect after new FadeEffect
ok
```

Stock boot passes the former id-2955 wall. The 2026-09-25 11:10 prove reaches
`READY=1` and stops on `prepare-started` (script SIGKILL, not a compositor
exit).

The raw standalone `live-interface-gir-gate` intentionally remains FAIL until
Vala respects non-introspectable interfaces while writing `<implements>`.
Local Vala report:
`/home/alan/git/vala/bugs/girwriter-hidden-interface-implements.md`.

## Not this bug

- `notify::allocation` attempts to write a read-only property;
- nested `Meta.Barrier` has no backend implementation;
- the overview layout and icon-click regressions.
