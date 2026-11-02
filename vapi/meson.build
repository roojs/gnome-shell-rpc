# Generate libmutter Vala bindings from the installed mutter GIR (Gala recipe).
# Do not vendor a frozen libmutter.vapi.

mutter_dep_conf = {'MUTTER_API_VERSION': mutter_api_version}
configure_file(
  input: 'mutter-mtk-16.deps',
  output: 'mutter-mtk-@0@.deps'.format(mutter_api_version),
  configuration: mutter_dep_conf,
)
configure_file(
  input: 'mutter-cogl-16.deps',
  output: 'mutter-cogl-@0@.deps'.format(mutter_api_version),
  configuration: mutter_dep_conf,
)
configure_file(
  input: 'mutter-clutter-16.deps',
  output: 'mutter-clutter-@0@.deps'.format(mutter_api_version),
  configuration: mutter_dep_conf,
)
configure_file(
  input: 'libmutter-16.deps',
  output: 'libmutter-@0@.deps'.format(mutter_api_version),
  configuration: mutter_dep_conf,
)
configure_file(
  input: 'st-widget-peer.deps',
  output: 'st-widget-peer.deps',
  configuration: mutter_dep_conf,
)
# Vala reads the .deps beside the .vapi it opened. The configured
# .deps is in this build dir, so the .vapi has to be here too.
# configure_file will not emit a .vapi that shares the source name.
# This copy is not a Vala source. Compiling it duplicates St types.
st_widget_peer_vapi = custom_target(
  'st-widget-peer-vapi-copy',
  input: 'st-widget-peer.vapi',
  output: 'st-widget-peer.vapi',
  command: ['cp', '@INPUT@', '@OUTPUT@'],
  build_by_default: true,
)

# vapigen loads <Namespace>-<version>.metadata. The files on disk are the -16
# names; copy them to the mutter version this configure is building.
mtk_metadata = configure_file(
  input: 'Mtk-16.metadata',
  output: 'Mtk-@0@.metadata'.format(mutter_api_version),
  configuration: mutter_dep_conf,
)
cogl_metadata = configure_file(
  input: 'Cogl-16.metadata',
  output: 'Cogl-@0@.metadata'.format(mutter_api_version),
  configuration: mutter_dep_conf,
)
clutter_metadata = configure_file(
  input: 'Clutter-16.metadata',
  output: 'Clutter-@0@.metadata'.format(mutter_api_version),
  configuration: mutter_dep_conf,
)
meta_metadata = configure_file(
  input: 'Meta-16.metadata',
  output: 'Meta-@0@.metadata'.format(mutter_api_version),
  configuration: mutter_dep_conf,
)

vapigen_args = [
  '--directory=@0@'.format(meson.current_build_dir()),
  '--metadatadir=@0@'.format(meson.current_build_dir()),
  '--metadatadir=@0@'.format(meson.current_source_dir()),
  '--girdir=@0@'.format(mutter_typelib_dir),
  '--vapidir=@0@'.format(meson.current_build_dir()),
  '--vapidir=@0@'.format(meson.current_source_dir()),
]

mtk_target = custom_target('mutter-mtk-16',
  command: [
    vapigen,
    mutter_typelib_dir / 'Mtk-@0@.gir'.format(mutter_api_version),
    '--library=mutter-mtk-' + mutter_api_version,
    '--pkg=gobject-2.0',
    '--pkg=gio-2.0',
    '--pkg=cairo',
    '--pkg=graphene-gobject-1.0',
    vapigen_args,
  ],
  depend_files: [mtk_metadata],
  output: 'mutter-mtk-' + mutter_api_version + '.vapi',
)

cogl_target = custom_target('mutter-cogl-16',
  command: [
    vapigen,
    mutter_typelib_dir / 'Cogl-@0@.gir'.format(mutter_api_version),
    '--library=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--pkg=gobject-2.0',
    '--pkg=gio-2.0',
    '--pkg=cairo',
    '--pkg=graphene-gobject-1.0',
    '--pkg=x11',
    vapigen_args,
    files('Cogl-16-custom.vala'),
  ],
  depend_files: [cogl_metadata, files('Cogl-16-custom.vala')],
  depends: mtk_target,
  output: 'mutter-cogl-' + mutter_api_version + '.vapi',
)

clutter_target = custom_target('mutter-clutter-16',
  command: [
    vapigen,
    mutter_typelib_dir / 'Clutter-@0@.gir'.format(mutter_api_version),
    '--library=mutter-clutter-' + mutter_api_version,
    '--pkg=graphene-gobject-1.0',
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=atk',
    '--pkg=gio-2.0',
    '--pkg=json-glib-1.0',
    '--pkg=pango',
    '--pkg=x11',
    vapigen_args,
  ],
  depend_files: [clutter_metadata],
  depends: [cogl_target, mtk_target],
  output: 'mutter-clutter-' + mutter_api_version + '.vapi',
)

libmutter_target = custom_target('libmutter-16',
  command: [
    vapigen,
    mutter_typelib_dir / 'Meta-@0@.gir'.format(mutter_api_version),
    '--library=libmutter-' + mutter_api_version,
    '--pkg=graphene-gobject-1.0',
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-clutter-' + mutter_api_version,
    '--pkg=atk',
    '--pkg=gio-2.0',
    '--pkg=json-glib-1.0',
    '--pkg=pango',
    '--pkg=x11',
    '--pkg=xfixes-4.0',
    vapigen_args,
  ],
  depend_files: [meta_metadata],
  depends: [cogl_target, clutter_target],
  output: 'libmutter-' + mutter_api_version + '.vapi',
)

# vapigen does not write .deps; copy ours next to the generated vapis.
# Output a .vapi marker so declare_dependency(sources:) orders *valac* (a .c stamp
# only ordered the C compile, so mutter-rpc raced and failed with "Package not found").
mutter_vapi_stamp = custom_target('mutter-vapi-stamp',
  command: [
    'sh', '-c',
    'cp "$1/gjs-1.0.deps" "$2/" && touch "$3"',
    'sh',
    meson.current_source_dir(),
    meson.current_build_dir(),
    '@OUTPUT@',
  ],
  depends: [libmutter_target, clutter_target, cogl_target, mtk_target, st_widget_peer_vapi],
  output: 'mutter-vapi-stamp.vapi',
)

# Targets that --pkg libmutter-16 / mutter-*-16 must depend on this (not only link).
mutter_vapi_dep = declare_dependency(
  sources: [mutter_vapi_stamp],
)
