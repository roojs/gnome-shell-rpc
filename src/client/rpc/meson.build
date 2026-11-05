# Client RPC base. Other client libs link this. It does not link them:
# meta_register / st_register / shell hooks / prop-batch flush stay unresolved
# until gsr-client loads every .so.
# shared/namespace.vala cannot be compiled in this target: valac names an
# outside file by its basename, and this directory already has namespace.vala.
gsr_rpc_build_dir = meson.current_build_dir()

gsr_rpc_shared_lib = static_library(
  'gsr-rpc-shared',
  files(
    meson.project_source_root() / 'src' / 'shared' / 'namespace.vala',
    meson.project_source_root() / 'src' / 'shared' / 'Rectangle.vala',
    meson.project_source_root() / 'src' / 'shared' / 'ClutterEventState.vala',
    meson.project_source_root() / 'src' / 'shared' / 'Window.vala',
    meson.project_source_root() / 'src' / 'shared' / 'Workspace.vala',
  ),
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  vala_header: 'gsr-rpc-shared.h',
  vala_vapi: 'gsr-rpc-shared.vapi',
  install: false,
)

gsr_rpc_lib = shared_library(
  'gsr-rpc-16',
  files(
    'namespace.vala',
    meson.project_source_root() / 'src' / 'client' / 'Cancellable.vala',
    'VfuncRelay.vala',
    'c-vfunc-relay.c',
  ),
  link_whole: gsr_rpc_shared_lib,
  dependencies: [
    ocrpc_dep,
    dependency('gio-2.0'),
    dependency('gee-0.8'),
  ],
  vala_args: ocrpc_vala_args + [
    '--pkg=gio-2.0',
    '--pkg=gee-0.8',
    '--pkg=gsr-rpc-shared',
    '--vapidir', meson.current_build_dir(),
  ],
  c_args: [
    '-I' + meson.current_source_dir(),
    '-I' + meson.current_build_dir(),
  ],
  link_args: ['-Wl,--unresolved-symbols=ignore-all'],
  vala_header: 'gsr-rpc-16.h',
  vala_vapi: 'gsr-rpc-16.vapi',
  build_rpath: ocrpc_rpath,
  install: true,
)

gsr_rpc_dep = declare_dependency(
  link_with: gsr_rpc_lib,
  dependencies: [ocrpc_dep],
)
