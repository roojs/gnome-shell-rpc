executable(
  'fake-shell',
  files(meson.project_source_root() / 'src' / 'ApplicationInterface.vala'),
  'namespace.vala',
  'Session.vala',
  'Display.vala',
  'Window.vala',
  'Application.vala',
  'TopBar.vala',
  link_with: gsr_shared_lib,
  dependencies: [ocrpc_dep, gtk4_dep],
  vala_args: ocrpc_vala_args + [
    '--pkg=gtk4',
  ],
  c_args: ['-I' + meson.project_build_root() / 'src'],
  build_rpath: ocrpc_rpath,
  install: false,
)
