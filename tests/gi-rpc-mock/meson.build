if get_option('gi_rpc_mock')
  executable(
    'gi-rpc-mock',
    rpc_config,
    files(meson.project_source_root() / 'src' / 'ApplicationInterface.vala'),
    'namespace.vala',
    'MockBootGraph.vala',
    'Bootstrap.vala',
    'HelperMock.vala',
    'Application.vala',
    link_with: gsr_server_rpc_lib,
    dependencies: [ocrpc_dep, girepository_dep],
    vala_args: ocrpc_vala_args + [
      girepository_pkg,
      '--vapidir', meson.project_source_root() / 'vapi',
    ] + girepository_define,
    c_args: [
      '-I' + meson.project_build_root() / 'src',
      '-I' + gsr_server_build_dir,
    ],
    build_rpath: ocrpc_rpath,
    export_dynamic: true,
    install: false,
  )
endif
