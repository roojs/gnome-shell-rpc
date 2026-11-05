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

subdir('generator')

# Client libraries live under src/client/. Typelibs stay in this file so
# they are written to build/src, next to gsr-client and gsr-server.
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

subdir('client')

# Build-tree pc stays in build/src. The .so is in the Clutter build dir.
# The typelib is still written here.
pkg = import('pkgconfig')
configure_file(
  input: 'libmutter-clutter-rpc-16.pc.in',
  output: 'libmutter-clutter-rpc-' + mutter_api_version + '.pc',
  configuration: {
    'prefix': meson.project_build_root(),
    'libdir': clutter_rpc_build_dir,
    'includedir': mutter_clutter_rpc_incdir,
    'typelibdir': meson.current_build_dir(),
    'girdir': mutter_typelib_dir,
    'dep_cflags': ' '.join(mutter_clutter_dep_cflags),
    'version': meson.project_version(),
    'MUTTER_API_VERSION': mutter_api_version,
  },
)
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
    '--includedir', shell_build_dir,
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

# build/src/gsr-client and build/src/gsr-smoke stay as links. The programs
# themselves are built by src/client/meson.build. gi-rpc-smoke.sh opens
# these paths.
custom_target(
  'gsr-client-link',
  output: 'gsr-client',
  command: ['ln', '-sfn', 'client/gsr-client', '@OUTPUT@'],
  depends: [gnome_shell_rpc, shell_gi_typelib, mutter_rpc_typelib, clutter_rpc_typelib, st_rpc_typelib, gsr_rpc_subprocess_typelib],
  build_by_default: true,
)
custom_target(
  'gsr-smoke-link',
  output: 'gsr-smoke',
  command: ['ln', '-sfn', 'client/gsr-smoke', '@OUTPUT@'],
  depends: [gsr_smoke, shell_gi_typelib, mutter_rpc_typelib, clutter_rpc_typelib, st_rpc_typelib, gsr_rpc_subprocess_typelib],
  build_by_default: true,
)

configure_file(
  input: 'libst-rpc-16.pc.in',
  output: 'libst-rpc-' + mutter_api_version + '.pc',
  configuration: {
    'prefix': meson.project_build_root(),
    'libdir': st_rpc_build_dir,
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

# Build-tree pc (PKG_CONFIG_PATH=build/src). The typelib stays in this
# directory. The .so is in the Meta library build dir.
configure_file(
  input: 'libmutter-rpc-16.pc.in',
  output: 'libmutter-rpc-' + mutter_api_version + '.pc',
  configuration: {
    'prefix': meson.project_build_root(),
    'libdir': meta_rpc_build_dir,
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

# Shared sources for rpc-client and fake-shell. Those programs compile their
# own files from tests/, where a second namespace.vala or Window.vala would
# collide under Vala's --basedir. gsr-server links this library: compiling
# shared/namespace.vala in src/server/ would overwrite server/namespace.vala.
gsr_shared_lib = static_library(
  'gsr-shared',
  files(
    'shared/namespace.vala',
    'shared/Rectangle.vala',
    'shared/ClutterEventState.vala',
    'shared/Window.vala',
    'shared/Workspace.vala',
  ),
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  vala_header: 'gsr-shared.h',
  vala_vapi: 'gsr-shared.vapi',
  install: false,
)

subdir('server')

# The nest opens build/src/gsr-server and takes the typelib directory from
# that path. The real program is build/src/server/gsr-server. Typelibs stay
# in this directory, so the link's directory is the one the script uses.
custom_target(
  'gsr-server-link',
  output: 'gsr-server',
  command: ['ln', '-sfn', 'server/gsr-server', '@OUTPUT@'],
  depends: [mutter_rpc],
  build_by_default: true,
)
