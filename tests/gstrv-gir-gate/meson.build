# Isolated prove: gtk-doc GStrv on C → g-ir-scanner → GJS nested arrays.
# Not the product Shell typelib. No GIR merge.
gnome = import('gnome')
gjs = find_program('gjs')

gsr_search_lib = shared_library(
  'gsr-search-1.0',
  files('app-system.c'),
  dependencies: [dependency('gobject-2.0'), dependency('glib-2.0')],
  install: false,
)

gsr_search_gir = gnome.generate_gir(
  gsr_search_lib,
  sources: files('app-system.c', 'app-system.h'),
  namespace: 'GsrSearch',
  nsversion: '1.0',
  identifier_prefix: 'GsrSearch',
  symbol_prefix: 'gsr_search',
  header: 'app-system.h',
  includes: ['GObject-2.0'],
  install: false,
)

test(
  'gstrv-gir-gate',
  find_program('sh'),
  args: [
    files('check.sh'),
    gsr_search_gir[0],
    meson.current_build_dir(),
    files('check.js'),
  ],
  depends: [gsr_search_lib, gsr_search_gir[0], gsr_search_gir[1]],
)
