executable(
  'gjs-embed',
  files(meson.project_source_root() / 'src' / 'ApplicationInterface.vala'),
  'namespace.vala',
  'Application.vala',
  gjs_embed_config,
  dependencies: gjs_shell_deps,
  vala_args: gjs_shell_vala_args,
  install: false,
)
