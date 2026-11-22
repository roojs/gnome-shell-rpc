live_panel_cube_stop_a = executable(
  'live-panel-cube-stop-a',
  'live-panel-cube-stop-a.vala',
  dependencies: [ocrpc_dep, dependency('gio-unix-2.0')],
  vala_args: ocrpc_vala_args + ['--pkg=posix'],
  build_rpath: ocrpc_rpath,
  install: false,
)