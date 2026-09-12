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
