# Generate libmutter Vala bindings from the installed mutter GIR (Gala recipe).
# Do not vendor a frozen libmutter.vapi.

vapigen_args = [
  '--directory=@0@'.format(meson.current_build_dir()),
  '--metadatadir=@0@'.format(meson.current_source_dir()),
  '--girdir=@0@'.format(mutter_typelib_dir),
  '--vapidir=@0@'.format(meson.current_build_dir()),
  '--vapidir=@0@'.format(meson.current_source_dir()),
]

mtk_target = custom_target('mutter-mtk-16',
  command: [
    vapigen,
    mutter_typelib_dir / 'Mtk-16.gir',
    '--library=mutter-mtk-16',
    '--pkg=gobject-2.0',
    '--pkg=gio-2.0',
    '--pkg=cairo',
    '--pkg=graphene-gobject-1.0',
    vapigen_args,
  ],
  output: 'mutter-mtk-16.vapi',
)

cogl_target = custom_target('mutter-cogl-16',
  command: [
    vapigen,
    mutter_typelib_dir / 'Cogl-16.gir',
    '--library=mutter-cogl-16',
    '--pkg=mutter-mtk-16',
    '--pkg=gobject-2.0',
    '--pkg=gio-2.0',
    '--pkg=cairo',
    '--pkg=graphene-gobject-1.0',
    '--pkg=x11',
    vapigen_args,
    files('Cogl-16-custom.vala'),
  ],
  depends: mtk_target,
  output: 'mutter-cogl-16.vapi',
)

clutter_target = custom_target('mutter-clutter-16',
  command: [
    vapigen,
    mutter_typelib_dir / 'Clutter-16.gir',
    '--library=mutter-clutter-16',
    '--pkg=graphene-gobject-1.0',
    '--pkg=mutter-mtk-16',
    '--pkg=mutter-cogl-16',
    '--pkg=atk',
    '--pkg=gio-2.0',
    '--pkg=json-glib-1.0',
    '--pkg=pango',
    '--pkg=x11',
    vapigen_args,
  ],
  depends: [cogl_target, mtk_target],
  output: 'mutter-clutter-16.vapi',
)

libmutter_target = custom_target('libmutter-16',
  command: [
    vapigen,
    mutter_typelib_dir / 'Meta-16.gir',
    '--library=libmutter-16',
    '--pkg=graphene-gobject-1.0',
    '--pkg=mutter-cogl-16',
    '--pkg=mutter-clutter-16',
    '--pkg=atk',
    '--pkg=gio-2.0',
    '--pkg=json-glib-1.0',
    '--pkg=pango',
    '--pkg=x11',
    '--pkg=xfixes-4.0',
    vapigen_args,
  ],
  depend_files: files('Meta-16.metadata'),
  depends: [cogl_target, clutter_target],
  output: 'libmutter-16.vapi',
)

# vapigen does not write .deps; copy ours next to the generated vapis.
mutter_vapi_stamp = custom_target('mutter-vapi-stamp',
  command: [
    'sh', '-c',
    'cp "$1"/*.deps "$2" && touch "$3"',
    'sh',
    meson.current_source_dir(),
    meson.current_build_dir(),
    '@OUTPUT@',
  ],
  depends: [libmutter_target, clutter_target, cogl_target, mtk_target],
  output: 'mutter-vapi-stamp.c',
)
