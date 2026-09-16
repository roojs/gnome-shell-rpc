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

