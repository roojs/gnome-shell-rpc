# Isolated prove: valac writes GsrSearch-1.0.gir (stamp, never installed).
# gir-inject-placeholder.sh writes GsrSearch-1.0.injected.gir (typelib / install).

inject_sh = meson.project_source_root() / 'scripts' / 'gir-inject-placeholder.sh'
g_ir_compiler = find_program('g-ir-compiler')
sh = find_program('sh')
gjs = find_program('gjs')

gsr_search_lib = shared_library(
  'gsr-search-1.0',
  files('app-system.vala', 'app-system-search.c'),
  dependencies: [dependency('gobject-2.0'), dependency('glib-2.0')],
  vala_args: ['--pkg=gobject-2.0'],
  vala_gir: 'GsrSearch-1.0.gir',
  install: false,
)

gsr_search_gir = custom_target(
  'GsrSearch-1.0.injected.gir',
  output: 'GsrSearch-1.0.injected.gir',
  command: [
    sh,
    inject_sh,
    meson.current_build_dir() / 'GsrSearch-1.0.gir',
    files('search.function.gir'),
    '@OUTPUT@',
  ],
  depends: [gsr_search_lib],
  build_by_default: true,
  install: false,
)

gsr_search_typelib = custom_target(
  'GsrSearch-1.0.typelib',
  output: 'GsrSearch-1.0.typelib',
  command: [
    g_ir_compiler,
    '--output', '@OUTPUT@',
    '--shared-library', 'libgsr-search-1.0.so',
    gsr_search_gir,
  ],
  depends: [gsr_search_lib],
  build_by_default: true,
)

test(
  'gstrv-gir-gate',
  find_program('sh'),
  args: [
    files('check.sh'),
    gsr_search_gir,
    meson.current_build_dir(),
    files('check.js'),
  ],
  depends: [gsr_search_lib, gsr_search_gir, gsr_search_typelib],
)
