# volume.js `this._output is undefined`

**Status:** ✔️ done — `Runtime.do_call` → `OLLMrpc.Client.call_sync` (private MainContext)  
**Hit:** 2026-09-08 ~20:23 nested  
**Plan:** T-030 soft gap  
**OPC:** [call_sync](../../../../gitlive/OLLMchat/docs/bugs/2026-09-08-sync-call-nested-mainloop-reentrancy.md)  

---

## Symptom

```
JS ERROR: TypeError: this._output is undefined
_readOutput@…/volume.js:479
OutputIndicator/<@…/volume.js:454   // default-sink-changed
… QuickToggleMenu / OutputStreamSlider._init …
OutputIndicator@…/volume.js:457     // still assigning this._output =
```

Init continues (soft). Same race on `InputIndicator` / `_input`.

## Cause (ours, not stock JS)

Stock connects Gvc signals before `this._output = new OutputStreamSlider(…)`. That is fine in-process because Gvc almost never emits mid-construct.

Out-of-process, every GI stub call goes through `GiStub.Runtime.do_call`:

```vala
var call_loop = new GLib.MainLoop();
Runtime.client.call.begin(request, (obj, res) => {
    …; call_loop.quit();
});
call_loop.run();  // dispatches DEFAULT main context
```

While waiting on the socket, the nested loop runs **all** default-context sources — including Pulse/Gvc. `default-sink-changed` fires into JS while `OutputStreamSlider` is still constructing → `_output` unset.

Not a volume.js bug. Not fixed by reordering stock JS (that only papers over one call site).

## Fix

✔️ OPC `Client.call_sync` (private MainContext for RPC IO only).
✔️ Consumer `GiStub.Runtime.do_call` → `call_sync` (no nested default `MainLoop`).

## Prove

✔️ Nested 2026-09-08 ~21:11 after OPC `call_sync` (no push_thread_default): no `_output is undefined` observed (boot reached `notify_ready` / layout backgrounds). Call-sync re-entrancy path cleared.

Next wall: `Meta-BackgroundImageCache.load` empty `-32602` (shell exits).
