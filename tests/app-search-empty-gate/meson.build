ocrpc_for_test = ocrpc_libdir != '' ? ocrpc_libdir : ''

test(
  'app-search-empty-gate',
  find_program('sh'),
  args: [
    files('check.sh'),
    meson.project_build_root() / 'src',
    mutter_typelib_dir,
    meson.project_build_root() / 'src' / 'Shell-@0@.injected.gir'.format(mutter_api_version),
    meson.project_build_root() / 'src' / 'Shell-@0@.gir'.format(mutter_api_version),
    files('check.js'),
    ocrpc_for_test,
    shell_app_info_type,
  ],
  depends: [shell_gi_typelib, clutter_rpc_typelib, st_rpc_typelib],
)
