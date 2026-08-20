compositor_sources = files(
  'Debug.vala',
  'namespace.vala',
  'Main.vala',
  'Plugin.vala',
  'shared/namespace.vala',
  'shared/Rectangle.vala',
  'ui/namespace.vala',
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

rpc_client_sources = files(
  'Debug.vala',
  'rpc-client/namespace.vala',
  'rpc-client/Main.vala',
  'shared/namespace.vala',
  'shared/Rectangle.vala',
  'ui/namespace.vala',
  'ui/WindowParams.vala',
  'ui/Window.vala',
  'ui/DisplayParams.vala',
  'rpc/DaemonParams.vala',
)

rpc_client = executable('rpc-client',
  rpc_client_sources,
  dependencies: [ocrpc_dep],
  vala_args: ocrpc_vala_args,
  build_rpath: ocrpc_rpath,
  install: false,
)

gjs_dep = dependency('gjs-1.0')

gjs_embed = executable('gjs-embed',
  files(
    'Debug.vala',
    'gjs-embed/namespace.vala',
    'gjs-embed/Main.vala',
  ),
  dependencies: [gjs_dep, dependency('gee-0.8')],
  vala_args: [
    '--pkg=gjs-1.0',
    '--pkg=gee-0.8',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  install: false,
)

gtk4_dep = dependency('gtk4')

fake_shell = executable('fake-shell',
  files(
    'Debug.vala',
    'shared/namespace.vala',
    'shared/Rectangle.vala',
    'ui/namespace.vala',
    'ui/WindowParams.vala',
    'ui/Window.vala',
    'ui/DisplayParams.vala',
    'rpc/DaemonParams.vala',
    'remote/namespace.vala',
    'remote/Session.vala',
    'remote/Display.vala',
    'remote/Window.vala',
    'fake-shell/namespace.vala',
    'fake-shell/Main.vala',
    'fake-shell/Application.vala',
    'fake-shell/TopBar.vala',
  ),
  dependencies: [ocrpc_dep, gtk4_dep],
  vala_args: ocrpc_vala_args + [
    '--pkg=gtk4',
  ],
  build_rpath: ocrpc_rpath,
  install: false,
)
