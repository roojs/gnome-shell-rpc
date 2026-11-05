executable(
  'gi-rpc-echo',
  files(meson.project_source_root() / 'src' / 'ApplicationInterface.vala'),
  files(meson.project_source_root() / 'tests' / 'gi-rpc-smoke' / 'PingResult.vala'),
  'namespace.vala',
  'Echo.vala',
  'Application.vala',
  link_with: gsr_server_rpc_lib,
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  c_args: [
    '-I' + meson.project_build_root() / 'src',
    '-I' + gsr_server_build_dir,
  ],
  build_rpath: ocrpc_rpath,
  export_dynamic: true,
  install: false,
)
