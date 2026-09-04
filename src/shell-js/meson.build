# Substituted misc/config.js + vendor JS gresource for thin gnome-shell-rpc.
shell_js_conf = configuration_data()
shell_js_conf.set('PACKAGE_NAME', 'gnome-shell')
shell_js_conf.set('PACKAGE_VERSION', '48.0')
shell_js_conf.set('GETTEXT_PACKAGE', 'gnome-shell')
shell_js_conf.set('LIBMUTTER_API_VERSION', '16')
shell_js_conf.set10('HAVE_NETWORKMANAGER', false)
shell_js_conf.set10('HAVE_PORTAL_HELPER', false)
shell_js_conf.set('UTILS_FOLDER_APPS', run_command(
  generate_app_list,
  vendor_data_dir / 'default-apps' / 'utilities-folder.txt',
  check: true,
).stdout())
shell_js_conf.set('SYSTEM_FOLDER_APPS', run_command(
  generate_app_list,
  vendor_data_dir / 'default-apps' / 'system-folder.txt',
  check: true,
).stdout())
shell_js_conf.set('datadir', '/usr/share')
shell_js_conf.set('libexecdir', '/usr/libexec/gnome-shell')

subdir('misc')

shell_js_resource_deps = [shell_js_config]
if get_option('gi_rpc_js_overlay_message_list') != 'disabled'
  subdir('ui')
  shell_js_resource_deps += message_list_overlay
endif

shell_js_build_dir = meson.current_build_dir()

# Build dir first so substituted misc/config.js wins over vendor (only .in).
shell_js_resources = gnome.compile_resources(
  'shell-js-resources',
  vendor_js_dir / 'js-resources.gresource.xml',
  source_dir: [shell_js_build_dir, vendor_js_dir],
  c_name: 'shell_js_resources',
  dependencies: shell_js_resource_deps,
)
