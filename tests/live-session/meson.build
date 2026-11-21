executable(
  'panel-cube-live-prove',
  'panel-cube-live-prove.vala',
  link_with: gsr_shared_lib,
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  c_args: ['-I' + meson.project_build_root() / 'src'],
  build_rpath: ocrpc_rpath,
  install: false,
)