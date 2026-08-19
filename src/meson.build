compositor_sources = files(
  'Debug.vala',
  'namespace.vala',
  'Main.vala',
  'Plugin.vala',
  'ui/namespace.vala',
  'ui/Rectangle.vala',
  'ui/WindowParams.vala',
  'ui/Window.vala',
  'ui/WorkspaceParams.vala',
  'ui/Workspace.vala',
  'ui/DisplayParams.vala',
  'ui/Display.vala',
  'rpc/namespace.vala',
  'rpc/DaemonParams.vala',
  'rpc/Daemon.vala',
  'rpc/Listen.vala',
  'rpc/Server.vala',
)

mutter_vala_args = [
  '--pkg=libmutter-16',
  '--pkg=mutter-clutter-16',
  '--pkg=mutter-cogl-16',
  '--pkg=mutter-mtk-16',
  '--pkg=xfixes-4.0',
  '--pkg=gdesktopenums-3.0',
  '--vapidir', meson.project_build_root() / 'vapi',
  '--vapidir', meson.project_source_root() / 'vapi',
]

compositor_rpath = mutter_typelib_dir + ':' + ocrpc_rpath

gnome_shell_rpc = executable('gnome-shell-rpc',
  compositor_sources,
  mutter_vapi_stamp,
  dependencies: [mutter_dep, ocrpc_dep],
  vala_args: mutter_vala_args + ocrpc_vala_args,
  build_rpath: compositor_rpath,
  install: false,
)

rpc_client = executable('rpc-client',
  files(
    'Debug.vala',
    'rpc-client/namespace.vala',
    'rpc-client/Main.vala',
    'ui/namespace.vala',
    'ui/Rectangle.vala',
    'ui/WindowParams.vala',
    'ui/Window.vala',
    'ui/DisplayParams.vala',
    'rpc/DaemonParams.vala',
  ),
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)
