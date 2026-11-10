st_rpc_build_dir = meson.current_build_dir()

st_deny_file = files('St.deny')
st_overrides_file = files('St.overrides')
st_batch_whitelist = files('batch.whitelist')
st_override_dir = meson.current_source_dir() / 'overrides'
st_generated = custom_target('St_generated.vala',
  output: 'St_generated.vala',
  command: [
    gi_stub_gen,
    '--out=@OUTPUT@',
    '--missing-out=' + meson.current_build_dir() / 'St_generated.missing.md',
    '--typelib-dir=' + gnome_shell_pkglibdir + ':' + mutter_typelib_dir,
    '--deny-file=@INPUT0@',
    '--batch-file=' + meson.current_source_dir() / 'batch.whitelist',
    '--overrides-file=@INPUT1@',
    '--override-path=' + st_override_dir,
    'emit', 'St', mutter_api_version,
  ],
  input: [st_deny_file, st_overrides_file, st_batch_whitelist] + files(
    'overrides/Theme.override.vala',
    'overrides/ThemeContext.override.vala',
    'overrides/ThemeNode.override.vala',
    'overrides/Adjustment.override.vala',
    'overrides/Icon.override.vala',
    'overrides/IconInfo.override.vala',
    'overrides/IconTheme.override.vala',
    'overrides/ImageContent.override.vala',
    'overrides/SpinnerContent.override.vala',
    'overrides/Widget.override.vala',
    'overrides/FocusManager.override.vala',
    'overrides/Settings.override.vala',
    'overrides/Viewport.override.vala',
    'overrides/ScrollView.override.vala',
    'overrides/GenericAccessible.override.vala',
    'overrides/Entry.override.vala',
    'overrides/DrawingArea.override.vala',
    'overrides/Clipboard.override.vala',
    'overrides/DndStartGesture.override.vala',
    'overrides/ScrollViewFade.override.vala',
  ),
  depends: [gi_stub_gen],
  build_by_default: true,
)
st_boxed = custom_target('St_boxed.vala',
  input: st_generated,
  output: 'St_boxed.vala',
  command: [
    'cp',
    meson.current_build_dir() / 'St_generated_boxed.vala',
    '@OUTPUT@',
  ],
  build_by_default: true,
)

st_rpc_gir_name = 'st-rpc-' + mutter_api_version
st_rpc_lib = shared_library(
  'st-rpc-' + mutter_api_version,
  st_generated,
  files('namespace.vala'),
  dependencies: [
    mutter_vapi_dep,
    ocrpc_dep,
    mutter_clutter_rpc_link_dep,
    dependency('gio-2.0'),
    dependency('gdk-pixbuf-2.0'),
    dependency('cairo'),
    dependency('graphene-gobject-1.0'),
    dependency('mutter-cogl-' + mutter_api_version),
    dependency('mutter-mtk-' + mutter_api_version),
  ],
  vala_args: ocrpc_vala_args + [
    '--pkg=posix',
    '--pkg=linux',
    '--pkg=gdk-pixbuf-2.0',
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--pkg=gsr-rpc-16',
    '--pkg=gsr-rpc-shared',
    '--pkg=mutter-clutter-rpc-' + mutter_api_version,
    '--vapidir', meson.current_source_dir() / '../libmutter-clutter-rpc-16',
    '--pkg=gsr-clutter-effect-abi',
    '--vapidir', gsr_rpc_build_dir,
    '--vapidir', clutter_rpc_build_dir,
    '--vapidir', meta_rpc_build_dir,
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + gsr_rpc_build_dir,
    '-I' + clutter_rpc_build_dir,
    '-I' + meson.current_source_dir() / '../libmutter-clutter-rpc-16',
    '-include', 'mutter-clutter-rpc-' + mutter_api_version + '.h',
  ],
  link_args: ['-L' + meta_rpc_build_dir, '-lmutter-rpc-' + mutter_api_version],
  link_depends: [mutter_clutter_rpc_lib, mutter_rpc_lib],
  build_rpath: ocrpc_rpath + ':' + gsr_rpc_build_dir + ':' + clutter_rpc_build_dir + ':' + meta_rpc_build_dir,
  vala_header: 'st-rpc-' + mutter_api_version + '.h',
  vala_vapi: 'st-rpc-' + mutter_api_version + '.vapi',
  install: true,
  install_rpath: mutter_typelib_dir,
)

# Same split as the Clutter boxed library: St records stay out of the
# Shell GIR compilation. The server has no St vapi, so it does not
# link this.
# St.DrawingArea.rpc_construct overrides Clutter.Actor. libmutter-16.deps
# loads system mutter-clutter-16, a second Clutter namespace, so this
# target uses mutter-clutter-rpc-16 and gsr-rpc-16.
# Absolute path so this namespace.c does not land on the Clutter boxed one.
gsr_st_boxed_lib = static_library(
  'gsr-st-boxed',
  files(meson.project_source_root() / 'src' / 'boxed' / 'namespace.vala'),
  st_boxed,
  dependencies: [
    ocrpc_dep,
    dependency('gee-0.8'),
    dependency('graphene-gobject-1.0'),
    dependency('gdk-pixbuf-2.0'),
    dependency('mutter-mtk-' + mutter_api_version),
    dependency('mutter-cogl-' + mutter_api_version),
    dependency('gio-2.0'),
    dependency('gobject-2.0'),
    dependency('glib-2.0'),
    dependency('atk'),
    dependency('pango'),
    dependency('cairo'),
    dependency('x11'),
    dependency('json-glib-1.0'),
  ],
  link_with: st_rpc_lib,
  vala_args: ocrpc_vala_args + [
    '--pkg=mutter-clutter-rpc-' + mutter_api_version,
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    girepository_pkg,
    '--pkg=xfixes-4.0',
    '--pkg=gdesktopenums-3.0',
    '--pkg=posix',
    '--pkg=gee-0.8',
    '--pkg=graphene-gobject-1.0',
    '--pkg=gsr-rpc-16',
    '--pkg=gsr-rpc-shared',
    '--pkg=st-rpc-' + mutter_api_version,
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
    '--vapidir', meson.current_build_dir(),
    '--vapidir', gsr_rpc_build_dir,
    '--vapidir', clutter_rpc_build_dir,
    '--vapidir', meson.current_source_dir() / '../libmutter-clutter-rpc-16',
  ],
  c_args: [
    '-I' + gsr_rpc_build_dir,
    '-I' + clutter_rpc_build_dir,
    '-I' + meson.current_source_dir() / '../libmutter-clutter-rpc-16',
    '-include', 'mutter-clutter-rpc-' + mutter_api_version + '.h',
  ],
  vala_header: 'gsr-st-boxed.h',
  vala_vapi: 'gsr-st-boxed.vapi',
)

mutter_rpc_client_dep = declare_dependency(
  link_with: [mutter_rpc_lib, st_rpc_lib],
  dependencies: [
    mutter_clutter_rpc_client_dep,
    dependency('mutter-mtk-' + mutter_api_version),
    dependency('mutter-cogl-' + mutter_api_version),
    dependency('atk'),
    dependency('pango'),
  ],
  compile_args: ['-I' + mutter_includedir],
)
