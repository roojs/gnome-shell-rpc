project('gnome-shell-rpc', 'vala', 'c',
  version: '0.1.0',
  meson_version: '>= 0.59.0',
  default_options: [
    'warning_level=1',
    'prefix=/usr',
  ],
)

vala = meson.get_compiler('vala')
cc = meson.get_compiler('c')
fs = import('fs')

add_project_arguments([
  '--target-glib=2.78',
], language: 'vala')

libmutter_dep = dependency('libmutter-16', version: '>= 48')
mutter_dep = [
  libmutter_dep,
  dependency('mutter-mtk-16'),
  dependency('mutter-cogl-16'),
  dependency('mutter-clutter-16'),
  dependency('gio-2.0'),
  dependency('gobject-2.0'),
  dependency('glib-2.0'),
  dependency('atk'),
  dependency('graphene-gobject-1.0'),
  dependency('pango'),
  dependency('cairo'),
  dependency('x11'),
  dependency('json-glib-1.0'),
]

mutter_typelib_dir = libmutter_dep.get_variable('typelibdir')
add_project_link_arguments(['-Wl,-rpath,@0@'.format(mutter_typelib_dir)], language: 'c')

ocrpc_libdir = get_option('ocrpc_libdir')
ocrpc_lib = ocrpc_libdir / 'libocrpc.so'
ocrpc_vapi = ocrpc_libdir / 'ocrpc.vapi'
if not fs.exists(ocrpc_lib) or not fs.exists(ocrpc_vapi)
  warning('libocrpc not found at @0@ — build OLLMchat libocrpc first'.format(ocrpc_libdir))
endif

ocrpc_vala_args = [
  '--pkg=ocrpc',
  '--pkg=json-glib-1.0',
  '--vapidir=' + ocrpc_libdir,
]

ocrpc_dep = declare_dependency(
  dependencies: [
    dependency('gee-0.8'),
    dependency('gio-unix-2.0'),
    dependency('json-glib-1.0'),
    dependency('libsoup-3.0'),
  ],
  link_args: ['-L' + ocrpc_libdir, '-locrpc'],
  compile_args: ['-I' + ocrpc_libdir],
)

ocrpc_rpath = ocrpc_libdir

vapigen = find_program('vapigen', required: true)

subdir('gnome-shell')
subdir('vapi')
subdir('src')
