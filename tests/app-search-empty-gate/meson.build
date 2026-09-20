ocrpc_for_test = ocrpc_libdir != '' ? ocrpc_libdir : ''

test(
  'app-search-empty-gate',
  find_program('sh'),
  args: [
    files('check.sh'),
    meson.project_build_root() / 'src',
    mutter_typelib_dir,
    meson.project_build_root() / 'src' / 'Shell-16.injected.gir',
    meson.project_build_root() / 'src' / 'Shell-16.gir',
    files('check.js'),
    ocrpc_for_test,
  ],
  depends: [shell_gi_typelib, clutter_rpc_typelib, st_rpc_typelib],
)
