compositor_sources = files(
  'ApplicationInterface.vala',
  'namespace.vala',
  'Main.vala',
  'Plugin.vala',
  'shared/namespace.vala',
  'shared/Rectangle.vala',
  'ui/namespace.vala',
  'ui/Window.vala',
  'ui/Workspace.vala',
  'ui/Display.vala',
  'ui/Compositor.vala',
  'ui/Backend.vala',
  'rpc/namespace.vala',
  'rpc/Bootstrap.vala',
  'rpc/Daemon.vala',
  'rpc/Listen.vala',
  'rpc/Server.vala',
  'rpc/CancellableBridge.vala',
  'rpc/helper/namespace.vala',
  'rpc/helper/SoundPlayer.vala',
  'rpc/helper/Background.vala',
  'rpc/helper/Context.vala',
  'rpc/helper/IdleMonitor.vala',
)

mutter_vala_args = [
  '--pkg=libmutter-16',
  '--pkg=mutter-clutter-16',
  '--pkg=mutter-cogl-16',
  '--pkg=mutter-mtk-16',
  '--pkg=gobject-introspection-1.0',
  '--pkg=xfixes-4.0',
  '--pkg=gdesktopenums-3.0',
  '--vapidir', meson.project_build_root() / 'vapi',
  '--vapidir', meson.project_source_root() / 'vapi',
]

rpc_config = configure_file(
  input: 'rpc/Config.vala.in',
  output: 'Config.vala',
  configuration: configuration_data({
    'MUTTER_TYPELIB_DIR': mutter_typelib_dir,
  }),
)

compositor_rpath = mutter_typelib_dir + ':' + ocrpc_rpath

gnome_shell_rpc = executable('gnome-shell-rpc',
  compositor_sources,
  rpc_config,
  mutter_vapi_stamp,
  dependencies: [mutter_dep, ocrpc_dep, dependency('gobject-introspection-1.0')],
  vala_args: mutter_vala_args + ocrpc_vala_args,
  build_rpath: compositor_rpath,
  export_dynamic: true,
  install: false,
)

rpc_client_sources = files(
  'ApplicationInterface.vala',
  'rpc-client/namespace.vala',
  'rpc-client/Application.vala',
  'shared/namespace.vala',
  'shared/Rectangle.vala',
  'ui/namespace.vala',
  'ui/Window.vala',
)

rpc_client = executable('rpc-client',
  rpc_client_sources,
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

gjs_dep = dependency('gjs-1.0')
girepository_dep = dependency('gobject-introspection-1.0')

gjs_embed = executable('gjs-embed',
  files(
    'ApplicationInterface.vala',
    'gjs-embed/namespace.vala',
    'gjs-embed/Application.vala',
  ),
  dependencies: [
    gjs_dep,
    girepository_dep,
    dependency('gee-0.8'),
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--pkg=gjs-1.0',
    '--pkg=gobject-introspection-1.0',
    '--pkg=gee-0.8',
    '--pkg=gio-2.0',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  install: false,
)

g_ir_compiler = find_program('g-ir-compiler')

gi_stub_gen = executable('gi-stub-gen',
  files(
    'ApplicationInterface.vala',
    'gi-stub-gen/namespace.vala',
    'gi-stub-gen/Generator.vala',
    'gi-stub-gen/Application.vala',
  ),
  dependencies: [
    girepository_dep,
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

# Schema typelib from handwritten GIR (signatures only; no .so required yet).
girpcsmoke_typelib_schema = custom_target('GiRpcSmoke-1.0-schema.typelib',
  input: files('gi-rpc-smoke/GiRpcSmoke-1.0.gir'),
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
    'gi-rpc-smoke/namespace.vala',
    'gi-stub/namespace.vala',
    'gi-stub/Runtime.vala',
    'shared/namespace.vala',
    'shared/Rectangle.vala',
    'ui/namespace.vala',
    'ui/Window.vala',
    'rpc/namespace.vala',
  ),
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

girpcsmoke_typelib = custom_target('GiRpcSmoke-1.0.typelib',
  input: files('gi-rpc-smoke/GiRpcSmoke-1.0.gir'),
  output: 'GiRpcSmoke-1.0.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', girpcsmoke_lib.full_path(),
    '@INPUT@',
  ],
  depends: girpcsmoke_lib,
)

metamini_lib = shared_library('metamini',
  files(
    'meta-mini/namespace.vala',
    'meta-mini/Display.vala',
    'meta-mini/Compositor.vala',
    'meta-mini/Backend.vala',
    'meta-mini/IdleMonitor.vala',
    'meta-mini/WindowActor.vala',
    'meta-mini/Window.vala',
    'meta-mini/SoundPlayer.vala',
    'meta-mini/StartupNotification.vala',
    'meta-mini/LaunchContext.vala',
    'gi-stub/namespace.vala',
    'gi-stub/Runtime.vala',
    'gi-stub/CancellableBridge.vala',
    'shared/namespace.vala',
    'shared/Rectangle.vala',
    'ui/namespace.vala',
    'ui/Window.vala',
    'rpc/namespace.vala',
  ),
  mutter_vapi_stamp,
  dependencies: [
    ocrpc_dep,
    dependency('mutter-clutter-16'),
    dependency('mutter-cogl-16'),
    dependency('mutter-mtk-16'),
  ],
  vala_args: ocrpc_vala_args + [
    '--pkg=mutter-clutter-16',
    '--pkg=mutter-cogl-16',
    '--pkg=mutter-mtk-16',
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  build_rpath: ocrpc_rpath,
  link_args: ['-L' + mutter_typelib_dir],
  install: false,
)

metamini_typelib = custom_target('Meta-16.typelib',
  input: files('meta-mini/Meta-16.gir'),
  output: 'Meta-16.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', metamini_lib.full_path(),
    '--includedir', mutter_typelib_dir,
    '@INPUT@',
  ],
  depends: [metamini_lib],
  build_by_default: true,
)

# Review artifact: client stubs from stock mutter Meta-16 typelib (not linked yet).
meta_deny_file = files('gi-stub-gen/Meta.deny')
meta_overrides_file = files('gi-stub-gen/Meta.overrides')
meta_override_dir = meson.current_source_dir() / 'gi-stub/overrides'
meta_override_files = files(
  'gi-stub/overrides/SoundPlayer.override.vala',
  'gi-stub/overrides/Background.override.vala',
  'gi-stub/overrides/Context.override.vala',
  'gi-stub/overrides/IdleMonitor.override.vala',
  'gi-stub/overrides/WindowActor.override.vala',
)

meta_window_generated = custom_target('meta_window_generated',
  output: ['Meta_window_generated.vala', 'Meta_window_generated.missing.md'],
  command: [
    gi_stub_gen,
    '--out=@OUTPUT0@',
    '--missing-out=@OUTPUT1@',
    '--typelib-dir=' + mutter_typelib_dir,
    '--deny-file=@INPUT0@',
    '--overrides-file=@INPUT1@',
    '--override-path=' + meta_override_dir,
    'emit', 'Meta', '16',
  ],
  input: [meta_deny_file, meta_overrides_file] + meta_override_files,
  depends: [gi_stub_gen],
  build_by_default: true,
)

# Plan 0.5.7: client CancellableBridge (server helpers are in gnome-shell-rpc).
meta_override_client = static_library('meta-override-client',
  files(
    'gi-stub/namespace.vala',
    'gi-stub/Runtime.vala',
    'gi-stub/CancellableBridge.vala',
    'shared/namespace.vala',
    'shared/Rectangle.vala',
    'ui/namespace.vala',
    'ui/Window.vala',
    'rpc/namespace.vala',
  ),
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

gi_rpc_echo = executable('gi-rpc-echo',
  files(
    'ApplicationInterface.vala',
    'rpc/namespace.vala',
    'rpc/Daemon.vala',
    'rpc/Listen.vala',
    'gi-rpc-smoke/namespace.vala',
    'gi-rpc-smoke/PingResult.vala',
    'gi-rpc-echo/namespace.vala',
    'gi-rpc-echo/Echo.vala',
    'gi-rpc-echo/Application.vala',
  ),
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  export_dynamic: true,
  install: false,
)

gtk4_dep = dependency('gtk4')

fake_shell = executable('fake-shell',
  files(
    'ApplicationInterface.vala',
    'shared/namespace.vala',
    'shared/Rectangle.vala',
    'ui/namespace.vala',
    'ui/Window.vala',
    'fake-shell/namespace.vala',
    'fake-shell/Session.vala',
    'fake-shell/Display.vala',
    'fake-shell/Window.vala',
    'fake-shell/Application.vala',
    'fake-shell/TopBar.vala',
  ),
  dependencies: [ocrpc_dep, gtk4_dep],
  vala_args: ocrpc_vala_args + [
    '--pkg=gtk4',
  ],
  build_rpath: ocrpc_rpath,
  install: false,
)
