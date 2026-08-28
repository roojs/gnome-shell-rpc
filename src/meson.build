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
  'rpc/helper/Display.vala',
  'rpc/helper/Window.vala',
  'rpc/helper/WindowActor.vala',
  'rpc/helper/Devices.vala',
  'rpc/helper/Selection.vala',
  'rpc/helper/SelectionSource.vala',
  'rpc/helper/SelectionSourceMemory.vala',
  'rpc/helper/ShapedTexture.vala',
)

mutter_vala_args = [
  '--pkg=libmutter-16',
  '--pkg=mutter-clutter-16',
  '--pkg=mutter-cogl-16',
  '--pkg=mutter-mtk-16',
  '--pkg=gobject-introspection-1.0',
  '--pkg=xfixes-4.0',
  '--pkg=gdesktopenums-3.0',
  '--pkg=posix',
  '--vapidir', meson.project_build_root() / 'vapi',
  '--vapidir', meson.project_source_root() / 'vapi',
]

# meta-mini/*.vala uses Clutter / Mtk / Graphene types in a few hand stubs.
meta_mini_deps = [
  dependency('graphene-gobject-1.0'),
  dependency('mutter-clutter-16'),
  dependency('mutter-mtk-16'),
]

meta_mini_vala_args = [
  '--pkg=posix',
  '--pkg=mutter-clutter-16',
  '--pkg=mutter-mtk-16',
  '--vapidir', meson.project_build_root() / 'vapi',
  '--vapidir', meson.project_source_root() / 'vapi',
]

# Fixed build-tree location (client-libs/meson.build uses meson.current_build_dir()).
gnome_shell_client_libdir = meson.project_build_root() / 'gnome-shell' / 'client-libs'
gnome_shell_client_typelibdir = get_option('gnome_shell_client_libs').enabled() and gnome_shell_vendor_root != '' ? gnome_shell_client_libdir : ''

rpc_config = configure_file(
  input: 'rpc/Config.vala.in',
  output: 'Config.vala',
  configuration: configuration_data({
    'MUTTER_TYPELIB_DIR': mutter_typelib_dir,
    'GNOME_SHELL_CLIENT_TYPELIB_DIR': gnome_shell_client_typelibdir,
  }),
)

compositor_rpath = mutter_typelib_dir + ':' + ocrpc_rpath

mutter_rpc = executable('mutter-rpc',
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

gjs_shell_sources = files(
  'ApplicationInterface.vala',
  'gjs-embed/namespace.vala',
  'gjs-embed/Application.vala',
)

gjs_shell_deps = [
  gjs_dep,
  girepository_dep,
  dependency('gee-0.8'),
  dependency('gio-2.0'),
]

gjs_shell_vala_args = [
  '--pkg=gjs-1.0',
  '--pkg=gobject-introspection-1.0',
  '--pkg=gee-0.8',
  '--pkg=gio-2.0',
  '--vapidir', meson.project_source_root() / 'vapi',
]

gjs_embed_config = configure_file(
  input: 'gjs-embed/Config.vala.in',
  output: 'GjsEmbedConfig.vala',
  configuration: configuration_data({
    'GNOME_SHELL_JS_DIR': gnome_shell_js_runtime_dir,
    'APPLICATION_ID': 'org.gnome.ShellRpc.GjsEmbed',
  }),
)

gnome_shell_rpc_config = configure_file(
  input: 'gjs-embed/Config.vala.in',
  output: 'GnomeShellRpcConfig.vala',
  configuration: configuration_data({
    'GNOME_SHELL_JS_DIR': gnome_shell_js_runtime_dir,
    'APPLICATION_ID': 'org.gnome.ShellRpc',
  }),
)

gjs_embed = executable('gjs-embed',
  gjs_shell_sources,
  gjs_embed_config,
  dependencies: gjs_shell_deps,
  vala_args: gjs_shell_vala_args,
  install: false,
)

gnome_shell_rpc = executable('gnome-shell-rpc',
  gjs_shell_sources,
  gnome_shell_rpc_config,
  dependencies: gjs_shell_deps,
  vala_args: gjs_shell_vala_args,
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
    'meta-mini/Window.vala',
    'meta-mini/WindowActor.vala',
    'gi-stub/PaintedContent.vala',
    'shared/namespace.vala',
    'shared/Rectangle.vala',
    'ui/namespace.vala',
    'ui/Window.vala',
    'rpc/namespace.vala',
  ),
  dependencies: [ocrpc_dep] + meta_mini_deps,
  vala_args: ocrpc_vala_args + meta_mini_vala_args,
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

# Client Meta from gi-stub-gen (0.6 Phase 2 / 0.5.2 Phase 9).
# Install layout mirrors mutter: .so in libdir; Meta-16 typelib + GIR in
# ${libdir}/mutter-rpc-16/ — never stock mutter-16 or /usr/share/gir-1.0.
# MUTTER_TL=$(pkg-config --variable=typelibdir libmutter-16)
# GI_TYPELIB_PATH=$(pkg-config --variable=typelibdir libmutter-rpc-16):$MUTTER_TL \
#   ./build/src/gjs-embed --debug src/gjs-embed/meta-smoke.js
mutter_rpc_gir_name = 'mutter-rpc-16'
mutter_rpc_typelib_install_dir = get_option('libdir') / mutter_rpc_gir_name

meta_deny_file = files('gi-stub-gen/Meta.deny')
meta_overrides_file = files('gi-stub-gen/Meta.overrides')
meta_override_dir = meson.current_source_dir() / 'gi-stub/overrides'
meta_override_files = files(
  'gi-stub/overrides/SoundPlayer.override.vala',
  'gi-stub/overrides/Background.override.vala',
  'gi-stub/overrides/Context.override.vala',
  'gi-stub/overrides/IdleMonitor.override.vala',
  'gi-stub/overrides/Display.override.vala',
  'gi-stub/overrides/Window.override.vala',
  'gi-stub/overrides/Meta.override.vala',
  'gi-stub/overrides/WindowActor.override.vala',
  'gi-stub/overrides/Selection.override.vala',
  'gi-stub/overrides/SelectionSource.override.vala',
  'gi-stub/overrides/SelectionSourceMemory.override.vala',
  'gi-stub/overrides/ShapedTexture.override.vala',
  'gi-stub/overrides/WaylandCompositor.override.vala',
)

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
    'emit', 'Meta', '16',
  ],
  input: [meta_deny_file, meta_overrides_file] + meta_override_files,
  depends: [gi_stub_gen],
  build_by_default: true,
)

mutter_includedir = join_paths(
  libmutter_dep.get_variable('includedir'),
  'mutter-16',
)

mutter_rpc_lib = shared_library('mutter-rpc-16',
  meta_window_generated,
  files(
    'gi-stub/namespace.vala',
    'gi-stub/Runtime.vala',
    'gi-stub/CancellableBridge.vala',
    'gi-stub/PaintedContent.vala',
    'gi-stub/c-meta-shell-gaps.c',
    'shared/namespace.vala',
    'shared/Rectangle.vala',
    'ui/namespace.vala',
    'ui/Window.vala',
    'rpc/namespace.vala',
  ),
  mutter_vapi_stamp,
  dependencies: [
    ocrpc_dep,
    dependency('gio-2.0'),
    dependency('cairo'),
    dependency('graphene-gobject-1.0'),
    dependency('mutter-clutter-16'),
    dependency('mutter-cogl-16'),
    dependency('mutter-mtk-16'),
    dependency('x11'),
  ],
  vala_args: ocrpc_vala_args + [
    '--pkg=posix',
    '--pkg=gdesktopenums-3.0',
    '--pkg=mutter-clutter-16',
    '--pkg=mutter-cogl-16',
    '--pkg=mutter-mtk-16',
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: ['-I' + mutter_includedir],
  build_rpath: ocrpc_rpath,
  link_args: ['-L' + mutter_typelib_dir],
  install: true,
)

# Soname only — do not bake build-dir full_path into the typelib.
mutter_rpc_typelib = custom_target('Meta-16.typelib',
  input: files('meta-mini/Meta-16.gir'),
  output: 'Meta-16.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libmutter-rpc-16.so',
    '--includedir', mutter_typelib_dir,
    '@INPUT@',
  ],
  depends: [mutter_rpc_lib],
  build_by_default: true,
  install: true,
  install_dir: mutter_rpc_typelib_install_dir,
)

install_data(
  files('meta-mini/Meta-16.gir'),
  install_dir: mutter_rpc_typelib_install_dir,
)

# Build-tree pc (nested / PKG_CONFIG_PATH=build/src). typelib lives next to .so here.
configure_file(
  input: 'libmutter-rpc-16.pc.in',
  output: 'libmutter-rpc-16.pc',
  configuration: {
    'prefix': meson.project_build_root(),
    'libdir': meson.current_build_dir(),
    'typelibdir': meson.current_build_dir(),
    'girdir': meson.current_source_dir() / 'meta-mini',
    'mutter_includedir': mutter_includedir,
    'version': meson.project_version(),
  },
)

# Installed pc: Meta-16.{typelib,gir} under ${libdir}/mutter-rpc-16.
pkg = import('pkgconfig')
pkg.generate(
  mutter_rpc_lib,
  filebase: 'libmutter-rpc-16',
  name: 'mutter-rpc',
  description: 'Mutter-shaped RPC client (GJS + C Meta-16)',
  requires: ['gio-2.0', 'gobject-2.0', 'mutter-clutter-16'],
  variables: [
    'typelibdir=${libdir}/' + mutter_rpc_gir_name,
    'girdir=${libdir}/' + mutter_rpc_gir_name,
    'mutter_includedir=' + mutter_includedir,
  ],
  extra_cflags: '-I' + mutter_includedir,
)

# Plan 0.5.7: client CancellableBridge (server helpers are in mutter-rpc).
meta_override_client = static_library('meta-override-client',
  files(
    'gi-stub/namespace.vala',
    'gi-stub/Runtime.vala',
    'meta-mini/Window.vala',
    'meta-mini/WindowActor.vala',
    'gi-stub/CancellableBridge.vala',
    'gi-stub/PaintedContent.vala',
    'shared/namespace.vala',
    'shared/Rectangle.vala',
    'ui/namespace.vala',
    'ui/Window.vala',
    'rpc/namespace.vala',
  ),
  dependencies: [ocrpc_dep] + meta_mini_deps,
  vala_args: ocrpc_vala_args + meta_mini_vala_args,
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
