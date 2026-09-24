# Nested Wayland has no Meta.Barrier implementation

**User goal:** nested mutter-rpc + gnome-shell-rpc stays up and answers pointer and keyboard. From [`../plans/0.8-init-complete-and-interaction.md`](../plans/0.8-init-complete-and-interaction.md).

**Status:** ⏳ open

**Seen:** 2026-09-24 18:08:29, `org.gnome.ShellRpc.debug.log` and `mutter-rpc.debug.log`.

`layout.js` creates the panel-edge barrier with a property bag. The client now sends one `Meta-Barrier.new`. Mutter accepts the call and then fails `GInitable`.

```text
Client.vala:1017: id=2044 method=Meta-Barrier.new
Client.vala:1179: replied id=2044 error=Failed to create barrier impl
file src/Meta_window_generated.vala: line 391: uncaught error: Failed to create barrier impl (g-io-error-quark, 0)
```

Same for ids 2046 and 2047. Server:

```text
(../src/backends/meta-barrier.c:258):init_barrier_impl: runtime check failed: (priv->impl)
```

The `g_value_get_uint` criticals from 18:03 are gone. `directions` and `flags` are unpacked with `get_flags()`.

## Why `priv->impl` stays null

`/home/alan/mutter-test/mutter/src/backends/meta-barrier.c`, `init_barrier_impl`:

```c
#if defined(HAVE_NATIVE_BACKEND)
  if (META_IS_BACKEND_NATIVE (priv->backend))
    priv->impl = meta_barrier_impl_native_new (barrier);
#endif
  if (META_IS_BACKEND_X11 (priv->backend) &&
      !meta_is_wayland_compositor ())
    priv->impl = meta_barrier_impl_x11_new (barrier);

  g_warn_if_fail (priv->impl);
```

Native gets an implementation. X11 gets one only when Mutter is not a Wayland compositor. This nested session is Wayland and is not the native backend, so both branches miss.

`meta_barrier_constructed` still runs. `meta_barrier_initable_init` then fails the whole constructor:

```c
  if (!priv->impl)
    {
      g_set_error (error, G_IO_ERROR, G_IO_ERROR_FAILED,
                   "Failed to create barrier impl");
      return FALSE;
    }
```

`meta_barrier_new` returns NULL. The client `construct` does not catch that, so line 391 is an uncaught error and `rpc_lid` is never set.

This is not an X11-only API to skip on the client. The X11 branch is the one this session does not take. The `hit` signal doc already says delivery needs an XI2 server. The object itself is still what `layout.js` stores.

## Suggested fix

In Mutter, add a no-op `MetaBarrierImpl` and assign it from `init_barrier_impl` when the native branch and the X11 branch both do not run (nested Wayland). `release` does nothing. No pointer grab, so `hit` and `leave` never fire.

`GInitable` then succeeds and `Meta-Barrier.new` returns a live object. `layout.js` keeps `_rightPanelBarrier` / `_leftPanelBarrier`. Pressure barriers stay inert, which matches a backend with no barrier device.

Do not override `Meta.Barrier` on the client to swallow the error or invent a second object. A client that catches the `GError` and leaves `rpc_lid` at 0 still gives the shell no barrier.
