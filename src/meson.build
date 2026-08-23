compositor_sources = files(
  'ApplicationInterface.vala',
  'namespace.vala',
  'Main.vala',
  'Plugin.vala',
  'shared/namespace.vala',
  'shared/Rectangle.vala',
  'ui/namespace.vala',
  'ui/WindowParams.vala',
  'ui/Window.vala',
  'ui/WorkspaceParams.vala',
  'ui/Workspace.vala',
  'ui/DisplayParams.vala',
  'ui/Display.vala',
  'rpc/namespace.vala',
  'rpc/DaemonParams.vala',
  'rpc/Daemon.vala',
  'rpc/Listen.vala',
  'rpc/Server.vala',
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
  install: false,
)

rpc_client_sources = files(
  'ApplicationInterface.vala',
  'rpc-client/namespace.vala',
  'rpc-client/Application.vala',
  'shared/namespace.vala',
  'shared/Rectangle.vala',
  'ui/namespace.vala',
  'ui/WindowParams.vala',
  'ui/Window.vala',
  'ui/DisplayParams.vala',
  'rpc/DaemonParams.vala',
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

# Review artifact: full Meta-16 stub emit (not linked into any binary yet).
meta_generated = custom_target('Meta_generated.vala',
  output: 'Meta_generated.vala',
  command: [
    gi_stub_gen,
    'emit', 'Meta', '16',
    '--typelib-dir=' + mutter_typelib_dir,
    '--out=@OUTPUT@',
  ],
  depends: gi_stub_gen,
  build_by_default: true,
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
    'emit', 'GiRpcSmoke', '1.0',
    '--typelib-dir=' + girpcsmoke_schema_dir,
    '--allow=ping',
    '--out=@OUTPUT@',
  ],
  depends: [girpcsmoke_schema_named, gi_stub_gen],
)

girpcsmoke_lib = shared_library('girpcsmoke',
  girpcsmoke_generated,
  files(
    'gi-rpc-smoke/namespace.vala',
  ),
  dependencies: [dependency('gobject-2.0'), dependency('glib-2.0')],
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
    'meta-mini/Window.vala',
    'meta-mini/StartupNotification.vala',
    'meta-mini/LaunchContext.vala',
    'gi-stub/namespace.vala',
    'gi-stub/Runtime.vala',
    'shared/namespace.vala',
    'shared/Rectangle.vala',
    'ui/namespace.vala',
    'ui/WindowParams.vala',
    'ui/Window.vala',
    'ui/DisplayParams.vala',
    'rpc/namespace.vala',
    'rpc/DaemonParams.vala',
  ),
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

metamini_typelib = custom_target('Meta-16.typelib',
  input: files('meta-mini/Meta-16.gir'),
  output: 'Meta-16.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', metamini_lib.full_path(),
    '@INPUT@',
  ],
  depends: [metamini_lib],
  build_by_default: true,
)

gi_rpc_echo = executable('gi-rpc-echo',
  files(
    'ApplicationInterface.vala',
    'rpc/namespace.vala',
    'rpc/DaemonParams.vala',
    'rpc/Daemon.vala',
    'rpc/Listen.vala',
    'gi-rpc-smoke/namespace.vala',
    'gi-rpc-smoke/PingParams.vala',
    'gi-rpc-smoke/PingResult.vala',
    'gi-rpc-echo/namespace.vala',
    'gi-rpc-echo/Echo.vala',
    'gi-rpc-echo/Application.vala',
  ),
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

gtk4_dep = dependency('gtk4')

fake_shell = executable('fake-shell',
  files(
    'ApplicationInterface.vala',
    'shared/namespace.vala',
    'shared/Rectangle.vala',
    'ui/namespace.vala',
    'ui/WindowParams.vala',
    'ui/Window.vala',
    'ui/DisplayParams.vala',
    'rpc/DaemonParams.vala',
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
