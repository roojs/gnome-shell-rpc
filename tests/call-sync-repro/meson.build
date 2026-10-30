executable('call-sync-repro',
  'repro.vala',
  dependencies: [dependency('gio-2.0')],
  install: false,
)

# Two pipes model clicked -> sync request -> blocking callback +
# before-update -> response. Modes exercise the signal-ordering options.
signal_reentrancy_gate = executable('signal-reentrancy-gate',
  'signal-reentrancy-gate.vala',
  dependencies: [dependency('gio-unix-2.0')],
  vala_args: ['--pkg=posix'],
  install: false,
)

# Real libocrpc gate: post-call_poll Live.Invoke + idle MainContext only.
after_reply_gate = executable('after-reply-gate',
  [
    'after-reply-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
reentrant_emit_call_gate = executable('reentrant-emit-call-gate',
  [
    'reentrant-emit-call-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# A server emit inside an outer call_poll requires a depth-two callback reply.
outer_emit_reply_gate = executable('outer-emit-reply-gate',
  [
    'outer-emit-reply-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'LiveCallback.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# A blocking void GObject signal must carry a reply id and keep the server
# inside the emission until the client replies. This guards the libocrpc fix
# for the null GClosure return_value used by void signals.
blocking_void_signal_gate = executable('blocking-void-signal-gate',
  [
    'blocking-void-signal-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'LiveCallback.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

test(
  'blocking-void-signal',
  blocking_void_signal_gate,
  timeout: 5,
)

# Response then Invoke in one client read — bin buffer vs IOChannel IN.
buffer_invoke_gate = executable('buffer-invoke-gate',
  [
    'buffer-invoke-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'LiveCallback.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
notif_nested_call_gate = executable('notif-nested-call-gate',
  [
    'notif-nested-call-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
nested_relay_storm_gate = executable('nested-relay-storm-gate',
  [
    'nested-relay-storm-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'LiveCallback.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Nested Hook.emit on ONE callback id — inner reply must not release the outer.
same_hook_reentrant_emit_gate = executable('same-hook-reentrant-emit-gate',
  [
    'same-hook-reentrant-emit-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'LiveCallback.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

test(
  'signal-reentrancy-current',
  signal_reentrancy_gate,
  args: ['current'],
  should_fail: true,
  suite: 'signal-reentrancy',
  timeout: 5,
)

foreach mode : [
  'later-depth',
  'later-reentry',
  'signal-queue',
  'transport-queue',
  'server-delay',
  'stack-bool',
  'stack-void',
  'stack',
  'server-bool',
  'server-void',
  'server',
  'proposal-after',
  'emit-queue',
  'event',
  'event-scope',
  'event-reschedule',
]
  test(
    'signal-reentrancy-' + mode,
    signal_reentrancy_gate,
    args: [mode],
    suite: 'signal-reentrancy',
    timeout: 5,
  )
endforeach

foreach mode : [
  'stack-eager',
  'stack-defer',
  'proposal-during',
  'proposal-noreply',
  'call-hold',
  'later-skip',
  'press-gap',
  'server-gap',
  'event-no-click',
]
  test(
    'signal-reentrancy-' + mode,
    signal_reentrancy_gate,
    args: [mode],
    should_fail: true,
    suite: 'signal-reentrancy',
    timeout: 5,
  )
endforeach

test(
  'signal-reentrancy-after-reply',
  after_reply_gate,
  suite: 'signal-reentrancy',
  timeout: 10,
)

test(
  'signal-reentrancy-buffer-invoke',
  buffer_invoke_gate,
  suite: 'signal-reentrancy',
  timeout: 10,
)

test(
  'signal-reentrancy-reentrant-emit-call',
  reentrant_emit_call_gate,
  suite: 'signal-reentrancy',
  timeout: 10,
)

test(
  'signal-reentrancy-outer-emit-reply',
  outer_emit_reply_gate,
  suite: 'signal-reentrancy',
  timeout: 10,
)

test(
  'signal-reentrancy-notif-nested-call',
  notif_nested_call_gate,
  suite: 'signal-reentrancy',
  timeout: 10,
)

test(
  'signal-reentrancy-same-hook-reentrant-emit',
  same_hook_reentrant_emit_gate,
  suite: 'signal-reentrancy',
  timeout: 20,
)

test(
  'signal-reentrancy-nested-relay-storm',
  nested_relay_storm_gate,
  suite: 'signal-reentrancy',
  timeout: 30,
)

# Burst of Notifications ahead of the Invoke — client must drain its bin
# buffer, not one message per readable event (server blocked in hook.emit).
executable('poll-burst-strand-gate',
  [
    'poll-burst-strand-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [
    mutter_vapi_dep,
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# val("o") stamps the runtime type. An unregistered private subclass must
# still cross as its nearest registered parent.
executable('runtime-parent-schema-gate',
  [
    'runtime-parent-schema-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# A live private subclass must cross as the registered public type declared
# by its GValue (Clutter.Actor return holding MetaSurfaceActorWayland).
executable('declared-object-type-gate',
  [
    'declared-object-type-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# get_effect of a leaf registered as Shell-BlurEffect. Client has no such alias.
executable('shell-blur-alias-gate',
  [
    'shell-blur-alias-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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

# Headless stage: a reactive child gets press and release, including
# under a stage grab.
executable('button-release-deliver-gate',
  'button-release-deliver-gate.c',
  dependencies: [libmutter_dep],
  install: false,
)

# Crash-screen Log Out text: hover does not change the cursor sprite,
# and the click may miss. src/ stays unchanged.
executable('logout-text-pointer-gate',
  'logout-text-pointer-gate.c',
  dependencies: [libmutter_dep],
  install: false,
)

# StWidget is rejected by StScrollView.set_child. A StViewport subclass
# is accepted and its allocate sees the scroll box. src/ stays unchanged.
executable('viewport-scrollable-peer-gate',
  'viewport-scrollable-peer-gate.c',
  dependencies: [libmutter_dep],
  include_directories: include_directories('../../vendor/gnome-shell/src'),
  c_args: ['-DST_COMPILATION'],
  link_args: gnome_shell_st_link_args + ['-Wl,-rpath,' + gnome_shell_pkglibdir],
  install: false,
)

# Stock Clutter must finish both ClickAction handlers before a frame scheduled
# by long-press cancellation reaches before-update.
clutter_event_frame_order_gate = executable(
  'clutter-event-frame-order-gate',
  'clutter-event-frame-order-gate.c',
  dependencies: [libmutter_dep],
  install: false,
)

test(
  'signal-reentrancy-clutter-event-frame-order',
  clutter_event_frame_order_gate,
  suite: 'signal-reentrancy',
  timeout: 20,
)

# Drag cancel on a batched leave has no current event. Same failure as the
# Weston and guest thumbnail drag. should_fail until a fix passes it.
clutter_drag_leave_gate = executable(
  'clutter-drag-leave-gate',
  'clutter-drag-leave-gate.c',
  dependencies: [libmutter_dep],
  install: false,
)

test(
  'signal-reentrancy-clutter-drag-leave',
  clutter_drag_leave_gate,
  suite: 'signal-reentrancy',
  timeout: 20,
)

# Unset boolean return must not stop a true-handled signal chain.
executable('button-release-chain-gate',
  [
    'button-release-chain-gate.vala',
    'button-release-chain-signal.c',
  ],
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

# Null GObject in Notification.args must round-trip (calendar close).
executable('null-object-arg-gate',
  'null-object-arg-gate.vala',
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

# Ffi "as" vs "S" for Vala length-bearing string[] (spawnv argv).
executable('ffi-as-string-array-gate',
  [
    'ffi-as-string-array-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Named signal with a GObject arg never exported on this connection
# (mutter window-added during Meta.Window construction).
executable('subscribe-unexported-object-arg-gate',
  [
    'subscribe-unexported-object-arg-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# Live.Hook.emit on a stopped connection must return (client gone,
# Clutter vfunc trampoline still fires).
executable('hook-emit-after-stop-gate',
  ['hook-emit-after-stop-gate.vala'],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

# notify:: must put the typed property value on Notification.args.
executable('subscribe-notify-args-gate',
  [
    'subscribe-notify-args-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
  ],
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args,
  c_args: ['-rdynamic'],
  link_args: ['-rdynamic'],
  build_rpath: ocrpc_rpath,
  install: false,
)

# A notify applied to a Live proxy must not invoke its outbound RPC setter.
# FAIL until libocrpc has a side-effect-free mirror-update path.
executable('notify-proxy-setter-echo-gate',
  [
    'notify-proxy-setter-echo-gate.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Daemon.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Listen.vala',
    meson.project_source_root() / 'src' / 'server' / 'rpc' / 'Connection.vala',
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

# Public GObject classes implementing Live.Interface must remain constructible
# through GI. Current libocrpc VAPI leaks an unresolved OLLMrpc interface into
# the consumer GIR; GJS follows it and crashes in g_interface_info_find_method.
live_interface_gir_fixture = shared_library(
  'live-interface-gir-gate-1.0',
  'live-interface-gir-gate.vala',
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  vala_gir: 'LiveInterfaceGirGate-1.0.gir',
  build_rpath: ocrpc_rpath,
  install: false,
)

live_interface_gir_typelib = custom_target(
  'LiveInterfaceGirGate-1.0.typelib',
  output: 'LiveInterfaceGirGate-1.0.typelib',
  command: [
    find_program('g-ir-compiler'),
    '--output', '@OUTPUT@',
    '--shared-library', 'liblive-interface-gir-gate-1.0.so',
    meson.current_build_dir() / 'LiveInterfaceGirGate-1.0.gir',
  ],
  depends: live_interface_gir_fixture,
  build_by_default: true,
)

test(
  'live-interface-gir-gate',
  find_program('gjs'),
  args: files('live-interface-gir-gate.js'),
  env: [
    'GI_TYPELIB_PATH=' + meson.current_build_dir(),
    'LD_LIBRARY_PATH=' + meson.current_build_dir(),
  ],
  depends: [live_interface_gir_fixture, live_interface_gir_typelib],
)

# Meta.Laters stores a GLib.SourceFunc and calls it from before-update.
# This holder does only that store-and-call, after GJS has disposed the
# bound object. A crash here is the callback lifetime, not the shell.
later_callback_hold_fixture = shared_library(
  'later-callback-hold-1.0',
  'later-callback-hold.vala',
  'later-callback-hold-fix.c',
  dependencies: [dependency('gobject-2.0')],
  vala_gir: 'LaterCallbackHold-1.0.gir',
  install: false,
)

later_callback_hold_typelib = custom_target(
  'LaterCallbackHold-1.0.typelib',
  output: 'LaterCallbackHold-1.0.typelib',
  command: [
    find_program('g-ir-compiler'),
    '--output', '@OUTPUT@',
    '--shared-library', 'liblater-callback-hold-1.0.so',
    meson.current_build_dir() / 'LaterCallbackHold-1.0.gir',
  ],
  depends: later_callback_hold_fixture,
  build_by_default: true,
)

test(
  'later-callback-hold',
  find_program('gjs'),
  args: files('later-callback-hold.js'),
  env: [
    'GI_TYPELIB_PATH=' + meson.current_build_dir(),
    'LD_LIBRARY_PATH=' + meson.current_build_dir(),
  ],
  depends: [later_callback_hold_fixture, later_callback_hold_typelib],
)

# Shell.PolkitAuthenticationAgent.initiate. length is the Vala default
# (GStrv + int). GJS aborts. strv registers five parameters ending in
# G_TYPE_STRV from polkit-initiate-shape-strv.c.
polkit_initiate_shape_fixture = shared_library(
  'polkit-initiate-shape-1.0',
  'polkit-initiate-shape.vala',
  'polkit-initiate-shape-strv.c',
  dependencies: [dependency('gobject-2.0')],
  vala_gir: 'PolkitInitiateShape-1.0.gir',
  install: false,
)

polkit_initiate_shape_gir = custom_target(
  'PolkitInitiateShape-1.0.injected.gir',
  output: 'PolkitInitiateShape-1.0.injected.gir',
  command: [
    find_program('xsltproc'),
    '--nonet', '--novalid',
    '--output', '@OUTPUT@',
    files('polkit-initiate-shape-inject.xsl'),
    meson.current_build_dir() / 'PolkitInitiateShape-1.0.gir',
  ],
  depends: polkit_initiate_shape_fixture,
  build_by_default: true,
)

polkit_initiate_shape_typelib = custom_target(
  'PolkitInitiateShape-1.0.typelib',
  output: 'PolkitInitiateShape-1.0.typelib',
  command: [
    find_program('g-ir-compiler'),
    '--output', '@OUTPUT@',
    '--shared-library', 'libpolkit-initiate-shape-1.0.so',
    meson.current_build_dir() / 'PolkitInitiateShape-1.0.injected.gir',
  ],
  depends: polkit_initiate_shape_gir,
  build_by_default: true,
)

test(
  'polkit-initiate-shape-length',
  find_program('gjs'),
  args: [files('polkit-initiate-shape.js'), 'length'],
  env: [
    'GI_TYPELIB_PATH=' + meson.current_build_dir(),
    'LD_LIBRARY_PATH=' + meson.current_build_dir(),
  ],
  depends: [polkit_initiate_shape_fixture, polkit_initiate_shape_typelib],
  should_fail: true,
  timeout: 5,
)

test(
  'polkit-initiate-shape-strv',
  find_program('gjs'),
  args: [files('polkit-initiate-shape.js'), 'strv'],
  env: [
    'GI_TYPELIB_PATH=' + meson.current_build_dir(),
    'LD_LIBRARY_PATH=' + meson.current_build_dir(),
  ],
  depends: [polkit_initiate_shape_fixture, polkit_initiate_shape_typelib],
  timeout: 5,
)

# finish() writes the request after finished(). The handler drops the
# only other ref. bad is the use-after-free. held keeps the instance.
polkit_request_finish_hold = executable(
  'polkit-request-finish-hold',
  'polkit-request-finish-hold.vala',
  dependencies: [dependency('gobject-2.0')],
  c_args: ['-fsanitize=address', '-fno-omit-frame-pointer'],
  link_args: ['-fsanitize=address'],
  install: false,
)

test(
  'polkit-request-finish-bad',
  polkit_request_finish_hold,
  args: ['bad'],
  should_fail: true,
  timeout: 5,
)

test(
  'polkit-request-finish-held',
  polkit_request_finish_hold,
  args: ['held'],
  timeout: 5,
)

# Nested Later.add: the inner add runs before the outer add returns.
# GJS 1.82 CallbackIn::release then unrefs the inner trampoline.
test(
  'later-callback-nested-add',
  find_program('gjs'),
  args: files('later-callback-nested-add.js'),
  env: [
    'GI_TYPELIB_PATH=' + meson.current_build_dir(),
    'LD_LIBRARY_PATH=' + meson.current_build_dir(),
  ],
  depends: [later_callback_hold_fixture, later_callback_hold_typelib],
)

# 250ms scale removed while the handler is still open. current is the
# RPC split (clock runs in the quiet gap). in-process is the control.
scale_gap_gate = executable('scale-gap-gate',
  'scale-gap-gate.vala',
  dependencies: [dependency('gio-unix-2.0')],
  vala_args: ['--pkg=posix'],
  install: false,
)

test(
  'scale-gap-current',
  scale_gap_gate,
  args: ['current'],
  should_fail: true,
  timeout: 5,
)

foreach mode : ['in-process', 'pause-on-ease', 'pause-plain', 'pause-on-get', 'start-on-frame']
  test(
    'scale-gap-' + mode,
    scale_gap_gate,
    args: [mode],
    timeout: 5,
  )
endforeach

foreach mode : ['ease-gap', 'frame-plain', 'start-on-stopped', 'hold-until-click', 'inhibit-drag']
  test(
    'scale-gap-' + mode,
    scale_gap_gate,
    args: [mode],
    should_fail: true,
    timeout: 5,
  )
endforeach

# Show then opacity in one client turn. current paints in the quiet gap.
# poll presents only after a quiet longer than the in-turn gap.
# poll-short expires during that gap and still paints opacity 255.
startup_paint_gap_gate = executable('startup-paint-gap-gate',
  'startup-paint-gap-gate.vala',
  dependencies: [dependency('gio-unix-2.0')],
  vala_args: ['--pkg=posix'],
  install: false,
)

test(
  'startup-paint-gap-current',
  startup_paint_gap_gate,
  args: ['current'],
  should_fail: true,
  timeout: 5,
)

foreach mode : ['in-process', 'hold-turn', 'poll', 'flow-idle', 'main-poll', 'poll-wake', 'overview-hold']
  test(
    'startup-paint-gap-' + mode,
    startup_paint_gap_gate,
    args: [mode],
    timeout: 5,
  )
endforeach

test(
  'startup-paint-gap-poll-short',
  startup_paint_gap_gate,
  args: ['poll-short'],
  should_fail: true,
  timeout: 5,
)

# Nested poke: one callback removes itself and runs the queue again, which
# calls the next SourceFunc. Then the JS wrapper is dropped and poke runs.
test(
  'later-callback-reenter',
  find_program('gjs'),
  args: files('later-callback-reenter.js'),
  env: [
    'GI_TYPELIB_PATH=' + meson.current_build_dir(),
    'LD_LIBRARY_PATH=' + meson.current_build_dir(),
  ],
  depends: [later_callback_hold_fixture, later_callback_hold_typelib],
)

