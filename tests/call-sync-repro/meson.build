executable('call-sync-repro',
  'repro.vala',
  dependencies: [dependency('gio-2.0')],
  install: false,
)

# Real libocrpc gate: post-call_poll Live.Invoke + idle MainContext only.
executable('after-reply-gate',
  [
    'after-reply-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Nested sync call_poll from inside a Live.Invoke while server in hook.emit
# — the "hang after settle" re-entrancy reduced to two libocrpc processes.
executable('reentrant-emit-call-gate',
  [
    'reentrant-emit-call-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Response then Invoke in one client read — bin buffer vs IOChannel IN.
executable('buffer-invoke-gate',
  [
    'buffer-invoke-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Response stranded in client bin buffer behind a coalesced Notification —
# call_poll polls only socket fd + IOChannel IN, never bin.get_available().
executable('poll-coalesced-reply-gate',
  [
    'poll-coalesced-reply-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Coalesced [Notification][Response] to a NESTED call_poll, server parked in
# hook.emit — the one-deep version of this passes.
executable('poll-nested-coalesced-reply-gate',
  [
    'poll-nested-coalesced-reply-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'LiveCallback.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Two Requests already on the socket when on_input_ready runs once
# (app-search 09:23 GestureAction.new / before-update / prefs_get_dynamic_workspaces).
executable('coalesced-nested-request-gate',
  [
    'coalesced-nested-request-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Nested call_poll from a Notification handler during outer call_poll
# (app-search 08:28 set_width / before-update / get_children).
executable('notif-nested-call-gate',
  [
    'notif-nested-call-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Live shape at volume: deep nesting + re-entrant emits + sync calls in invoke
# handlers + notifications mid-dispatch. Looks for a wedge the one-shot gates miss.
executable('nested-relay-storm-gate',
  [
    'nested-relay-storm-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'LiveCallback.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Nested Hook.emit on ONE callback id — inner reply must not release the outer.
executable('same-hook-reentrant-emit-gate',
  [
    'same-hook-reentrant-emit-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'LiveCallback.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Burst of Notifications ahead of the Invoke — client must drain its bin
# buffer, not one message per readable event (server blocked in hook.emit).
executable('poll-burst-strand-gate',
  [
    'poll-burst-strand-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Gi get_property omit GValue — must not CRITICAL via Value(Type.INVALID).
executable('gvalue-omit-gate',
  [
    'gvalue-omit-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [
    ocrpc_dep,
    dependency('gio-unix-2.0'),
    dependency('gobject-introspection-1.0'),
  ],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Capital-V Value (OPC type+data wrap) — FAIL until OLLMchat lands V.
executable('value-v-gate',
  [
    'value-v-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# GValue* IN: append held Value to args (not ay memcpy of GValue struct).
executable('gvalue-in-gate',
  [
    'gvalue-in-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [
    ocrpc_dep,
    dependency('gio-unix-2.0'),
    dependency('gobject-introspection-1.0'),
  ],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Clutter.Interval.set_final_value(GValue*) over Gi — external prove for set_to.
executable('clutter-interval-gvalue-gate',
  [
    'clutter-interval-gvalue-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [
    ocrpc_dep,
    dependency('gio-unix-2.0'),
    dependency('gobject-introspection-1.0'),
    dependency('mutter-clutter-16'),
  ],
  vala_args: ocrpc_vala_args + [
    '--pkg=mutter-clutter-16',
    '--vapidir', meson.project_build_root() / 'vapi',
  ],
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath + ':/usr/lib/x86_64-linux-gnu/mutter-16',
  install: false,
)

# Live decode must reuse Client.proxies (object identity).
executable('proxy-reuse-gate',
  [
    'proxy-reuse-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Live.Hook.emit GObject "o" must decode on the client (get_object).
executable('hook-o-gate',
  [
    'hook-o-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Ffi add_class "o" must resolve wire lease uint64 (like Gi).
executable('ffi-o-lease-gate',
  [
    'ffi-o-lease-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# measure_event tiddu (not typo tiidu) coords stay double across bin.
executable('event-tiidu-gate',
  'event-tiidu-gate.vala',
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

# Ffi "as" vs "S" for Vala length-bearing string[] (spawnv argv).
executable('ffi-as-string-array-gate',
  [
    'ffi-as-string-array-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# call_poll must deliver Live.Buffer fd on reply (spawnv stdout).
executable('call-poll-buffer-fd-gate',
  [
    'call-poll-buffer-fd-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args + ['--pkg=posix'],
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# call_poll cannot send Live.Buffer with Request (ImageContent.set_data).
executable('request-buffer-gate',
  [
    'request-buffer-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args + ['--pkg=posix'],
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Named GObject signal args must appear on Notification (before-update / stopped).
executable('subscribe-signal-args-gate',
  [
    'subscribe-signal-args-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# notify:: must put the typed property value on Notification.args.
executable('subscribe-notify-args-gate',
  [
    'subscribe-notify-args-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Named-signal boxed arg that is not GLib.Bytes (ClutterFrame analog).
executable('subscribe-boxed-signal-arg-gate',
  [
    'subscribe-boxed-signal-arg-gate.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# IconTheme.get_icon_sizes — Bytes/ay int32 slab (not Variant ai).
executable('icon-sizes-ay-gate',
  ['icon-sizes-ay-gate.vala'],
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

