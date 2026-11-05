executable(
  'rpc-client',
  files(meson.project_source_root() / 'src' / 'ApplicationInterface.vala'),
  'namespace.vala',
  'Application.vala',
  link_with: gsr_shared_lib,
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  c_args: ['-I' + meson.project_build_root() / 'src'],
  build_rpath: ocrpc_rpath,
  install: false,
)
