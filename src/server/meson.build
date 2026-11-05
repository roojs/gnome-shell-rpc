# shared/namespace.vala is not in this target. Valac would name it namespace.c,
# the same as server/namespace.vala. gsr-shared is linked instead.
compositor_sources = files(
  meson.project_source_root() / 'src' / 'ApplicationInterface.vala',
  'Main.vala',
  'Plugin.vala',
  'rpc/Daemon.vala',
  'Bootstrap.vala',
  'rpc/LiveCallback.vala',
  'Cancellable.vala',
  'StartupFrameLock.vala',
  'OverviewPaintHold.vala',
  'namespace.vala',
  'rpc/namespace.vala',
  'rpc/Connection.vala',
  'rpc/Lease.vala',
  'rpc/Listen.vala',
  'rpc/Server.vala',
  'libmutter-16/namespace.vala',
  'libmutter-16/Compositor.vala',
  'libmutter-16/Keybinding.vala',
  'libmutter-16/WindowActor.vala',
  'libmutter-16/Context.vala',
  'libmutter-16/Settings.vala',
  'libmutter-16/IdleMonitor.vala',
  'libmutter-16/SoundPlayer.vala',
  'libmutter-16/Background.vala',
  'libmutter-16/BackgroundActor.vala',
  'libmutter-16/BackgroundImageCache.vala',
  'libmutter-16/Selection.vala',
  'libmutter-16/SelectionSource.vala',
  'libmutter-16/SelectionSourceMemory.vala',
  'libmutter-16/ShapedTexture.vala',
  'libmutter-16/Barrier.vala',
  'libmutter-16/BarrierEventOverride.vala',
  'libmutter-16/KeyBindingOverride.vala',
  'libmutter-16/AppLaunch.vala',
  'libmutter-clutter-18/ClutterActor.vala',
  'libmutter-clutter-18/Clutter.vala',
  'libmutter-clutter-18/ClutterThreads.vala',
  'libmutter-clutter-18/ClutterLayoutManager.vala',
  'libmutter-clutter-18/ClutterPaintContext.vala',
  'libmutter-clutter-18/Constraint.vala',
  'libmutter-clutter-18/Interval.vala',
  'libmutter-clutter-18/Text.vala',
  'libmutter-clutter-18/ShaderEffect.vala',
  'libmutter-clutter-18/Devices.vala',
  'libmutter-clutter-18/LayoutHooks.vala',
  'libmutter-clutter-18/ClutterEventOverride.vala',
  'libmutter-clutter-18/InputDeviceOverride.vala',
  'libmutter-clutter-18/PickContextOverride.vala',
  'libmutter-clutter-18/RegionOverride.vala',
  'libmutter-clutter-18/shader-uniform-apply.c',
  'libst-16/namespace.vala',
  'libst-16/BoxedTypeOverrides.vala',
  'libst-16/St.vala',
  'libst-16/ThemeContext.vala',
  'libst-16/ThemeNode.vala',
  'libst-16/Icon.vala',
  'libst-16/IconTheme.vala',
  'libst-16/ImageContent.vala',
  'libst-16/SpinnerContent.vala',
  'libst-16/DrawingArea.vala',
  'libst-16/DrawingAreaActor.vala',
  'libst-16/ViewportActor.vala',
  'libst-16/Viewport.vala',
  'libst-16/SquareBinActor.vala',
  'libst-16/FocusManager.vala',
  'libst-16/Clipboard.vala',
  'libshell-16/GLSLEffect.vala',
  'libshell-16/BlurEffect.vala',
  'libshell-16/InvertLightnessEffect.vala',
)

if mutter_api_version == '18'
  compositor_sources += files(
    'libmutter-18/SpawnClient.vala',
    'libmutter-18/Display.vala',
    'libmutter-18/Window.vala',
    'libmutter-18/WaylandClient.vala',
    'libmutter-18/Keymap.vala',
    'libst-16/DndStart.vala',
    'libmutter-18/IdleWatch.vala',
    'libmutter-clutter-18/namespace.vala',
    'libmutter-clutter-18/ClutterStage.vala',
    'libmutter-clutter-18/ClickGesture.vala',
    'libmutter-clutter-18/PressGesture.vala',
    'libmutter-clutter-18/PanGesture.vala',
    'libmutter-clutter-18/LongPressGesture.vala',
    'libmutter-clutter-18/Backend.vala',
    'libshell-18/namespace.vala',
    'libshell-18/EdgeDragGesture.vala',
  )
else
  compositor_sources += files(
    'libshell-16/namespace.vala',
    'rpc/SpawnClient.vala',
    'libmutter-16/Display.vala',
    'libmutter-16/Window.vala',
    'libmutter-16/WaylandClient.vala',
    'libmutter-clutter-16/namespace.vala',
    'libmutter-clutter-16/ClutterStage.vala',
    'libmutter-clutter-16/ClutterGestureAction.vala',
  )
endif

rpc_gdb_spawn = get_option('rpc_gdb_spawn')
if rpc_gdb_spawn
  compositor_sources += files('GdbSpawnWrap.vala')
endif

rpc_config = configure_file(
  input: 'Config.vala.in',
  output: 'Config.vala',
  configuration: configuration_data({
    'MUTTER_TYPELIB_DIR': mutter_typelib_dir,
    'MUTTER_API_VERSION': mutter_api_version,
    'GNOME_SHELL_CLIENT_TYPELIB_DIR': gnome_shell_client_typelibdir,
    'GNOME_SHELL_PKGLIBDIR': gnome_shell_pkglibdir,
  }),
)

compositor_rpath = mutter_typelib_dir + ':' + gnome_shell_pkglibdir
if ocrpc_rpath != ''
  compositor_rpath += ':' + ocrpc_rpath
endif

mutter_rpc_vala_args = mutter_vala_args + ocrpc_vala_args + [
  '--pkg=st-widget-peer',
]
if rpc_gdb_spawn
  mutter_rpc_vala_args += '--define=GSR_GDB_SPAWN'
endif

mutter_rpc = executable('gsr-server',
  compositor_sources,
  clutter_helper_vfunc_ids,
  files(meson.project_source_root() / 'vapi' / 'gsr-clutter-event-key.c'),
  rpc_config,
  dependencies: [
    mutter_vapi_dep,
    mutter_dep,
    ocrpc_dep,
    girepository_dep,
    dependency('gee-0.8'),
    dependency('cairo'),
    dependency('graphene-gobject-1.0'),
  ],
  link_with: [gsr_clutter_boxed_lib, gsr_shared_lib],
  vala_args: mutter_rpc_vala_args + [
    '--pkg=gee-0.8',
    '--pkg=cairo',
    '--pkg=graphene-gobject-1.0',
    '--pkg=gsr-clutter-boxed',
    '--pkg=gsr-shared',
    '--vapidir', clutter_rpc_build_dir,
    '--vapidir', meson.project_build_root() / 'src',
  ],
  c_args: [
    '-I' + meson.project_source_root() / 'vapi',
    '-I' + clutter_rpc_build_dir,
    '-I' + meson.project_build_root() / 'src',
  ],
  link_args: gnome_shell_st_link_args,
  build_rpath: compositor_rpath + ':' + clutter_rpc_build_dir,
  export_dynamic: true,
  install: true,
  install_rpath: get_option('prefix') / get_option('libdir') + ':' + mutter_typelib_dir + ':' + gnome_shell_pkglibdir,
)

gsr_server_build_dir = meson.current_build_dir()

# Server socket sources for gi-rpc-mock. Same --basedir collision on
# rpc/namespace.vala against the mock's own namespace.vala.
gsr_server_rpc_lib = static_library(
  'gsr-server-rpc',
  files(
    'rpc/namespace.vala',
    'rpc/Daemon.vala',
    'rpc/Connection.vala',
    'rpc/Listen.vala',
  ),
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  install: false,
)

# /proc/self/exe is this directory, and SpawnClient looks for the client there.
custom_target(
  'gsr-server-client-link',
  output: 'gsr-client',
  command: ['ln', '-sfn', '../client/gsr-client', '@OUTPUT@'],
  depends: [gnome_shell_rpc],
  build_by_default: true,
)
custom_target(
  'gsr-server-smoke-link',
  output: 'gsr-smoke',
  command: ['ln', '-sfn', '../client/gsr-smoke', '@OUTPUT@'],
  depends: [gsr_smoke],
  build_by_default: true,
)
