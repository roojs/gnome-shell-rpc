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
  'rpc/namespace.vala',
  'rpc/Bootstrap.vala',
  'rpc/Daemon.vala',
  'rpc/Listen.vala',
  'rpc/Server.vala',
  'rpc/CancellableBridge.vala',
  'rpc/helper/namespace.vala',
  'rpc/helper/SoundPlayer.vala',
  'rpc/helper/Background.vala',
  'rpc/helper/BackgroundActor.vala',
  'rpc/helper/Context.vala',
  'rpc/helper/Settings.vala',
  'rpc/helper/IdleMonitor.vala',
  'rpc/helper/Display.vala',
  'rpc/helper/Window.vala',
  'rpc/helper/WindowActor.vala',
  'rpc/helper/Devices.vala',
  'rpc/helper/Selection.vala',
  'rpc/helper/SelectionSource.vala',
  'rpc/helper/SelectionSourceMemory.vala',
  'rpc/helper/ShapedTexture.vala',
  'rpc/helper/ShaderEffect.vala',
  'rpc/helper/GLSLEffect.vala',
  'rpc/helper/ClutterThreads.vala',
  'rpc/helper/ClutterActor.vala',
  'rpc/helper/ClutterStage.vala',
  'rpc/helper/shader-uniform-apply.c',
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

# Legacy client Shell/St from vendor; disabled by default (Phase C uses St RPC stubs).
mutter_rpc_gir_name = 'mutter-rpc-16'
gnome_shell_client_libdir = meson.project_build_root() / 'gnome-shell' / 'client-libs'
gnome_shell_client_typelibdir = get_option('gnome_shell_client_libs').enabled() and gnome_shell_vendor_root != '' ? gnome_shell_client_libdir : ''

gnome_shell_pkglibdir = '/usr/lib/gnome-shell'
gnome_shell_girdir = '/usr/share/gnome-shell'

# Stock libst for mutter-rpc Gi.register("St") — same pkglibdir as typelib.
# Link by absolute path so --no-as-needed is not split from -lst-16 by the linker.
gnome_shell_st_lib = gnome_shell_pkglibdir / 'libst-16.so'
gnome_shell_st_link_args = [
  '-Wl,--push-state',
  '-Wl,--no-as-needed',
  gnome_shell_st_lib,
  '-Wl,--pop-state',
]

rpc_config = configure_file(
  input: 'rpc/Config.vala.in',
  output: 'Config.vala',
  configuration: configuration_data({
    'MUTTER_TYPELIB_DIR': mutter_typelib_dir,
    'GNOME_SHELL_CLIENT_TYPELIB_DIR': gnome_shell_client_typelibdir,
    'GNOME_SHELL_PKGLIBDIR': gnome_shell_pkglibdir,
  }),
)

compositor_rpath = mutter_typelib_dir + ':' + gnome_shell_pkglibdir + ':' + ocrpc_rpath

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

gjs_embed = executable('gjs-embed',
  gjs_shell_sources,
  gjs_embed_config,
  dependencies: gjs_shell_deps,
  vala_args: gjs_shell_vala_args,
  install: false,
)

gnome_shell_rpc_config = configure_file(
  input: 'gjs-embed/Config.vala.in',
  output: 'GnomeShellRpcConfig.vala',
  configuration: configuration_data({
    'GNOME_SHELL_JS_DIR': gnome_shell_js_runtime_dir,
    'APPLICATION_ID': 'org.gnome.ShellRpc',
  }),
)

g_ir_compiler = find_program('g-ir-compiler')

gi_stub_gen = executable('gi-stub-gen',
  files(
    'ApplicationInterface.vala',
    'gi-stub-gen/namespace.vala',
    'gi-stub-gen/TypelibWalk.vala',
    'gi-stub-gen/HeaderConfig.vala',
    'gi-stub-gen/Generator.vala',
    'gi-stub-gen/HeaderGenerator.vala',
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

# 0.5 GiRpcSmoke toy — optional; product nested path is mutter-rpc + gnome-shell-rpc.
if get_option('legacy_gi_rpc_smoke')
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
      'meta-mini/namespace.vala',
      'meta-mini/Window.vala',
      'meta-mini/WindowActor.vala',
      'meta-mini/Context.vala',
      'meta-mini/Display.vala',
      'meta-mini/Compositor.vala',
      'meta-mini/Backend.vala',
      'meta-mini/StartupNotification.vala',
      'meta-mini/LaunchContext.vala',
      'meta-mini/SoundPlayer.vala',
      'meta-mini/IdleMonitor.vala',
      'gi-stub/PaintedContent.vala',
      'gi-stub/CancellableBridge.vala',
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
endif

# Client Meta from gi-stub-gen (0.6 Phase 2 / 0.5.2 Phase 9).
# Install layout mirrors mutter: .so in libdir; Meta-16 typelib + GIR in
# ${libdir}/mutter-rpc-16/ — never stock mutter-16 or /usr/share/gir-1.0.
# MUTTER_TL=$(pkg-config --variable=typelibdir libmutter-16)
# GI_TYPELIB_PATH=$(pkg-config --variable=typelibdir libmutter-rpc-16):$MUTTER_TL \
#   ./build/src/gjs-embed --debug src/gjs-embed/meta-smoke.js
mutter_rpc_typelib_install_dir = get_option('libdir') / mutter_rpc_gir_name

meta_deny_file = files('gi-stub-gen/Meta.deny')
meta_overrides_file = files('gi-stub-gen/Meta.overrides')
meta_override_dir = meson.current_source_dir() / 'gi-stub/overrides'
meta_override_files = files(
  'gi-stub/overrides/SoundPlayer.override.vala',
  'gi-stub/overrides/Background.override.vala',
  'gi-stub/overrides/BackgroundActor.override.vala',
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

# C deps for our Clutter/Meta stubs (cogl/atk/…).
# Stock mutter-16/clutter is only for compiling our Clutter .so C gaps
# (varargs shim) until/alongside the Vala header; St uses clutter-rpc incdir.
mutter_clutter_cflags_raw = run_command(
  'pkg-config', '--cflags', 'mutter-clutter-16', check: true,
).stdout().split()
mutter_clutter_dep_cflags = []
mutter_clutter_stock_inc = []
foreach f : mutter_clutter_cflags_raw
  if f.contains('mutter-16/clutter')
    mutter_clutter_stock_inc += f
  else
    mutter_clutter_dep_cflags += f
  endif
endforeach
mutter_clutter_cflags = mutter_clutter_dep_cflags

clutter_deny_file = files('gi-stub-gen/Clutter.deny')
clutter_overrides_file = files('gi-stub-gen/Clutter.overrides')
clutter_override_dir = meson.current_source_dir() / 'gi-stub/overrides-clutter'
clutter_override_files = files(
  'gi-stub/overrides-clutter/Clutter.override.vala',
  'gi-stub/overrides-clutter/Stage.override.vala',
  'gi-stub/overrides-clutter/Actor.override.vala',
  'gi-stub/overrides-clutter/ActorIter.override.vala',
  'gi-stub/overrides-clutter/Backend.override.vala',
  'gi-stub/overrides-clutter/PipelineNode.override.vala',
  'gi-stub/overrides-clutter/PaintContext.override.vala',
  'gi-stub/overrides-clutter/PaintNode.override.vala',
)
clutter_generated = custom_target('Clutter_generated.vala',
  output: 'Clutter_generated.vala',
  command: [
    gi_stub_gen,
    '--out=@OUTPUT@',
    '--missing-out=' + meson.current_build_dir() / 'Clutter_generated.missing.md',
    '--typelib-dir=' + mutter_typelib_dir,
    '--deny-file=@INPUT0@',
    '--overrides-file=@INPUT1@',
    '--override-path=' + clutter_override_dir,
    'emit', 'Clutter', '16',
  ],
  input: [clutter_deny_file, clutter_overrides_file] + clutter_override_files,
  depends: [gi_stub_gen],
  build_by_default: true,
)

# Stub Clutter (separate from Meta — stock-like mutter-clutter split).
mutter_clutter_rpc_gir_name = 'mutter-clutter-rpc-16'
mutter_clutter_rpc_incdir = meson.current_build_dir() / 'clutter-include'

mutter_clutter_rpc_lib = shared_library(
  'mutter-clutter-rpc-16',
  clutter_generated,
  files(
    'gi-stub/namespace.vala',
    'gi-stub/Runtime.vala',
    'gi-stub/CancellableBridge.vala',
    'gi-stub/ShaderEffectUniform.vala',
    'gi-stub/ClutterStageAbi.vala',
    'gi-stub/ClutterEffectRelay.vala',
    'gi-stub/c-clutter-st-abi-gaps.c',
    'gi-stub/c-clutter-effect-abi.c',
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
    dependency('atk'),
    dependency('pango'),
    dependency('graphene-gobject-1.0'),
    dependency('mutter-cogl-16'),
    dependency('mutter-mtk-16'),
  ],
  vala_args: ocrpc_vala_args + [
    '--pkg=posix',
    '--pkg=gdesktopenums-3.0',
    '--pkg=atk',
    '--pkg=pango',
    '--pkg=mutter-cogl-16',
    '--pkg=mutter-mtk-16',
    '--vapidir', meson.current_source_dir() / 'gi-stub',
    '--pkg=gsr-clutter-effect-abi',
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + meson.current_source_dir() / 'gi-stub',
  ] + mutter_clutter_cflags + mutter_clutter_stock_inc,
  # meta_register() is defined in libmutter-rpc-16 (lazy-bound on first Runtime.register).
  link_args: ['-Wl,--unresolved-symbols=ignore-all'],
  vala_header: 'mutter-clutter-rpc-16.h',
  vala_vapi: 'mutter-clutter-rpc-16.vapi',
  build_rpath: ocrpc_rpath,
  install: true,
)

# Generator-owned stock-shaped clutter/ tree (0.7.4).
clutter_headers_config = files('gi-stub-gen/Clutter.headers')
clutter_header_override_files = files(
  'gi-stub-gen/header-overrides/Event.h',
  'gi-stub-gen/header-overrides/ActorBox.h',
  'gi-stub-gen/header-overrides/ActorIter.h',
  'gi-stub-gen/header-overrides/Actor.methods.h',
  'gi-stub-gen/header-overrides/Interval.methods.h',
  'gi-stub-gen/header-overrides/PaintContext.methods.h',
  'gi-stub-gen/header-overrides/PaintNode.methods.h',
  'gi-stub-gen/header-overrides/ShaderEffect.methods.h',
  'gi-stub-gen/header-overrides/Stage.methods.h',
  'gi-stub-gen/header-overrides/TextBuffer.h',
  'gi-stub-gen/header-overrides/TextBuffer.methods.h',
  'gi-stub-gen/header-overrides/clutter-keysyms.h',
  'gi-stub-gen/header-overrides/clutter-macros.h',
  'gi-stub-gen/header-overrides/clutter-main.h',
  'gi-stub-gen/header-overrides/clutter-pango.h',
  'gi-stub-gen/header-overrides/pango/clutter-actor-pango.h',
  'gi-stub-gen/header-overrides/pango/clutter-text.h',
  'gi-stub-gen/header-overrides/pango/clutter-text-buffer.h',
  'gi-stub-gen/header-overrides/pango/clutter-text-node.h',
)
stage_clutter_headers = custom_target(
  'clutter-rpc-headers',
  output: 'clutter-headers.stamp',
  input: [clutter_headers_config] + clutter_header_override_files,
  command: [
    'sh', '-c',
    'mkdir -p "$2" && "$1" --typelib-dir="$3" --outdir="$2" --headers-config="$4" emit-headers Clutter 16 && touch "$5"',
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
  'mkdir -p "$2" && cp -a "$1/." "$2/"',
  mutter_clutter_rpc_incdir,
  get_option('prefix') / get_option('includedir') / mutter_clutter_rpc_gir_name,
)

configure_file(
  input: 'libmutter-clutter-rpc-16.pc.in',
  output: 'libmutter-clutter-rpc-16.pc',
  configuration: {
    'prefix': meson.project_build_root(),
    'libdir': meson.current_build_dir(),
    'includedir': mutter_clutter_rpc_incdir,
    'typelibdir': meson.current_build_dir(),
    'girdir': mutter_typelib_dir,
    'dep_cflags': ' '.join(mutter_clutter_dep_cflags),
    'version': meson.project_version(),
  },
)

pkg = import('pkgconfig')
pkg.generate(
  mutter_clutter_rpc_lib,
  filebase: 'libmutter-clutter-rpc-16',
  name: 'mutter-clutter-rpc',
  description: 'Mutter-shaped RPC Clutter client (Vala stubs)',
  requires: [
    'gio-2.0',
    'gobject-2.0',
    'atk',
    'pango',
    'mutter-cogl-16',
    'mutter-mtk-16',
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
    ocrpc_dep,
    dependency('gee-0.8'),
    dependency('mutter-mtk-16'),
    dependency('mutter-cogl-16'),
    dependency('atk'),
    dependency('pango'),
  ],
)

# St / Shell clients: generated clutter/ tree only (0.7.4).
mutter_clutter_rpc_client_dep = declare_dependency(
  dependencies: [mutter_clutter_rpc_link_dep],
  compile_args: [
    '-I' + mutter_clutter_rpc_incdir,
    '-I' + meson.current_source_dir() / 'gi-stub',
  ] + mutter_clutter_dep_cflags,
  sources: [stage_clutter_headers],
)

# Client Meta stubs (RPC); Clutter + Runtime + Shared/Ui wire types are in clutter-rpc.
# c-meta-shell-gaps includes stock meta/*.h → needs stock clutter/ on -I, and must
# NOT see -include mutter-clutter-rpc-16.h (Vala) or generated clutter-include.
gsr_meta_shell_gaps = static_library(
  'gsr-meta-shell-gaps',
  'gi-stub/c-meta-shell-gaps.c',
  c_args: [
    '-I' + mutter_includedir,
  ] + mutter_clutter_stock_inc + mutter_clutter_dep_cflags,
  dependencies: [
    dependency('glib-2.0'),
    dependency('x11'),
  ],
)

mutter_rpc_lib = shared_library('mutter-rpc-16',
  meta_window_generated,
  files(
    'gi-stub/namespace.vala',
    'gi-stub/PaintedContent.vala',
    'gi-stub/MetaSettingsAbi.vala',
  ),
  mutter_vapi_stamp,
  dependencies: [
    ocrpc_dep,
    mutter_clutter_rpc_link_dep,
    dependency('gio-2.0'),
    dependency('cairo'),
    dependency('atk'),
    dependency('pango'),
    dependency('graphene-gobject-1.0'),
    dependency('mutter-cogl-16'),
    dependency('mutter-mtk-16'),
    dependency('x11'),
  ],
  link_whole: gsr_meta_shell_gaps,
  vala_args: ocrpc_vala_args + [
    '--pkg=posix',
    '--pkg=gdesktopenums-3.0',
    '--pkg=atk',
    '--pkg=pango',
    '--pkg=mutter-cogl-16',
    '--pkg=mutter-mtk-16',
    '--vapidir', meson.current_source_dir() / 'gi-stub',
    '--pkg=gsr-clutter-effect-abi',
    '--pkg=mutter-clutter-rpc-16',
    '--vapidir', meson.current_build_dir(),
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + mutter_includedir,
    '-I' + meson.current_source_dir() / 'gi-stub',
    # Vala Clutter types for Meta .c — not the generated clutter-include tree.
    '-include', 'mutter-clutter-rpc-16.h',
  ] + mutter_clutter_cflags,
  build_rpath: ocrpc_rpath + ':' + meson.current_build_dir(),
  link_args: ['-L' + mutter_typelib_dir],
  vala_header: 'mutter-rpc-16.h',
  vala_vapi: 'mutter-rpc-16.vapi',
  install: true,
)

# mutter_rpc_client_dep is declared after st_rpc_lib (Clutter Runtime needs st_register).

# Stock Meta GIR, shared-library → our stub .so (same pattern as Clutter).
# Hand meta-mini/Meta-16.gir stays for docs / early smokes; typelib must list
# Background etc. for init.js.
mutter_meta_gir = mutter_typelib_dir / 'Meta-16.gir'
mutter_rpc_typelib = custom_target('Meta-16.typelib',
  output: 'Meta-16.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libmutter-rpc-16.so',
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
mutter_clutter_gir = mutter_typelib_dir / 'Clutter-16.gir'
clutter_rpc_typelib = custom_target('Clutter-16.typelib',
  output: 'Clutter-16.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libmutter-clutter-rpc-16.so',
    '--includedir', mutter_typelib_dir,
    mutter_clutter_gir,
  ],
  depends: [mutter_clutter_rpc_lib],
  build_by_default: true,
  install: true,
  install_dir: mutter_rpc_typelib_install_dir,
)

st_deny_file = files('gi-stub-gen/St.deny')
st_overrides_file = files('gi-stub-gen/St.overrides')
st_override_dir = meson.current_source_dir() / 'gi-stub/overrides-st'
st_generated = custom_target('St_generated.vala',
  output: 'St_generated.vala',
  command: [
    gi_stub_gen,
    '--out=@OUTPUT@',
    '--missing-out=' + meson.current_build_dir() / 'St_generated.missing.md',
    '--typelib-dir=' + gnome_shell_pkglibdir + ':' + mutter_typelib_dir,
    '--deny-file=@INPUT0@',
    '--overrides-file=@INPUT1@',
    '--override-path=' + st_override_dir,
    'emit', 'St', '16',
  ],
  input: [st_deny_file, st_overrides_file] + files(
    'gi-stub/overrides-st/Widget.override.vala',
    'gi-stub/overrides-st/ThemeContext.override.vala',
    'gi-stub/overrides-st/FocusManager.override.vala',
    'gi-stub/overrides-st/Settings.override.vala',
  ),
  depends: [gi_stub_gen],
  build_by_default: true,
)

st_rpc_gir_name = 'st-rpc-16'
st_rpc_lib = shared_library(
  'st-rpc-16',
  st_generated,
  files('gi-stub/namespace.vala'),
  dependencies: [
    ocrpc_dep,
    mutter_clutter_rpc_link_dep,
    dependency('gio-2.0'),
    dependency('gdk-pixbuf-2.0'),
    dependency('cairo'),
    dependency('graphene-gobject-1.0'),
    dependency('mutter-cogl-16'),
    dependency('mutter-mtk-16'),
  ],
  vala_args: ocrpc_vala_args + [
    '--pkg=posix',
    '--pkg=gdk-pixbuf-2.0',
    '--pkg=mutter-cogl-16',
    '--pkg=mutter-mtk-16',
    '--pkg=mutter-clutter-rpc-16',
    '--vapidir', meson.current_source_dir() / 'gi-stub',
    '--pkg=gsr-clutter-effect-abi',
    '--vapidir', meson.current_build_dir(),
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + meson.current_source_dir() / 'gi-stub',
    '-include', 'mutter-clutter-rpc-16.h',
  ],
  link_args: ['-L' + meson.current_build_dir(), '-lmutter-rpc-16'],
  link_depends: [mutter_clutter_rpc_lib, mutter_rpc_lib],
  build_rpath: ocrpc_rpath + ':' + meson.current_build_dir(),
  vala_header: 'st-rpc-16.h',
  vala_vapi: 'st-rpc-16.vapi',
  install: true,
)

mutter_rpc_client_dep = declare_dependency(
  link_with: [mutter_rpc_lib, st_rpc_lib],
  dependencies: [
    mutter_clutter_rpc_client_dep,
    dependency('mutter-mtk-16'),
    dependency('mutter-cogl-16'),
    dependency('atk'),
    dependency('pango'),
  ],
  compile_args: ['-I' + mutter_includedir],
)

# 0.7.7 — owned Shell-16 facade (not libshell). GIR from Vala (vala_gir).
shell_gi_lib = shared_library(
  'shell-gi-16',
  files(
    'shell-gi/namespace.vala',
    'shell-gi/ActionMode.vala',
    'shell-gi/Util.vala',
    'shell-gi/App.vala',
    'shell-gi/GLSLEffect.vala',
    'shell-gi/SquareBin.vala',
    'shell-gi/WindowPreview.vala',
    'shell-gi/WorkspaceBackground.vala',
    'shell-gi/Screenshot.vala',
    'shell-gi/Global.vala',
  ),
  dependencies: [
    ocrpc_dep,
    declare_dependency(
      link_with: [mutter_rpc_lib, st_rpc_lib],
      dependencies: [
        mutter_clutter_rpc_client_dep,
        dependency('mutter-mtk-16'),
        dependency('mutter-cogl-16'),
        dependency('atk'),
        dependency('pango'),
        dependency('gdk-pixbuf-2.0'),
      ],
      compile_args: ['-I' + mutter_includedir],
    ),
  ],
  vala_args: ocrpc_vala_args + [
    '--pkg=gio-2.0',
    '--pkg=gdesktopenums-3.0',
    '--pkg=gsr-clutter-effect-abi',
    '--pkg=gdk-pixbuf-2.0',
    '--pkg=mutter-rpc-16',
    '--pkg=mutter-clutter-rpc-16',
    '--pkg=st-rpc-16',
    '--pkg=mutter-cogl-16',
    '--pkg=mutter-mtk-16',
    '--pkg=atk',
    '--pkg=pango',
    '--pkg=graphene-gobject-1.0',
    '--vapidir', meson.current_source_dir() / 'gi-stub',
    '--vapidir', meson.current_build_dir(),
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + mutter_includedir,
    '-I' + meson.current_source_dir() / 'gi-stub',
    '-I' + meson.current_build_dir(),
    '-include', 'mutter-clutter-rpc-16.h',
  ] + mutter_clutter_cflags,
  build_rpath: ocrpc_rpath + ':' + meson.current_build_dir(),
  vala_header: 'shell-gi-16.h',
  vala_vapi: 'shell-gi-16.vapi',
  vala_gir: 'Shell-16.gir',
  install: false,
)

shell_gi_typelib = custom_target(
  'Shell-16.typelib',
  input: meson.current_build_dir() / 'Shell-16.gir',
  output: 'Shell-16.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libshell-gi-16.so',
    '--includedir', mutter_typelib_dir,
    '--includedir', gnome_shell_girdir,
    '--includedir', meson.current_build_dir(),
    '@INPUT@',
  ],
  depends: [shell_gi_lib],
  build_by_default: true,
  install: false,
)

# 0.7.7 S1 — JS gresource (vendor tree + substituted misc/config.js).
gnome = import('gnome')
vendor_js_dir = gnome_shell_vendor_root / 'js'
vendor_data_dir = gnome_shell_vendor_root / 'data'
generate_app_list = find_program(
  gnome_shell_vendor_root / 'meson' / 'generate-app-list.py',
)
subdir('shell-js')
st_gir = gnome_shell_girdir / 'St-16.gir'
st_rpc_typelib = custom_target('St-16.typelib',
  output: 'St-16.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libst-rpc-16.so',
    '--includedir', mutter_typelib_dir,
    '--includedir', gnome_shell_girdir,
    st_gir,
  ],
  depends: [st_rpc_lib],
  build_by_default: true,
  install: true,
  install_dir: mutter_rpc_typelib_install_dir,
)

# Thin gnome-shell-rpc host (no libshell / no client libst).
# Link st-rpc for Runtime.st_register without --pkg/st vapi (Gdk noise).
gnome_shell_rpc = executable('gnome-shell-rpc',
  files(
    'ApplicationInterface.vala',
    'shell-client/namespace.vala',
    'shell-client/ShellApplication.vala',
  ) + shell_js_resources,
  dependencies: gjs_shell_deps + [
    ocrpc_dep,
    dependency('gdk-pixbuf-2.0'),
    declare_dependency(
      link_with: [mutter_rpc_lib, mutter_clutter_rpc_lib, shell_gi_lib],
      dependencies: [
        dependency('mutter-mtk-16'),
        dependency('mutter-cogl-16'),
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
    '--pkg=mutter-rpc-16',
    '--pkg=mutter-clutter-rpc-16',
    '--pkg=st-rpc-16',
    '--pkg=shell-gi-16',
    '--pkg=mutter-cogl-16',
    '--pkg=mutter-mtk-16',
    '--pkg=atk',
    '--pkg=pango',
    '--vapidir', meson.current_build_dir(),
    '--vapidir', meson.current_source_dir() / 'gi-stub',
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + mutter_includedir,
    '-I' + meson.current_source_dir() / 'gi-stub',
    '-I' + meson.current_build_dir(),
    '-include', 'mutter-clutter-rpc-16.h',
  ] + mutter_clutter_cflags,
  link_args: ['-L' + meson.current_build_dir(), '-lst-rpc-16'],
  link_depends: [
    st_rpc_lib,
    shell_gi_typelib,
    mutter_rpc_typelib,
    clutter_rpc_typelib,
    st_rpc_typelib,
  ],
  build_rpath: ocrpc_rpath + ':' + meson.current_build_dir(),
  install: false,
)

configure_file(
  input: 'libst-rpc-16.pc.in',
  output: 'libst-rpc-16.pc',
  configuration: {
    'prefix': meson.project_build_root(),
    'libdir': meson.current_build_dir(),
    'typelibdir': meson.current_build_dir(),
    'girdir': gnome_shell_girdir,
    'version': meson.project_version(),
  },
)

pkg.generate(
  st_rpc_lib,
  filebase: 'libst-rpc-16',
  name: 'libst-rpc',
  description: 'St-shaped RPC client (Vala stubs)',
  requires: [
    'gio-2.0',
    'gobject-2.0',
    'mutter-cogl-16',
    'mutter-mtk-16',
    'libmutter-clutter-rpc-16',
  ],
  variables: [
    'typelibdir=${libdir}/' + mutter_rpc_gir_name,
    'girdir=${libdir}/' + mutter_rpc_gir_name,
  ],
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
    'clientlibdir': gnome_shell_client_libdir,
    'mutter_includedir': mutter_includedir,
    'version': meson.project_version(),
  },
)

# Installed pc.
pkg.generate(
  mutter_rpc_lib,
  filebase: 'libmutter-rpc-16',
  name: 'mutter-rpc',
  description: 'Mutter-shaped RPC client (GJS + C Meta-16)',
  requires: [
    'gio-2.0',
    'gobject-2.0',
    'atk',
    'pango',
    'mutter-cogl-16',
    'mutter-mtk-16',
    'libmutter-clutter-rpc-16',
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
      'gi-stub/namespace.vala',
      'gi-stub/Runtime.vala',
      'meta-mini/namespace.vala',
      'meta-mini/Window.vala',
      'meta-mini/WindowActor.vala',
      'meta-mini/Context.vala',
      'meta-mini/Display.vala',
      'meta-mini/Compositor.vala',
      'meta-mini/Backend.vala',
      'meta-mini/StartupNotification.vala',
      'meta-mini/LaunchContext.vala',
      'meta-mini/SoundPlayer.vala',
      'meta-mini/IdleMonitor.vala',
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
endif

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

if get_option('gnome_shell_client_libs').enabled() and gnome_shell_vendor_root != ''
  # Legacy vendored libshell/libst — optional comparison only (0.7.7 default host is thin).
endif

mutter_rpc = executable('mutter-rpc',
  compositor_sources,
  rpc_config,
  mutter_vapi_stamp,
  dependencies: [
    mutter_dep,
    ocrpc_dep,
    dependency('gobject-introspection-1.0'),
  ],
  vala_args: mutter_vala_args + ocrpc_vala_args,
  link_args: gnome_shell_st_link_args,
  build_rpath: compositor_rpath,
  export_dynamic: true,
  install: false,
)
