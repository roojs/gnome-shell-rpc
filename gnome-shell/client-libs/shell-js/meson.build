jsconf = configuration_data()
jsconf.set('PACKAGE_NAME', 'gnome-shell')
jsconf.set('PACKAGE_VERSION', '48.0')
jsconf.set('GETTEXT_PACKAGE', 'gnome-shell')
jsconf.set('LIBMUTTER_API_VERSION', mutter_api_version)
jsconf.set10('HAVE_NETWORKMANAGER', false)
jsconf.set10('HAVE_PORTAL_HELPER', false)
jsconf.set('UTILS_FOLDER_APPS', run_command(
  generate_app_list,
  vendor_data_dir / 'default-apps' / 'utilities-folder.txt',
  check: true,
).stdout())
jsconf.set('SYSTEM_FOLDER_APPS', run_command(
  generate_app_list,
  vendor_data_dir / 'default-apps' / 'system-folder.txt',
  check: true,
).stdout())
jsconf.set('datadir', '/usr/share')
jsconf.set('libexecdir', '/usr/libexec/gnome-shell')

subdir('misc')

shell_js_build_dir = meson.current_build_dir()

js_resources = gnome.compile_resources(
  'js-resources',
  vendor_js_dir / 'js-resources.gresource.xml',
  source_dir: [vendor_js_dir, shell_js_build_dir],
  c_name: 'shell_js_resources',
  dependencies: [config_js],
)
