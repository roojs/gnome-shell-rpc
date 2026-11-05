compositor_sources = files(
  'ApplicationInterface.vala',
  'server/Main.vala',
  'server/Plugin.vala',
  'server/rpc/Daemon.vala',
  'server/Bootstrap.vala',
  'server/rpc/LiveCallback.vala',
  'server/Cancellable.vala',
  'server/StartupFrameLock.vala',
  'server/OverviewPaintHold.vala',
  'server/namespace.vala',
  'server/rpc/namespace.vala',
  'server/rpc/Connection.vala',
  'server/rpc/Lease.vala',
  'server/rpc/Listen.vala',
  'server/rpc/Server.vala',
  'shared/namespace.vala',
  'shared/Rectangle.vala',
  'shared/ClutterEventState.vala',
  'shared/Window.vala',
  'shared/Workspace.vala',
  'server/libmutter-16/namespace.vala',
  'server/libmutter-16/Compositor.vala',
  'server/libmutter-16/Keybinding.vala',
  'server/libmutter-16/WindowActor.vala',
  'server/libmutter-16/Context.vala',
  'server/libmutter-16/Settings.vala',
  'server/libmutter-16/IdleMonitor.vala',
  'server/libmutter-16/SoundPlayer.vala',
  'server/libmutter-16/Background.vala',
  'server/libmutter-16/BackgroundActor.vala',
  'server/libmutter-16/BackgroundImageCache.vala',
  'server/libmutter-16/Selection.vala',
  'server/libmutter-16/SelectionSource.vala',
  'server/libmutter-16/SelectionSourceMemory.vala',
  'server/libmutter-16/ShapedTexture.vala',
  'server/libmutter-16/Barrier.vala',
  'server/libmutter-16/BarrierEventOverride.vala',
  'server/libmutter-16/KeyBindingOverride.vala',
  'server/libmutter-16/AppLaunch.vala',
  'server/libmutter-clutter-18/ClutterActor.vala',
  'server/libmutter-clutter-18/Clutter.vala',
  'server/libmutter-clutter-18/ClutterThreads.vala',
  'server/libmutter-clutter-18/ClutterLayoutManager.vala',
  'server/libmutter-clutter-18/ClutterPaintContext.vala',
  'server/libmutter-clutter-18/Constraint.vala',
  'server/libmutter-clutter-18/Interval.vala',
  'server/libmutter-clutter-18/Text.vala',
  'server/libmutter-clutter-18/ShaderEffect.vala',
  'server/libmutter-clutter-18/Devices.vala',
  'server/libmutter-clutter-18/LayoutHooks.vala',
  'server/libmutter-clutter-18/ClutterEventOverride.vala',
  'server/libmutter-clutter-18/InputDeviceOverride.vala',
  'server/libmutter-clutter-18/PickContextOverride.vala',
  'server/libmutter-clutter-18/RegionOverride.vala',
  'server/libmutter-clutter-18/shader-uniform-apply.c',
  'server/libst-16/namespace.vala',
  'server/libst-16/BoxedTypeOverrides.vala',
  'server/libst-16/St.vala',
  'server/libst-16/ThemeContext.vala',
  'server/libst-16/ThemeNode.vala',
  'server/libst-16/Icon.vala',
  'server/libst-16/IconTheme.vala',
  'server/libst-16/ImageContent.vala',
  'server/libst-16/SpinnerContent.vala',
  'server/libst-16/DrawingArea.vala',
  'server/libst-16/DrawingAreaActor.vala',
  'server/libst-16/ViewportActor.vala',
  'server/libst-16/Viewport.vala',
  'server/libst-16/SquareBinActor.vala',
  'server/libst-16/FocusManager.vala',
  'server/libst-16/Clipboard.vala',
  'server/libshell-16/GLSLEffect.vala',
  'server/libshell-16/BlurEffect.vala',
  'server/libshell-16/InvertLightnessEffect.vala',
)

if mutter_api_version == '18'
  compositor_sources += files(
    'server/libmutter-18/SpawnClient.vala',
    'server/libmutter-18/Display.vala',
    'server/libmutter-18/Window.vala',
    'server/libmutter-18/WaylandClient.vala',
    'server/libmutter-18/Keymap.vala',
    'server/libst-16/DndStart.vala',
    'server/libmutter-18/IdleWatch.vala',
    'server/libmutter-clutter-18/namespace.vala',
    'server/libmutter-clutter-18/ClutterStage.vala',
    'server/libmutter-clutter-18/ClickGesture.vala',
    'server/libmutter-clutter-18/PressGesture.vala',
    'server/libmutter-clutter-18/PanGesture.vala',
    'server/libmutter-clutter-18/LongPressGesture.vala',
    'server/libmutter-clutter-18/Backend.vala',
    'server/libshell-18/namespace.vala',
    'server/libshell-18/EdgeDragGesture.vala',
  )
else
  compositor_sources += files(
    'server/libshell-16/namespace.vala',
    'server/rpc/SpawnClient.vala',
    'server/libmutter-16/Display.vala',
    'server/libmutter-16/Window.vala',
    'server/libmutter-16/WaylandClient.vala',
    'server/libmutter-clutter-16/namespace.vala',
    'server/libmutter-clutter-16/ClutterStage.vala',
    'server/libmutter-clutter-16/ClutterGestureAction.vala',
  )
endif

rpc_gdb_spawn = get_option('rpc_gdb_spawn')
if rpc_gdb_spawn
  compositor_sources += files('server/GdbSpawnWrap.vala')
endif

# 2.0 when that pc exists (Ubuntu 26.04 / GJS 1.88). 1.0 otherwise.
# gi-stub-gen stays on 1.0: the 2.0 vapi has no BaseInfo.get_type().
girepository_2 = dependency('girepository-2.0', required: false)
if girepository_2.found()
  girepository_dep = girepository_2
  girepository_pkg = '--pkg=girepository-2.0'
  girepository_define = ['--define=GIREPOSITORY_2']
else
  girepository_dep = dependency('gobject-introspection-1.0')
  girepository_pkg = '--pkg=gobject-introspection-1.0'
  girepository_define = []
endif

mutter_vala_args = [
  '--pkg=libmutter-' + mutter_api_version,
  '--pkg=mutter-clutter-' + mutter_api_version,
  '--pkg=mutter-cogl-' + mutter_api_version,
  '--pkg=mutter-mtk-' + mutter_api_version,
  girepository_pkg,
  '--pkg=xfixes-4.0',
  '--pkg=gdesktopenums-3.0',
  '--pkg=posix',
  '--pkg=linux',
  '--vapidir', meson.project_build_root() / 'vapi',
  '--vapidir', meson.project_source_root() / 'vapi',
] + girepository_define

# ../tests/meta-mini/*.vala uses Clutter / Mtk / Graphene types in a few hand stubs.
meta_mini_deps = [
  dependency('graphene-gobject-1.0'),
  dependency('mutter-clutter-' + mutter_api_version),
  dependency('mutter-mtk-' + mutter_api_version),
]

meta_mini_vala_args = [
  '--pkg=posix',
  '--pkg=mutter-clutter-' + mutter_api_version,
  '--pkg=mutter-mtk-' + mutter_api_version,
  '--vapidir', meson.project_build_root() / 'vapi',
  '--vapidir', meson.project_source_root() / 'vapi',
]

# Legacy client Shell/St from vendor; disabled by default (Phase C uses St RPC stubs).
mutter_rpc_gir_name = 'mutter-rpc-' + mutter_api_version
mutter_rpc_typelib_install_dir = get_option('libdir') / mutter_rpc_gir_name
gnome_shell_client_libdir = meson.project_build_root() / 'gnome-shell' / 'client-libs'
gnome_shell_client_typelibdir = get_option('gnome_shell_client_libs').enabled() and gnome_shell_vendor_root != '' ? gnome_shell_client_libdir : ''

# Stock pkglibdir / libst: server-only (mutter-rpc links distro libst-16.so).
# Client links libst-rpc-16.so; typelibs are build-tree (Meta/Clutter/St/Shell RPC).
# Distro girdir is St-16.gir schema input + g-ir-compiler include path — not client typelibdir.
gnome_shell_st_link_args = [
  '-Wl,--push-state',
  '-Wl,--no-as-needed',
  gnome_shell_st_lib,
  '-Wl,--pop-state',
]

rpc_config = configure_file(
  input: 'server/Config.vala.in',
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

gjs_dep = dependency('gjs-1.0')

gjs_shell_deps = [
  gjs_dep,
  girepository_dep,
  dependency('gee-0.8'),
  dependency('gio-2.0'),
]

gjs_shell_vala_args = [
  '--pkg=gjs-1.0',
  girepository_pkg,
  '--pkg=gee-0.8',
  '--pkg=gio-2.0',
  '--vapidir', meson.project_source_root() / 'vapi',
] + girepository_define

gjs_embed_config = configure_file(
  input: 'client/Config.vala.in',
  output: 'GjsEmbedConfig.vala',
  configuration: configuration_data({
    'GNOME_SHELL_JS_DIR': gnome_shell_js_runtime_dir,
    'APPLICATION_ID': 'org.gnome.ShellRpc.GjsEmbed',
    'TYPELIB_INSTALL_DIR': get_option('prefix') / mutter_rpc_typelib_install_dir,
    'MUTTER_TYPELIB_DIR': mutter_typelib_dir,
    'MUTTER_API_VERSION': mutter_api_version,
    'GNOME_SHELL_PKGLIBDIR': gnome_shell_pkglibdir,
  }),
)

gnome_shell_rpc_config = configure_file(
  input: 'client/Config.vala.in',
  output: 'GnomeShellRpcConfig.vala',
  configuration: configuration_data({
    'GNOME_SHELL_JS_DIR': gnome_shell_js_runtime_dir,
    'APPLICATION_ID': 'org.gnome.ShellRpc',
    'TYPELIB_INSTALL_DIR': get_option('prefix') / mutter_rpc_typelib_install_dir,
    'MUTTER_TYPELIB_DIR': mutter_typelib_dir,
    'MUTTER_API_VERSION': mutter_api_version,
    'GNOME_SHELL_PKGLIBDIR': gnome_shell_pkglibdir,
  }),
)

g_ir_compiler = find_program('g-ir-compiler')
# gir-xslt-inject.sh. Checked here so a missing xsltproc fails setup, not ninja.
xsltproc = find_program('xsltproc')

gi_stub_gen = executable('gi-stub-gen',
  files(
    'ApplicationInterface.vala',
    'generator/namespace.vala',
    'generator/HeaderConfig.vala',
    'generator/Generator.vala',
    'generator/BoxedType.vala',
    'generator/HeaderGenerator.vala',
    'generator/Application.vala',
  ),
  dependencies: [
    dependency('gobject-introspection-1.0'),
    dependency('gee-0.8'),
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--pkg=gobject-introspection-1.0',
    '--pkg=gee-0.8',
    '--pkg=gio-2.0',
  ],
  install: false,
)

# 0.5 GiRpcSmoke toy — optional; product nested path is mutter-rpc + gnome-shell-rpc.
if get_option('legacy_gi_rpc_smoke')
  # Schema typelib from handwritten GIR (signatures only; no .so required yet).
  girpcsmoke_typelib_schema = custom_target('GiRpcSmoke-1.0-schema.typelib',
    input: files('../tests/gi-rpc-smoke/GiRpcSmoke-1.0.gir'),
    output: 'GiRpcSmoke-1.0-schema.typelib',
    command: [
      g_ir_compiler,
      '--output', '@OUTPUT@',
      '--shared-library', 'libgirpcsmoke.so',
      '@INPUT@',
    ],
  )

  # Copy schema typelib to the name GI.Repository.require expects, in a private dir.
  girpcsmoke_schema_dir = meson.current_build_dir() / 'gi-rpc-smoke-schema'
  girpcsmoke_schema_named = custom_target('GiRpcSmoke-schema-named',
    input: girpcsmoke_typelib_schema,
    output: 'gi-rpc-smoke-schema.stamp',
    command: [
      'sh', '-c',
      'mkdir -p "$1" && cp "$2" "$1/GiRpcSmoke-1.0.typelib" && touch "$3"',
      'sh',
      girpcsmoke_schema_dir,
      '@INPUT@',
      '@OUTPUT@',
    ],
  )

  girpcsmoke_generated = custom_target('GiRpcSmoke_generated.vala',
    output: 'GiRpcSmoke_generated.vala',
    command: [
      gi_stub_gen,
      '--out=@OUTPUT@',
      '--typelib-dir=' + girpcsmoke_schema_dir,
      'emit', 'GiRpcSmoke', '1.0',
    ],
    depends: [girpcsmoke_schema_named, gi_stub_gen],
  )

  girpcsmoke_lib = shared_library('girpcsmoke',
    girpcsmoke_generated,
    files(
      '../tests/gi-rpc-smoke/namespace.vala',
      'client/rpc/namespace.vala',
      '../tests/meta-mini/namespace.vala',
      '../tests/meta-mini/Window.vala',
      '../tests/meta-mini/WindowActor.vala',
      '../tests/meta-mini/Context.vala',
      '../tests/meta-mini/Display.vala',
      '../tests/meta-mini/Compositor.vala',
      '../tests/meta-mini/Backend.vala',
      '../tests/meta-mini/StartupNotification.vala',
      '../tests/meta-mini/LaunchContext.vala',
      '../tests/meta-mini/SoundPlayer.vala',
      '../tests/meta-mini/IdleMonitor.vala',
      'client/libmutter-rpc-16/PaintedContent.vala',
      'client/Cancellable.vala',
      'shared/namespace.vala',
      'shared/Rectangle.vala',
  'shared/ClutterEventState.vala',
      'shared/Window.vala',
      'shared/Workspace.vala',
      'server/rpc/namespace.vala',
    ),
    dependencies: [ocrpc_dep] + meta_mini_deps,
    vala_args: ocrpc_vala_args + meta_mini_vala_args,
    build_rpath: ocrpc_rpath,
    install: false,
  )

  girpcsmoke_typelib = custom_target('GiRpcSmoke-1.0.typelib',
    input: files('../tests/gi-rpc-smoke/GiRpcSmoke-1.0.gir'),
    output: 'GiRpcSmoke-1.0.typelib',
    command: [
      g_ir_compiler,
      '--output', '@OUTPUT@',
      '--shared-library', girpcsmoke_lib.full_path(),
      '@INPUT@',
    ],
    depends: girpcsmoke_lib,
  )

  gi_rpc_echo = executable('gi-rpc-echo',
    files(
      'ApplicationInterface.vala',
      'server/rpc/namespace.vala',
      'server/rpc/Daemon.vala',
      'server/rpc/Connection.vala',
      'server/rpc/Listen.vala',
      '../tests/gi-rpc-smoke/namespace.vala',
      '../tests/gi-rpc-smoke/PingResult.vala',
      '../tests/gi-rpc-echo/namespace.vala',
      '../tests/gi-rpc-echo/Echo.vala',
      '../tests/gi-rpc-echo/Application.vala',
    ),
    dependencies: [ocrpc_dep],
    vala_args: ocrpc_vala_args,
    build_rpath: ocrpc_rpath,
    export_dynamic: true,
    install: false,
  )
endif


# Client Meta from gi-stub-gen (0.6 Phase 2 / 0.5.2 Phase 9).
# Install layout mirrors mutter: .so in libdir; Meta-16 typelib + GIR in
# ${libdir}/mutter-rpc-16/ — never stock mutter-16 or /usr/share/gir-1.0.
# MUTTER_TL=$(pkg-config --variable=typelibdir libmutter-16)
# GI_TYPELIB_PATH=$(pkg-config --variable=typelibdir libmutter-rpc-16):$MUTTER_TL \
#   ./build/src/gjs-embed --debug src/../tests/gjs-embed/meta-smoke.js

meta_deny_file = files('client/libmutter-rpc-16/Meta.deny')
meta_overrides_file = files('client/libmutter-rpc-16/Meta.overrides')
meta_override_dir = meson.current_source_dir() / 'client/libmutter-rpc-16/overrides'
meta_override_files = files(
  'client/libmutter-rpc-16/overrides/SoundPlayer.override.vala',
  'client/libmutter-rpc-16/overrides/Background.override.vala',
  'client/libmutter-rpc-16/overrides/BackgroundActor.override.vala',
  'client/libmutter-rpc-16/overrides/BackgroundContent.override.vala',
  'client/libmutter-rpc-16/overrides/BackgroundImageCache.override.vala',
  'client/libmutter-rpc-16/overrides/Context.override.vala',
  'client/libmutter-rpc-16/overrides/Backend.override.vala',
  'client/libmutter-rpc-16/overrides/Settings.override.vala',
  'client/libmutter-rpc-16/overrides/IdleMonitor.override.vala',
  'client/libmutter-rpc-16/overrides/Laters.override.vala',
  'client/libmutter-rpc-16/overrides/Workspace.override.vala',
  'client/libmutter-rpc-16/overrides/WorkspaceManager.override.vala',
  'client/libmutter-rpc-16/overrides/Display.override.vala',
  'client/libmutter-rpc-16/overrides/Meta.override.vala',
  'client/libmutter-rpc-16/overrides/WindowActor.override.vala',
  'client/libmutter-rpc-16/overrides/Selection.override.vala',
  'client/libmutter-rpc-16/overrides/SelectionSource.override.vala',
  'client/libmutter-rpc-16/overrides/SelectionSourceMemory.override.vala',
  'client/libmutter-rpc-16/overrides/ShapedTexture.override.vala',
  'client/libmutter-rpc-16/overrides/WaylandCompositor.override.vala',
  'client/libmutter-rpc-16/overrides/Compositor.override.vala',
)
if mutter_api_version == '18'
  meta_override_files += files(
    'client/libmutter-rpc-18/overrides/Window.override.vala',
    'client/libmutter-rpc-18/overrides/WaylandClient.override.vala',
    'client/libmutter-rpc-18/overrides/Backend.override.vala',
    'client/libmutter-rpc-18/overrides/IdleMonitor.override.vala',
    'client/libmutter-rpc-18/overrides/KeymapDescription.override.vala',
  )
  meta_deny_file = files('client/libmutter-rpc-18/Meta.deny')
  meta_override_dir = meson.current_source_dir() / 'client/libmutter-rpc-18/overrides' + ':' + meta_override_dir
else
  meta_override_files += files(
    'client/libmutter-rpc-16/overrides/Window.override.vala',
    'client/libmutter-rpc-16/overrides/WaylandClient.override.vala',
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

mutter_includedir = join_paths(
  libmutter_dep.get_variable('includedir'),
  'mutter-' + mutter_api_version,
)

# C deps for our Clutter/Meta stubs (cogl/atk/…).
# Stock mutter-16/clutter is only for compiling our Clutter .so C gaps
# (varargs shim) until/alongside the Vala header; St uses clutter-rpc incdir.
mutter_clutter_cflags_raw = run_command(
  'pkg-config', '--cflags', 'mutter-clutter-' + mutter_api_version, check: true,
).stdout().split()
mutter_clutter_dep_cflags = []
mutter_clutter_stock_inc = []
foreach f : mutter_clutter_cflags_raw
  if f.contains('mutter-' + mutter_api_version + '/clutter')
    mutter_clutter_stock_inc += f
  else
    mutter_clutter_dep_cflags += f
  endif
endforeach
mutter_clutter_cflags = mutter_clutter_dep_cflags

clutter_deny_file = files('client/libmutter-clutter-rpc-16/Clutter.deny')
clutter_overrides_file = configure_file(
  input: 'client/libmutter-clutter-rpc-16/Clutter.overrides',
  output: 'Clutter.overrides',
  configuration: {
    'MUTTER_API_VERSION': mutter_api_version,
  },
)
batch_whitelist = files('client/libmutter-clutter-rpc-16/batch.whitelist')
clutter_override_dir = meson.current_source_dir() / 'client/libmutter-clutter-rpc-16/overrides'
clutter_override_files = files(
  'client/libmutter-clutter-rpc-16/overrides/Clutter.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/AlignConstraint.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/BindConstraint.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/BrightnessContrastEffect.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/DesaturateEffect.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/Clone.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/Constraint.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/ActorBox.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/ClickAction.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/Actor.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/LayoutManager.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/LayoutMeta.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/SnapConstraint.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/ActorIter.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/PipelineNode.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/PaintContext.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/PaintNode.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/Transition.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/Interval.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/Text.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/InputDevice.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/InputMethod.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/ShaderEffect.override.vala',
  'client/libmutter-clutter-rpc-16/overrides/TextureContent.override.vala',
)
if mutter_api_version == '18'
  clutter_override_files += files(
    'client/libmutter-clutter-rpc-18/overrides/Stage.override.vala',
    'client/libmutter-clutter-rpc-18/overrides/Backend.override.vala',
    'client/libmutter-clutter-rpc-18/overrides/Gesture.override.vala',
    'client/libmutter-clutter-rpc-18/overrides/ClickGesture.override.vala',
    'client/libmutter-clutter-rpc-18/overrides/PanGesture.override.vala',
  )
  clutter_deny_file = files('client/libmutter-clutter-rpc-18/Clutter.deny')
  clutter_override_dir = meson.current_source_dir() / 'client/libmutter-clutter-rpc-18/overrides' + ':' + clutter_override_dir
else
  clutter_override_files += files(
    'client/libmutter-clutter-rpc-16/overrides/GestureAction.override.vala',
    'client/libmutter-clutter-rpc-16/overrides/Stage.override.vala',
    'client/libmutter-clutter-rpc-16/overrides/Backend.override.vala',
  )
endif
# Two single-output emits — Meson 1.7 Vala cannot compile CustomTargetIndex
# (clutter_generated[0] / [1]) as a source.
clutter_generated = custom_target('Clutter_generated.vala',
  output: 'Clutter_generated.vala',
  command: [
    gi_stub_gen,
    '--out=@OUTPUT@',
    '--missing-out=' + meson.current_build_dir() / 'Clutter_generated.missing.md',
    '--typelib-dir=' + mutter_typelib_dir,
    '--deny-file=@INPUT0@',
    '--batch-file=' + meson.current_source_dir() / 'client/libmutter-clutter-rpc-16/batch.whitelist',
    '--overrides-file=@INPUT1@',
    '--override-path=' + clutter_override_dir,
    'emit', 'Clutter', mutter_api_version,
  ],
  input: [clutter_deny_file, clutter_overrides_file, batch_whitelist] + clutter_override_files,
  depends: [gi_stub_gen],
  build_by_default: true,
)
clutter_helper_vfunc_ids = custom_target('Clutter_helper_vfunc_ids.vala',
  output: 'Clutter_helper_vfunc_ids.vala',
  command: [
    gi_stub_gen,
    '--out=' + meson.current_build_dir() / 'Clutter_generated_for_helper.vala',
    '--helper-out=@OUTPUT@',
    '--typelib-dir=' + mutter_typelib_dir,
    '--deny-file=@INPUT0@',
    '--batch-file=' + meson.current_source_dir() / 'client/libmutter-clutter-rpc-16/batch.whitelist',
    '--overrides-file=@INPUT1@',
    '--override-path=' + clutter_override_dir,
    'emit', 'Clutter', mutter_api_version,
  ],
  input: [clutter_deny_file, clutter_overrides_file, batch_whitelist] + clutter_override_files,
  depends: [gi_stub_gen],
  build_by_default: true,
)
# The Clutter emit writes this beside the stubs. Vala cannot take a
# second output of that target, so copy it to its own output.
clutter_boxed = custom_target('Clutter_boxed.vala',
  input: clutter_generated,
  output: 'Clutter_boxed.vala',
  command: [
    'cp',
    meson.current_build_dir() / 'Clutter_generated_boxed.vala',
    '@OUTPUT@',
  ],
  build_by_default: true,
)

# Gsr.Boxed is its own namespace. Shell-16 writes a GIR, and a GIR
# cannot hold a second top-level namespace, so this compiles alone.
gsr_clutter_boxed_lib = static_library(
  'gsr-clutter-boxed',
  'boxed/namespace.vala',
  clutter_boxed,
  dependencies: [
    ocrpc_dep,
    dependency('gee-0.8'),
    dependency('graphene-gobject-1.0'),
  ] + mutter_dep,
  vala_args: mutter_vala_args + ocrpc_vala_args + [
    '--pkg=gee-0.8',
    '--pkg=graphene-gobject-1.0',
  ],
  vala_header: 'gsr-clutter-boxed.h',
  vala_vapi: 'gsr-clutter-boxed.vapi',
)

# Client RPC base. Other client libs link this. It does not link them:
# meta_register / st_register / shell hooks / prop-batch flush stay unresolved
# until gsr-client loads every .so.
gsr_rpc_lib = shared_library(
  'gsr-rpc-16',
  files(
    'client/rpc/namespace.vala',
    'client/Cancellable.vala',
    'client/rpc/VfuncRelay.vala',
    'client/rpc/c-vfunc-relay.c',
    'shared/namespace.vala',
    'shared/Rectangle.vala',
  'shared/ClutterEventState.vala',
    'shared/Window.vala',
    'shared/Workspace.vala',
  ),
  dependencies: [
    ocrpc_dep,
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: ocrpc_vala_args + [
    '--pkg=gio-2.0',
    '--pkg=gee-0.8',
  ],
  c_args: [
    '-I' + meson.current_source_dir() / 'client/rpc',
  ],
  link_args: ['-Wl,--unresolved-symbols=ignore-all'],
  vala_header: 'gsr-rpc-16.h',
  vala_vapi: 'gsr-rpc-16.vapi',
  build_rpath: ocrpc_rpath,
  install: true,
)

gsr_rpc_dep = declare_dependency(
  link_with: gsr_rpc_lib,
  dependencies: [ocrpc_dep],
)

# Stub Clutter (separate from Meta — stock-like mutter-clutter split).
mutter_clutter_rpc_gir_name = 'mutter-clutter-rpc-' + mutter_api_version
mutter_clutter_rpc_incdir = meson.current_build_dir() / 'clutter-include'

mutter_clutter_rpc_lib = shared_library(
  'mutter-clutter-rpc-' + mutter_api_version,
  clutter_generated,
  files(
    'client/libmutter-clutter-rpc-16/namespace.vala',
    'client/libmutter-clutter-rpc-18/Event.vala',
    'client/libmutter-clutter-rpc-18/EventSequence.vala',
    'client/libmutter-clutter-rpc-16/Batch.vala',
    'client/libmutter-clutter-rpc-16/c-clutter-abi.c',
    'client/libmutter-clutter-rpc-16/c-rpc-construct-chain.c',
  ),
  dependencies: [
    mutter_vapi_dep,
    gsr_rpc_dep,
    dependency('gio-2.0'),
    dependency('cairo'),
    dependency('atk'),
    dependency('pango'),
    dependency('pangocairo'),
    dependency('graphene-gobject-1.0'),
    dependency('mutter-cogl-' + mutter_api_version),
    dependency('mutter-mtk-' + mutter_api_version),
  ],
  vala_args: ocrpc_vala_args + [
    '--pkg=posix',
    '--pkg=gdesktopenums-3.0',
    '--pkg=atk',
    '--pkg=pango',
    '--pkg=pangocairo',
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--pkg=gsr-rpc-16',
    '--vapidir', meson.current_build_dir(),
    '--vapidir', meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    '--pkg=gsr-clutter-effect-abi',
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    '-DMUTTER_CLUTTER_RPC_HEADER="mutter-clutter-rpc-' + mutter_api_version + '.h"',
  ] + mutter_clutter_cflags + mutter_clutter_stock_inc,
  vala_header: 'mutter-clutter-rpc-' + mutter_api_version + '.h',
  vala_vapi: 'mutter-clutter-rpc-' + mutter_api_version + '.vapi',
  build_rpath: ocrpc_rpath,
  # Actor overrides write Shell.Signals symbols defined in libshell-16.
  link_args: ['-Wl,--unresolved-symbols=ignore-all'],
  install: true,
  install_rpath: mutter_typelib_dir,
)

# Generator-owned stock-shaped clutter/ tree (0.7.4).
clutter_headers_config = files('client/libmutter-clutter-rpc-16/Clutter.headers')
clutter_header_override_files = files(
  'client/libmutter-clutter-rpc-16/header-overrides/Event.h',
  'client/libmutter-clutter-rpc-16/header-overrides/ActorBox.h',
  'client/libmutter-clutter-rpc-16/header-overrides/ActorIter.h',
  'client/libmutter-clutter-rpc-16/header-overrides/Actor.methods.h',
  'client/libmutter-clutter-rpc-16/header-overrides/Interval.methods.h',
  'client/libmutter-clutter-rpc-16/header-overrides/PaintContext.methods.h',
  'client/libmutter-clutter-rpc-16/header-overrides/PaintNode.methods.h',
  'client/libmutter-clutter-rpc-16/header-overrides/ShaderEffect.methods.h',
  'client/libmutter-clutter-rpc-16/header-overrides/TextBuffer.h',
  'client/libmutter-clutter-rpc-16/header-overrides/TextBuffer.methods.h',
  'client/libmutter-clutter-rpc-16/header-overrides/clutter-keysyms.h',
  'client/libmutter-clutter-rpc-16/header-overrides/clutter-macros.h',
  'client/libmutter-clutter-rpc-16/header-overrides/clutter-main.h',
  'client/libmutter-clutter-rpc-16/header-overrides/clutter-pango.h',
  'client/libmutter-clutter-rpc-16/header-overrides/pango/clutter-actor-pango.h',
  'client/libmutter-clutter-rpc-16/header-overrides/pango/clutter-text.h',
  'client/libmutter-clutter-rpc-16/header-overrides/pango/clutter-text-buffer.h',
  'client/libmutter-clutter-rpc-16/header-overrides/pango/clutter-text-node.h',
)
if mutter_api_version == '18'
  clutter_header_override_files += files(
    'client/libmutter-clutter-rpc-18/header-overrides/Stage.methods.h',
  )
else
  clutter_header_override_files += files(
    'client/libmutter-clutter-rpc-16/header-overrides/Stage.methods.h',
  )
endif
stage_clutter_headers = custom_target(
  'clutter-rpc-headers',
  output: 'clutter-headers.stamp',
  input: [clutter_headers_config] + clutter_header_override_files,
  command: [
    'sh', '-c',
    'mkdir -p "$2" && "$1" --typelib-dir="$3" --outdir="$2" --headers-config="$4" emit-headers Clutter ' + mutter_api_version + ' && touch "$5"',
    'sh',
    gi_stub_gen,
    mutter_clutter_rpc_incdir,
    mutter_typelib_dir,
    clutter_headers_config,
    '@OUTPUT@',
  ],
  depends: [gi_stub_gen],
  build_by_default: true,
)
meson.add_install_script(
  'sh', '-c',
  'mkdir -p "${DESTDIR}$2" && cp -a "$1/." "${DESTDIR}$2/"',
  'sh',
  mutter_clutter_rpc_incdir,
  get_option('prefix') / get_option('includedir') / mutter_clutter_rpc_gir_name,
)

configure_file(
  input: 'libmutter-clutter-rpc-16.pc.in',
  output: 'libmutter-clutter-rpc-' + mutter_api_version + '.pc',
  configuration: {
    'prefix': meson.project_build_root(),
    'libdir': meson.current_build_dir(),
    'includedir': mutter_clutter_rpc_incdir,
    'typelibdir': meson.current_build_dir(),
    'girdir': mutter_typelib_dir,
    'dep_cflags': ' '.join(mutter_clutter_dep_cflags),
    'version': meson.project_version(),
    'MUTTER_API_VERSION': mutter_api_version,
  },
)

pkg = import('pkgconfig')
pkg.generate(
  mutter_clutter_rpc_lib,
  filebase: 'libmutter-clutter-rpc-' + mutter_api_version,
  name: 'mutter-clutter-rpc',
  description: 'Mutter-shaped RPC Clutter client (Vala stubs)',
  requires: [
    'gio-2.0',
    'gobject-2.0',
    'atk',
    'pango',
    'mutter-cogl-' + mutter_api_version,
    'mutter-mtk-' + mutter_api_version,
  ],
  variables: [
    'typelibdir=${libdir}/' + mutter_rpc_gir_name,
    'girdir=${libdir}/' + mutter_rpc_gir_name,
  ],
  extra_cflags: [
    '-I${includedir}/' + mutter_clutter_rpc_gir_name,
  ] + mutter_clutter_dep_cflags,
)

# Link-only: Meta Vala .c uses mutter-clutter-rpc-16.h (vala_header) for Clutter*.
# Do not put clutter-include on that compile line — it fights the Vala blob.
mutter_clutter_rpc_link_dep = declare_dependency(
  link_with: mutter_clutter_rpc_lib,
  dependencies: [
    gsr_rpc_dep,
    ocrpc_dep,
    dependency('gee-0.8'),
    dependency('mutter-mtk-' + mutter_api_version),
    dependency('mutter-cogl-' + mutter_api_version),
    dependency('atk'),
    dependency('pango'),
  ],
)

# St / Shell clients: generated clutter/ tree only (0.7.4).
mutter_clutter_rpc_client_dep = declare_dependency(
  dependencies: [mutter_clutter_rpc_link_dep],
  compile_args: [
    '-I' + mutter_clutter_rpc_incdir,
    '-I' + meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
  ] + mutter_clutter_dep_cflags,
  sources: [stage_clutter_headers],
)

# Client Meta stubs (RPC); Clutter + Runtime + Shared/Ui wire types are in clutter-rpc.
# c-meta-shell-gaps includes stock meta/*.h → needs stock clutter/ on -I, and must
# NOT see -include mutter-clutter-rpc-16.h (Vala) or generated clutter-include.
gsr_meta_shell_gaps = static_library(
  'gsr-meta-shell-gaps',
  'client/libmutter-rpc-16/c-meta-shell-gaps.c',
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
    'client/libmutter-rpc-16/namespace.vala',
    'client/libmutter-rpc-16/PaintedContent.vala',
    'client/libmutter-rpc-16/RpcSubprocess.vala',
    'client/libmutter-rpc-16/c-gio-subprocess-launcher-cwd.c',
    'client/libmutter-rpc-16/c-closure-ref.c',
    'client/libmutter-rpc-16/key-binding-wire.c',
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
    '--vapidir', meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    '--pkg=gsr-clutter-effect-abi',
    '--pkg=gsr-rpc-16',
    # mutter_clutter_rpc_link_dep supplies mutter-clutter-rpc-16.vapi; --pkg duplicates it.
    '--vapidir', meson.current_build_dir(),
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + mutter_includedir,
    '-I' + meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    # Vala Clutter types for Meta .c — not the generated clutter-include tree.
    '-include', 'mutter-clutter-rpc-' + mutter_api_version + '.h',
  ] + mutter_clutter_cflags,
  build_rpath: ocrpc_rpath + ':' + meson.current_build_dir(),
  link_args: ['-L' + mutter_typelib_dir],
  vala_header: 'mutter-rpc-' + mutter_api_version + '.h',
  vala_vapi: 'mutter-rpc-' + mutter_api_version + '.vapi',
  install: true,
  install_rpath: mutter_typelib_dir,
)

# mutter_rpc_client_dep is declared after st_rpc_lib (Clutter Runtime needs st_register).

# Stock Meta GIR → our stub .so (same pattern as Clutter).
# Hand ../tests/meta-mini/Meta-16.gir stays for docs / early smokes; typelib must list
# Background etc. for init.js.
# RpcSubprocess peer: separate Gsr-1.0.gir — do not patch stock Meta.
mutter_meta_gir = mutter_typelib_dir / 'Meta-@0@.gir'.format(mutter_api_version)
mutter_rpc_typelib = custom_target('Meta-16.typelib',
  output: 'Meta-' + mutter_api_version + '.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libmutter-rpc-' + mutter_api_version + '.so',
    '--includedir', mutter_typelib_dir,
    mutter_meta_gir,
  ],
  depends: [mutter_rpc_lib],
  build_by_default: true,
  install: true,
  install_dir: mutter_rpc_typelib_install_dir,
)

# Stock Clutter GIR, shared-library → our stub .so (client must not dlopen
# libmutter-clutter; libshell / init.js need the same symbols as libst).
mutter_clutter_gir = mutter_typelib_dir / 'Clutter-@0@.gir'.format(mutter_api_version)
clutter_rpc_typelib = custom_target('Clutter-16.typelib',
  output: 'Clutter-' + mutter_api_version + '.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libmutter-clutter-rpc-' + mutter_api_version + '.so',
    '--includedir', mutter_typelib_dir,
    mutter_clutter_gir,
  ],
  depends: [mutter_clutter_rpc_lib],
  build_by_default: true,
  install: true,
  install_dir: mutter_rpc_typelib_install_dir,
)

st_deny_file = files('client/libst-rpc-16/St.deny')
st_overrides_file = files('client/libst-rpc-16/St.overrides')
st_batch_whitelist = files('client/libst-rpc-16/batch.whitelist')
st_override_dir = meson.current_source_dir() / 'client/libst-rpc-16/overrides'
st_generated = custom_target('St_generated.vala',
  output: 'St_generated.vala',
  command: [
    gi_stub_gen,
    '--out=@OUTPUT@',
    '--missing-out=' + meson.current_build_dir() / 'St_generated.missing.md',
    '--typelib-dir=' + gnome_shell_pkglibdir + ':' + mutter_typelib_dir,
    '--deny-file=@INPUT0@',
    '--batch-file=' + meson.current_source_dir() / 'client/libst-rpc-16/batch.whitelist',
    '--overrides-file=@INPUT1@',
    '--override-path=' + st_override_dir,
    'emit', 'St', mutter_api_version,
  ],
  input: [st_deny_file, st_overrides_file, st_batch_whitelist] + files(
    'client/libst-rpc-16/overrides/Theme.override.vala',
    'client/libst-rpc-16/overrides/ThemeContext.override.vala',
    'client/libst-rpc-16/overrides/ThemeNode.override.vala',
    'client/libst-rpc-16/overrides/Adjustment.override.vala',
    'client/libst-rpc-16/overrides/Icon.override.vala',
    'client/libst-rpc-16/overrides/IconTheme.override.vala',
    'client/libst-rpc-16/overrides/ImageContent.override.vala',
    'client/libst-rpc-16/overrides/SpinnerContent.override.vala',
    'client/libst-rpc-16/overrides/Widget.override.vala',
    'client/libst-rpc-16/overrides/FocusManager.override.vala',
    'client/libst-rpc-16/overrides/Settings.override.vala',
    'client/libst-rpc-16/overrides/Viewport.override.vala',
    'client/libst-rpc-16/overrides/ScrollView.override.vala',
    'client/libst-rpc-16/overrides/GenericAccessible.override.vala',
    'client/libst-rpc-16/overrides/Entry.override.vala',
    'client/libst-rpc-16/overrides/DrawingArea.override.vala',
    'client/libst-rpc-16/overrides/Clipboard.override.vala',
    'client/libst-rpc-16/overrides/DndStartGesture.override.vala',
    'client/libst-rpc-16/overrides/ScrollViewFade.override.vala',
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
  files('client/libst-rpc-16/namespace.vala'),
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
    '--pkg=mutter-clutter-rpc-' + mutter_api_version,
    '--vapidir', meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    '--pkg=gsr-clutter-effect-abi',
    '--vapidir', meson.current_build_dir(),
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    '-include', 'mutter-clutter-rpc-' + mutter_api_version + '.h',
  ],
  link_args: ['-L' + meson.current_build_dir(), '-lmutter-rpc-' + mutter_api_version],
  link_depends: [mutter_clutter_rpc_lib, mutter_rpc_lib],
  build_rpath: ocrpc_rpath + ':' + meson.current_build_dir(),
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
gsr_st_boxed_lib = static_library(
  'gsr-st-boxed',
  'boxed/namespace.vala',
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
    '--pkg=st-rpc-' + mutter_api_version,
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
    '--vapidir', meson.current_build_dir(),
    '--vapidir', meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
  ],
  c_args: [
    '-I' + meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
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

# 0.7.7 — owned Shell-16 facade (not libshell).
# valac requires NAME-VERSION.gir (cannot be *.vala.gir). That file is the
# stamp, never installed. Inject writes Shell-16.injected.gir — typelib and
# any install use that (installed name Shell-16.gir).
# libsystemd has no Vala vapi — assert found, link with -lsystemd only.
dependency('libsystemd')
shell_api_define = []
if mutter_api_version == '18'
  shell_api_define = ['--define=MUTTER_18']
endif
shell_gi_lib = shared_library(
  'shell-' + mutter_api_version,
  files(
    'client/libshell-16/namespace.vala',
    'client/libshell-16/ClutterEventOverride.vala',
    'client/libshell-16/InputDeviceOverride.vala',
    'client/libshell-16/PickContextOverride.vala',
    'client/libshell-16/KeyBindingOverride.vala',
    'client/libshell-16/BarrierEventOverride.vala',
    'client/libshell-16/RegionOverride.vala',
    'client/libshell-16/ActionMode.vala',
    'client/libshell-16/AppState.vala',
    'client/libshell-16/AppLaunchGpu.vala',
    'client/libshell-16/Util.vala',
    'client/libshell-16/App.vala',
    'client/libshell-16/AppSystem.vala',
    'client/libshell-16/app-system-search.c',
    'client/libshell-16/GLSLEffect.vala',
    'client/libshell-16/BlurMode.vala',
    'client/libshell-16/BlurEffect.vala',
    'client/libshell-16/InvertLightnessEffect.vala',
    'client/libshell-16/NetworkAgentResponse.vala',
    'client/libshell-16/NetworkAgentRequest.vala',
    'client/libshell-16/NetworkAgentKeyringSave.vala',
    'client/libshell-16/NetworkAgent.vala',
    'client/libshell-16/MountOperation.vala',
    'client/libshell-16/PolkitAuthenticationAgent.vala',
    'client/libshell-16/polkit-authentication-agent-signals.c',
    'client/libshell-16/SecureTextBuffer.vala',
    'client/libshell-16/KeyringPrompt.vala',
    'client/libshell-16/PerfLog.vala',
    'client/libshell-16/SquareBin.vala',
    'client/libshell-16/Stack.vala',
    'client/libshell-16/WindowPreview.vala',
    'client/libshell-16/WindowPreviewLayout.vala',
    'client/libshell-16/WorkspaceBackground.vala',
    'client/libshell-16/Screenshot.vala',
    'client/libshell-16/WindowTracker.vala',
    'client/libshell-16/AppUsage.vala',
    'client/libshell-16/WM.vala',
    'client/libshell-16/Global.vala',
    'client/libshell-16/TimeChangeSource.vala',
    'client/libshell-16/CameraMonitor.vala',
  ) + (mutter_api_version == '18'
    ? files(
        'client/libshell-18/EdgeDragGesture.vala',
        'client/libshell-18/Signals.vala',
      )
    : files('client/libshell-16/Signals.vala')),
  dependencies: [
    mutter_vapi_dep,
    ocrpc_dep,
    dependency('gio-2.0'),
    dependency('gio-unix-2.0'),
    dependency('libnm'),
    dependency('libsecret-1'),
    dependency('polkit-agent-1'),
    dependency('polkit-gobject-1'),
    dependency('gcr-4'),
    declare_dependency(
      link_with: [
        mutter_rpc_lib,
        st_rpc_lib,
        gsr_clutter_boxed_lib,
        gsr_st_boxed_lib,
      ],
      dependencies: [
        mutter_clutter_rpc_client_dep,
        dependency('mutter-mtk-' + mutter_api_version),
        dependency('mutter-cogl-' + mutter_api_version),
        dependency('atk'),
        dependency('pango'),
        dependency('gdk-pixbuf-2.0'),
        dependency('libnm'),
        dependency('libsecret-1'),
        dependency('polkit-agent-1'),
        dependency('polkit-gobject-1'),
        dependency('gcr-4'),
      ],
      compile_args: ['-I' + mutter_includedir],
    ),
  ],
  link_args: ['-lsystemd'],
  vala_args: ocrpc_vala_args + shell_api_define + [
    '--pkg=posix',
    '--pkg=gio-2.0',
    '--pkg=gee-0.8',
    '--pkg=gdesktopenums-3.0',
    '--pkg=gsr-clutter-effect-abi',
    '--pkg=gdk-pixbuf-2.0',
    '--pkg=libnm',
    '--pkg=libsecret-1',
    '--pkg=polkit-agent-1',
    '--pkg=polkit-gobject-1',
    '--pkg=gcr-4',
    '--pkg=mutter-rpc-' + mutter_api_version,
    '--pkg=gsr-rpc-16',
    '--pkg=mutter-clutter-rpc-' + mutter_api_version,
    '--pkg=st-rpc-' + mutter_api_version,
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--pkg=atk',
    '--pkg=pango',
    '--pkg=graphene-gobject-1.0',
    '--pkg=gsr-clutter-boxed',
    '--pkg=gsr-st-boxed',
    '--vapidir', meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    '--vapidir', meson.current_build_dir(),
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + mutter_includedir,
    '-I' + meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    '-I' + meson.current_source_dir() / 'client/libshell-16',
    '-I' + meson.current_build_dir(),
    '-include', 'mutter-clutter-rpc-' + mutter_api_version + '.h',
    '-include', 'NetworkManager.h',
    '-include', 'nm-secret-agent-old.h',
    '-include', 'libsecret/secret.h',
    # Vala GLib.dpgettext pulls gi18n-lib.h (needs GETTEXT_PACKAGE).
    '-DGETTEXT_PACKAGE="gnome-shell"',
    '-DPOLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE',
    '-DGCR_API_SUBJECT_TO_CHANGE',
  ] + mutter_clutter_cflags,
  build_rpath: ocrpc_rpath + ':' + meson.current_build_dir(),
  vala_header: 'shell-' + mutter_api_version + '.h',
  vala_vapi: 'shell-' + mutter_api_version + '.vapi',
  vala_gir: 'Shell-' + mutter_api_version + '.gir',
  install: true,
  install_dir: [true, false, false, false],
  install_rpath: mutter_typelib_dir,
)

# Injected GIR is what the typelib / install ship (as Shell-16.gir).
# Vala 0.56 GirWriter: no nested GStrv, GLib.DesktopAppInfo. Per-series
# clutch — drop or replace when this tree moves off Shell-16 / valac 0.56.
if mutter_api_version == '18'
  shell_app_info_gir = meson.current_source_dir() / 'client/libshell-18/app-info.gir'
  shell_app_info_type = 'GioUnix.DesktopAppInfo'
else
  shell_app_info_gir = meson.current_source_dir() / 'client/libshell-16/app-info.gir'
  shell_app_info_type = 'Gio.DesktopAppInfo'
endif
shell_gi_gir = custom_target(
  'Shell-' + mutter_api_version + '.injected.gir',
  output: 'Shell-' + mutter_api_version + '.injected.gir',
  command: [
    find_program('sh'),
    meson.project_source_root() / 'scripts/gir-xslt-inject.sh',
    meson.current_build_dir() / 'Shell-' + mutter_api_version + '.gir',
    '@OUTPUT@',
    meson.project_source_root() / 'scripts/gir-inject.xsl',
    meson.current_source_dir() / 'client/libshell-16/search.function.gir',
    shell_app_info_gir,
    xsltproc,
    shell_app_info_type,
  ],
  depend_files: [
    files('client/libshell-16/search.function.gir'),
    files(mutter_api_version == '18' ? 'client/libshell-18/app-info.gir' : 'client/libshell-16/app-info.gir'),
    meson.project_source_root() / 'scripts/gir-inject.xsl',
    meson.project_source_root() / 'scripts/gir-xslt-inject.sh',
  ],
  depends: [shell_gi_lib],
  build_by_default: true,
  install: false,
)

shell_gi_typelib = custom_target(
  'Shell-' + mutter_api_version + '.typelib',
  output: 'Shell-' + mutter_api_version + '.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libshell-' + mutter_api_version + '.so',
    '--includedir', mutter_typelib_dir,
    '--includedir', gnome_shell_girdir,
    '--includedir', gnome_shell_st_girdir,
    '--includedir', meson.current_build_dir(),
    shell_gi_gir,
  ],
  depends: [shell_gi_lib],
  build_by_default: true,
  install: true,
  install_dir: mutter_rpc_typelib_install_dir,
)

# Meta.RpcSubprocess peer methods for GJS (find_by_gtype). Not stock Meta GIR.
gsr_rpc_subprocess_typelib = custom_target(
  'Gsr-1.0.typelib',
  input: meson.current_source_dir() / 'client/libmutter-rpc-16' / 'Gsr-1.0.gir',
  output: 'Gsr-1.0.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libmutter-rpc-' + mutter_api_version + '.so',
    '@INPUT@',
  ],
  depends: [mutter_rpc_lib],
  build_by_default: true,
  install: true,
  install_dir: mutter_rpc_typelib_install_dir,
)

# 0.7.7 S1 — JS gresource (vendor tree + substituted misc/config.js).
# Vendor root is required and resolved in gnome-shell/meson.build (auto-detect).
gnome = import('gnome')
vendor_js_dir = gnome_shell_vendor_root / 'js'
vendor_data_dir = gnome_shell_vendor_root / 'data'
# Upstream moved generate-app-list.py: meson/ on 48.x, build-aux/ on newer.
generate_app_list_script = gnome_shell_vendor_root / 'meson' / 'generate-app-list.py'
if not fs.exists(generate_app_list_script)
  generate_app_list_script = gnome_shell_vendor_root / 'build-aux' / 'generate-app-list.py'
endif
generate_app_list = find_program(generate_app_list_script)
subdir('client/gresource')
st_gir = gnome_shell_st_gir
# Typelib is ours (→ libst-rpc). Distro or generated St gir is schema only;
# includedir resolves GIR imports. Do not point shared-library at stock libst.
st_rpc_typelib = custom_target('St-16.typelib',
  output: 'St-' + mutter_api_version + '.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libst-rpc-' + mutter_api_version + '.so',
    '--includedir', mutter_typelib_dir,
    '--includedir', gnome_shell_girdir,
    '--includedir', gnome_shell_st_girdir,
    st_gir,
  ],
  depends: [st_rpc_lib],
  build_by_default: true,
  install: true,
  install_dir: mutter_rpc_typelib_install_dir,
)

# Thin gnome-shell-rpc host (no libshell / no client libst).
# Link st-rpc for Runtime.st_register without --pkg/st vapi (Gdk noise).
gnome_shell_rpc = executable('gsr-client',
  files(
    'ApplicationInterface.vala',
    'client/namespace.vala',
    'client/Application.vala',
    'client/shell-main.vala',
  ) + shell_js_resources + gsr_js_resources,
  gnome_shell_rpc_config,
  dependencies: gjs_shell_deps + [
    mutter_vapi_dep,
    ocrpc_dep,
    dependency('gdk-pixbuf-2.0'),
    # NetworkAgent / Polkit / KeyringPrompt types leak into shell-16.vapi.
    dependency('libnm'),
    dependency('polkit-agent-1'),
    dependency('polkit-gobject-1'),
    dependency('gcr-4'),
    declare_dependency(
      link_with: [gsr_rpc_lib, mutter_rpc_lib, mutter_clutter_rpc_lib, shell_gi_lib],
      dependencies: [
        dependency('mutter-mtk-' + mutter_api_version),
        dependency('mutter-cogl-' + mutter_api_version),
        dependency('atk'),
        dependency('pango'),
      ],
      compile_args: ['-I' + mutter_includedir],
    ),
  ],
  vala_args: gjs_shell_vala_args + ocrpc_vala_args + [
    '--pkg=gdesktopenums-3.0',
    '--pkg=gsr-clutter-effect-abi',
    '--pkg=gdk-pixbuf-2.0',
    '--pkg=libnm',
    '--pkg=polkit-agent-1',
    '--pkg=polkit-gobject-1',
    '--pkg=gcr-4',
    '--pkg=mutter-rpc-' + mutter_api_version,
    '--pkg=gsr-rpc-16',
    '--pkg=mutter-clutter-rpc-' + mutter_api_version,
    '--pkg=st-rpc-' + mutter_api_version,
    '--pkg=shell-' + mutter_api_version,
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--pkg=atk',
    '--pkg=pango',
    '--vapidir', meson.current_build_dir(),
    '--vapidir', meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + mutter_includedir,
    '-I' + meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    '-I' + meson.current_build_dir(),
    '-include', 'mutter-clutter-rpc-' + mutter_api_version + '.h',
    # shell-16.h embeds NetworkAgent → NMSecretAgentOld.
    '-include', 'NetworkManager.h',
    '-include', 'nm-secret-agent-old.h',
    '-DPOLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE',
    '-DGCR_API_SUBJECT_TO_CHANGE',
  ] + mutter_clutter_cflags,
  link_args: ['-L' + meson.current_build_dir(), '-lst-rpc-' + mutter_api_version],
  link_depends: [
    st_rpc_lib,
    shell_gi_typelib,
    mutter_rpc_typelib,
    clutter_rpc_typelib,
    st_rpc_typelib,
    gsr_rpc_subprocess_typelib,
  ],
  # libgvc.so lives in the gnome-shell pkglibdir. Gvc.MixerControl
  # is that library; without it on the runpath the type comes out void.
  build_rpath: ocrpc_rpath + ':' + meson.current_build_dir() + ':' + gnome_shell_pkglibdir,
  install: true,
  install_rpath: get_option('prefix') / get_option('libdir') + ':' + mutter_typelib_dir + ':' + gnome_shell_pkglibdir,
)

# Smoke and debug host. Same link as gsr-client.
gsr_smoke = executable('gsr-smoke',
  files(
    'ApplicationInterface.vala',
    'client/namespace.vala',
    'client/Application.vala',
    'client/SmokeApplication.vala',
    'client/smoke-main.vala',
  ) + shell_js_resources + gsr_js_resources,
  gnome_shell_rpc_config,
  dependencies: gjs_shell_deps + [
    mutter_vapi_dep,
    ocrpc_dep,
    dependency('gdk-pixbuf-2.0'),
    # NetworkAgent / Polkit / KeyringPrompt types leak into shell-16.vapi.
    dependency('libnm'),
    dependency('polkit-agent-1'),
    dependency('polkit-gobject-1'),
    dependency('gcr-4'),
    declare_dependency(
      link_with: [gsr_rpc_lib, mutter_rpc_lib, mutter_clutter_rpc_lib, shell_gi_lib],
      dependencies: [
        dependency('mutter-mtk-' + mutter_api_version),
        dependency('mutter-cogl-' + mutter_api_version),
        dependency('atk'),
        dependency('pango'),
      ],
      compile_args: ['-I' + mutter_includedir],
    ),
  ],
  vala_args: gjs_shell_vala_args + ocrpc_vala_args + [
    '--pkg=gdesktopenums-3.0',
    '--pkg=gsr-clutter-effect-abi',
    '--pkg=gdk-pixbuf-2.0',
    '--pkg=libnm',
    '--pkg=polkit-agent-1',
    '--pkg=polkit-gobject-1',
    '--pkg=gcr-4',
    '--pkg=mutter-rpc-' + mutter_api_version,
    '--pkg=gsr-rpc-16',
    '--pkg=mutter-clutter-rpc-' + mutter_api_version,
    '--pkg=st-rpc-' + mutter_api_version,
    '--pkg=shell-' + mutter_api_version,
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--pkg=atk',
    '--pkg=pango',
    '--vapidir', meson.current_build_dir(),
    '--vapidir', meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + mutter_includedir,
    '-I' + meson.current_source_dir() / 'client/libmutter-clutter-rpc-16',
    '-I' + meson.current_build_dir(),
    '-include', 'mutter-clutter-rpc-' + mutter_api_version + '.h',
    # shell-16.h embeds NetworkAgent → NMSecretAgentOld.
    '-include', 'NetworkManager.h',
    '-include', 'nm-secret-agent-old.h',
    '-DPOLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE',
    '-DGCR_API_SUBJECT_TO_CHANGE',
  ] + mutter_clutter_cflags,
  link_args: ['-L' + meson.current_build_dir(), '-lst-rpc-' + mutter_api_version],
  link_depends: [
    st_rpc_lib,
    shell_gi_typelib,
    mutter_rpc_typelib,
    clutter_rpc_typelib,
    st_rpc_typelib,
    gsr_rpc_subprocess_typelib,
  ],
  build_rpath: ocrpc_rpath + ':' + meson.current_build_dir() + ':' + gnome_shell_pkglibdir,
  install: true,
  install_rpath: get_option('prefix') / get_option('libdir') + ':' + mutter_typelib_dir + ':' + gnome_shell_pkglibdir,
)

configure_file(
  input: 'libst-rpc-16.pc.in',
  output: 'libst-rpc-' + mutter_api_version + '.pc',
  configuration: {
    'prefix': meson.project_build_root(),
    'libdir': meson.current_build_dir(),
    'typelibdir': meson.current_build_dir(),
    'girdir': gnome_shell_st_girdir,
    'version': meson.project_version(),
    'MUTTER_API_VERSION': mutter_api_version,
  },
)

pkg.generate(
  st_rpc_lib,
  filebase: 'libst-rpc-' + mutter_api_version,
  name: 'libst-rpc',
  description: 'St-shaped RPC client (Vala stubs)',
  requires: [
    'gio-2.0',
    'gobject-2.0',
    'mutter-cogl-' + mutter_api_version,
    'mutter-mtk-' + mutter_api_version,
    'libmutter-clutter-rpc-' + mutter_api_version,
  ],
  variables: [
    'typelibdir=${libdir}/' + mutter_rpc_gir_name,
    'girdir=${libdir}/' + mutter_rpc_gir_name,
  ],
)

meta_mini_gir = configure_file(
  input: '../tests/meta-mini/Meta-16.gir',
  output: 'Meta-@0@.gir'.format(mutter_api_version),
  configuration: {
    'MUTTER_API_VERSION': mutter_api_version,
  },
)
install_data(
  meta_mini_gir,
  install_dir: mutter_rpc_typelib_install_dir,
)

# Build-tree pc (nested / PKG_CONFIG_PATH=build/src). typelib lives next to .so here.
configure_file(
  input: 'libmutter-rpc-16.pc.in',
  output: 'libmutter-rpc-' + mutter_api_version + '.pc',
  configuration: {
    'prefix': meson.project_build_root(),
    'libdir': meson.current_build_dir(),
    'typelibdir': meson.current_build_dir(),
    'girdir': meson.current_build_dir(),
    'clientlibdir': gnome_shell_client_libdir,
    'mutter_includedir': mutter_includedir,
    'version': meson.project_version(),
    'MUTTER_API_VERSION': mutter_api_version,
  },
)

# Installed pc.
pkg.generate(
  mutter_rpc_lib,
  filebase: 'libmutter-rpc-' + mutter_api_version,
  name: 'mutter-rpc',
  description: 'Mutter-shaped RPC client (GJS + C Meta-' + mutter_api_version + ')',
  requires: [
    'gio-2.0',
    'gobject-2.0',
    'atk',
    'pango',
    'mutter-cogl-' + mutter_api_version,
    'mutter-mtk-' + mutter_api_version,
    'libmutter-clutter-rpc-' + mutter_api_version,
  ],
  variables: [
    'typelibdir=${libdir}/' + mutter_rpc_gir_name,
    'girdir=${libdir}/' + mutter_rpc_gir_name,
    'clientlibdir=${libdir}/' + mutter_rpc_gir_name,
    'mutter_includedir=' + mutter_includedir,
  ],
  extra_cflags: ['-I' + mutter_includedir],
)

# Plan 0.5.7 scaffold — never linked into compositor/client boot; optional.
if get_option('legacy_gi_rpc_smoke')
  meta_override_client = static_library('meta-override-client',
    files(
      'client/rpc/namespace.vala',
      '../tests/meta-mini/namespace.vala',
      '../tests/meta-mini/Window.vala',
      '../tests/meta-mini/WindowActor.vala',
      '../tests/meta-mini/Context.vala',
      '../tests/meta-mini/Display.vala',
      '../tests/meta-mini/Compositor.vala',
      '../tests/meta-mini/Backend.vala',
      '../tests/meta-mini/StartupNotification.vala',
      '../tests/meta-mini/LaunchContext.vala',
      '../tests/meta-mini/SoundPlayer.vala',
      '../tests/meta-mini/IdleMonitor.vala',
      'client/Cancellable.vala',
      'client/libmutter-rpc-16/PaintedContent.vala',
      'shared/namespace.vala',
      'shared/Rectangle.vala',
  'shared/ClutterEventState.vala',
      'shared/Window.vala',
      'shared/Workspace.vala',
      'server/rpc/namespace.vala',
    ),
    dependencies: [ocrpc_dep] + meta_mini_deps,
    vala_args: ocrpc_vala_args + meta_mini_vala_args,
    build_rpath: ocrpc_rpath,
    install: false,
  )
endif

gtk4_dep = dependency('gtk4')

if get_option('gnome_shell_client_libs').enabled() and gnome_shell_vendor_root != ''
  # Legacy vendored libshell/libst — optional comparison only (0.7.7 default host is thin).
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
  link_with: gsr_clutter_boxed_lib,
  vala_args: mutter_rpc_vala_args + [
    '--pkg=gee-0.8',
    '--pkg=cairo',
    '--pkg=graphene-gobject-1.0',
    '--pkg=gsr-clutter-boxed',
    '--vapidir', meson.current_build_dir(),
  ],
  c_args: [
    '-I' + meson.project_source_root() / 'vapi',
  ],
  link_args: gnome_shell_st_link_args,
  build_rpath: compositor_rpath,
  export_dynamic: true,
  install: true,
  install_rpath: get_option('prefix') / get_option('libdir') + ':' + mutter_typelib_dir + ':' + gnome_shell_pkglibdir,
)

session_data = meson.project_source_root() / 'data'
install_data(
  session_data / 'gsr-session',
  session_data / 'gsr-debug-session',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)
install_data(
  session_data / 'wayland-sessions' / 'gsr.desktop',
  session_data / 'wayland-sessions' / 'gsr-debug.desktop',
  install_dir: get_option('datadir') / 'wayland-sessions',
)
install_data(
  session_data / 'gnome-session' / 'sessions' / 'gsr.session',
  session_data / 'gnome-session' / 'sessions' / 'gsr-debug.session',
  install_dir: get_option('datadir') / 'gnome-session' / 'sessions',
)
install_data(
  session_data / 'applications' / 'org.gnome.ShellRpc.desktop',
  session_data / 'applications' / 'org.gnome.ShellRpcDebug.desktop',
  install_dir: get_option('datadir') / 'applications',
)
systemd = dependency('systemd', required: false)
if systemd.found()
  systemduserunitdir = systemd.get_variable('systemduserunitdir')
else
  systemduserunitdir = 'lib' / 'systemd' / 'user'
endif
install_data(
  session_data / 'systemd' / 'org.gnome.ShellRpc.target',
  session_data / 'systemd' / 'org.gnome.ShellRpc@.service',
  session_data / 'systemd' / 'org.gnome.ShellRpcDebug.target',
  session_data / 'systemd' / 'org.gnome.ShellRpcDebug.service',
  install_dir: systemduserunitdir,
)
install_data(
  session_data / 'systemd' / 'gnome-session@gsr.target.d' / 'gsr.session.conf',
  install_dir: systemduserunitdir / 'gnome-session@gsr.target.d',
)
install_data(
  session_data / 'systemd' / 'gnome-session@gsr-debug.target.d' / 'gsr.session.conf',
  install_dir: systemduserunitdir / 'gnome-session@gsr-debug.target.d',
)
apport_report_ignore = configure_file(
  input: session_data / 'apport' / 'report-ignore.in',
  output: 'gnome-shell-rpc',
  configuration: {
    'gsr_client': get_option('prefix') / get_option('bindir') / 'gsr-client',
    'gsr_server': get_option('prefix') / get_option('bindir') / 'gsr-server',
  },
)
install_data(
  apport_report_ignore,
  install_dir: get_option('sysconfdir') / 'apport' / 'report-ignore',
)
