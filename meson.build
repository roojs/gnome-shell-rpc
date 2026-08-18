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

vapigen = find_program('vapigen', required: true)

subdir('vapi')
subdir('src')
