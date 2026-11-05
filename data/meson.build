install_data(
  'gsr-session',
  'gsr-debug-session',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)
install_data(
  'wayland-sessions' / 'gsr.desktop',
  'wayland-sessions' / 'gsr-debug.desktop',
  install_dir: get_option('datadir') / 'wayland-sessions',
)
install_data(
  'gnome-session' / 'sessions' / 'gsr.session',
  'gnome-session' / 'sessions' / 'gsr-debug.session',
  install_dir: get_option('datadir') / 'gnome-session' / 'sessions',
)
install_data(
  'applications' / 'org.gnome.ShellRpc.desktop',
  'applications' / 'org.gnome.ShellRpcDebug.desktop',
  install_dir: get_option('datadir') / 'applications',
)
systemd = dependency('systemd', required: false)
if systemd.found()
  systemduserunitdir = systemd.get_variable('systemduserunitdir')
else
  systemduserunitdir = 'lib' / 'systemd' / 'user'
endif
install_data(
  'systemd' / 'org.gnome.ShellRpc.target',
  'systemd' / 'org.gnome.ShellRpc@.service',
  'systemd' / 'org.gnome.ShellRpcDebug.target',
  'systemd' / 'org.gnome.ShellRpcDebug.service',
  install_dir: systemduserunitdir,
)
install_data(
  'systemd' / 'gnome-session@gsr.target.d' / 'gsr.session.conf',
  install_dir: systemduserunitdir / 'gnome-session@gsr.target.d',
)
install_data(
  'systemd' / 'gnome-session@gsr-debug.target.d' / 'gsr.session.conf',
  install_dir: systemduserunitdir / 'gnome-session@gsr-debug.target.d',
)
apport_report_ignore = configure_file(
  input: 'apport' / 'report-ignore.in',
  output: 'gnome-shell-rpc',
  configuration: {
    'gsr_client': get_option('prefix') / get_option('bindir') / 'gsr-client',
    'gsr_server': get_option('prefix') / get_option('bindir') / 'gsr-server',
  },
)
install_data(
  apport_report_ignore,
  install_dir: get_option('sysconfdir') / 'apport' / 'report-ignore',
)
