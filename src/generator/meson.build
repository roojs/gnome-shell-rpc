# Stays on girepository 1.0. The 2.0 vapi has no BaseInfo.get_type().
gi_stub_gen = executable(
  'gi-stub-gen',
  files(meson.project_source_root() / 'src' / 'ApplicationInterface.vala'),
  'namespace.vala',
  'HeaderConfig.vala',
  'Generator.vala',
  'BoxedType.vala',
  'HeaderGenerator.vala',
  'Application.vala',
  dependencies: [
    dependency('gobject-introspection-1.0'),
    dependency('gee-0.8'),
    dependency('gio-2.0'),
  ],
  vala_args: [
    '--pkg=gobject-introspection-1.0',
    '--pkg=gee-0.8',
    '--pkg=gio-2.0',
  ],
  install: false,
)
