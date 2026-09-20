ocrpc_for_test = ocrpc_libdir != '' ? ocrpc_libdir : ''

test(
  'class-struct-offset-gate',
  find_program('sh'),
  args: [
    files('check.sh'),
    meson.project_build_root() / 'src',
    mutter_typelib_dir,
    files('check.js'),
    ocrpc_for_test,
  ],
  depends: [clutter_rpc_typelib, st_rpc_typelib],
)
