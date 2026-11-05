meta_rpc_build_dir = meson.current_build_dir()

meta_deny_file = files('Meta.deny')
meta_overrides_file = files('Meta.overrides')
meta_override_dir = meson.current_source_dir() / 'overrides'
meta_override_files = files(
  'overrides/SoundPlayer.override.vala',
  'overrides/Background.override.vala',
  'overrides/BackgroundActor.override.vala',
  'overrides/BackgroundContent.override.vala',
  'overrides/BackgroundImageCache.override.vala',
  'overrides/Context.override.vala',
  'overrides/Backend.override.vala',
  'overrides/Settings.override.vala',
  'overrides/IdleMonitor.override.vala',
  'overrides/Laters.override.vala',
  'overrides/Workspace.override.vala',
  'overrides/WorkspaceManager.override.vala',
  'overrides/Display.override.vala',
  'overrides/Meta.override.vala',
  'overrides/WindowActor.override.vala',
  'overrides/Selection.override.vala',
  'overrides/SelectionSource.override.vala',
  'overrides/SelectionSourceMemory.override.vala',
  'overrides/ShapedTexture.override.vala',
  'overrides/WaylandCompositor.override.vala',
  'overrides/Compositor.override.vala',
)
if mutter_api_version == '18'
  meta_override_files += files(
    '../libmutter-rpc-18/overrides/Window.override.vala',
    '../libmutter-rpc-18/overrides/WaylandClient.override.vala',
    '../libmutter-rpc-18/overrides/Backend.override.vala',
    '../libmutter-rpc-18/overrides/IdleMonitor.override.vala',
    '../libmutter-rpc-18/overrides/KeymapDescription.override.vala',
  )
  meta_deny_file = files('../libmutter-rpc-18/Meta.deny')
  meta_override_dir = meson.current_source_dir() / '../libmutter-rpc-18/overrides' + ':' + meta_override_dir
else
  meta_override_files += files(
    'overrides/Window.override.vala',
    'overrides/WaylandClient.override.vala',
  )
endif

meta_window_generated = custom_target('Meta_window_generated.vala',
  output: 'Meta_window_generated.vala',
  command: [
    gi_stub_gen,
    '--out=@OUTPUT@',
    '--missing-out=' + meson.current_build_dir() / 'Meta_window_generated.missing.md',
    '--typelib-dir=' + mutter_typelib_dir,
    '--deny-file=@INPUT0@',
    '--overrides-file=@INPUT1@',
    '--override-path=' + meta_override_dir,
    'emit', 'Meta', mutter_api_version,
  ],
  input: [meta_deny_file, meta_overrides_file] + meta_override_files,
  depends: [gi_stub_gen],
  build_by_default: true,
)

# Client Meta stubs (RPC); Clutter + Runtime + Shared/Ui wire types are in clutter-rpc.
# c-meta-shell-gaps includes stock meta/*.h → needs stock clutter/ on -I, and must
# NOT see -include mutter-clutter-rpc-16.h (Vala) or generated clutter-include.
gsr_meta_shell_gaps = static_library(
  'gsr-meta-shell-gaps',
  'c-meta-shell-gaps.c',
  c_args: [
    '-I' + mutter_includedir,
  ] + mutter_clutter_stock_inc + mutter_clutter_dep_cflags,
  dependencies: [
    dependency('glib-2.0'),
    dependency('x11'),
  ],
)

mutter_rpc_lib = shared_library('mutter-rpc-' + mutter_api_version,
  files(
    'namespace.vala',
    'PaintedContent.vala',
    'RpcSubprocess.vala',
    'c-gio-subprocess-launcher-cwd.c',
    'c-closure-ref.c',
    'key-binding-wire.c',
  ),
  meta_window_generated,
  dependencies: [
    mutter_vapi_dep,
    ocrpc_dep,
    mutter_clutter_rpc_link_dep,
    dependency('gio-2.0'),
    dependency('cairo'),
    dependency('atk'),
    dependency('pango'),
    dependency('graphene-gobject-1.0'),
    dependency('mutter-cogl-' + mutter_api_version),
    dependency('mutter-mtk-' + mutter_api_version),
    dependency('x11'),
  ],
  link_whole: gsr_meta_shell_gaps,
  vala_args: ocrpc_vala_args + [
    '--pkg=posix',
    '--pkg=gdesktopenums-3.0',
    '--pkg=atk',
    '--pkg=pango',
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--vapidir', meson.current_source_dir() / '../libmutter-clutter-rpc-16',
    '--pkg=gsr-clutter-effect-abi',
    '--pkg=gsr-rpc-16',
    '--pkg=gsr-rpc-shared',
    # mutter_clutter_rpc_link_dep supplies mutter-clutter-rpc-16.vapi; --pkg duplicates it.
    '--vapidir', gsr_rpc_build_dir,
    '--vapidir', clutter_rpc_build_dir,
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + mutter_includedir,
    '-I' + gsr_rpc_build_dir,
    '-I' + clutter_rpc_build_dir,
    '-I' + meson.current_source_dir() / '../libmutter-clutter-rpc-16',
    # Vala Clutter types for Meta .c — not the generated clutter-include tree.
    '-include', 'mutter-clutter-rpc-' + mutter_api_version + '.h',
  ] + mutter_clutter_cflags,
  build_rpath: ocrpc_rpath + ':' + gsr_rpc_build_dir + ':' + clutter_rpc_build_dir,
  link_args: ['-L' + mutter_typelib_dir],
  vala_header: 'mutter-rpc-' + mutter_api_version + '.h',
  vala_vapi: 'mutter-rpc-' + mutter_api_version + '.vapi',
  install: true,
  install_rpath: mutter_typelib_dir,
)
