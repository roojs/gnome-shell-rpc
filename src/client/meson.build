subdir('rpc')
subdir('libmutter-clutter-rpc-16')
subdir('libmutter-rpc-16')
subdir('libst-rpc-16')
subdir('libshell-16')

client_lib_build_dirs = [
  gsr_rpc_build_dir,
  clutter_rpc_build_dir,
  meta_rpc_build_dir,
  st_rpc_build_dir,
  shell_build_dir,
]
client_vapidir_args = []
client_header_inc = []
foreach d : client_lib_build_dirs
  client_vapidir_args += ['--vapidir', d]
  client_header_inc += '-I' + d
endforeach
client_lib_rpath = ':'.join(client_lib_build_dirs)

# JS gresource. The meson file stays in gresource/, so the output directory
# does not change.
gnome = import('gnome')
vendor_js_dir = gnome_shell_vendor_root / 'js'
vendor_data_dir = gnome_shell_vendor_root / 'data'
# Upstream moved generate-app-list.py: meson/ on 48.x, build-aux/ on newer.
generate_app_list_script = gnome_shell_vendor_root / 'meson' / 'generate-app-list.py'
if not fs.exists(generate_app_list_script)
  generate_app_list_script = gnome_shell_vendor_root / 'build-aux' / 'generate-app-list.py'
endif
generate_app_list = find_program(generate_app_list_script)
subdir('gresource')

# ApplicationInterface.vala lives in src/. An absolute path makes valac name
# the C file by its basename inside this target's private directory. A ../
# path would be written once for both programs.
gnome_shell_rpc = executable('gsr-client',
  files(
    meson.project_source_root() / 'src' / 'ApplicationInterface.vala',
    'namespace.vala',
    'Application.vala',
    'shell-main.vala',
  ) + shell_js_resources + gsr_js_resources,
  gnome_shell_rpc_config,
  dependencies: gjs_shell_deps + [
    mutter_vapi_dep,
    ocrpc_dep,
    dependency('gdk-pixbuf-2.0'),
    # NetworkAgent / Polkit / KeyringPrompt types leak into shell-16.vapi.
    dependency('libnm'),
    dependency('polkit-agent-1'),
    dependency('polkit-gobject-1'),
    dependency('gcr-4'),
    declare_dependency(
      link_with: [gsr_rpc_lib, mutter_rpc_lib, mutter_clutter_rpc_lib, shell_gi_lib],
      dependencies: [
        dependency('mutter-mtk-' + mutter_api_version),
        dependency('mutter-cogl-' + mutter_api_version),
        dependency('atk'),
        dependency('pango'),
      ],
      compile_args: ['-I' + mutter_includedir],
    ),
  ],
  vala_args: gjs_shell_vala_args + ocrpc_vala_args + [
    '--pkg=gdesktopenums-3.0',
    '--pkg=gsr-clutter-effect-abi',
    '--pkg=gdk-pixbuf-2.0',
    '--pkg=libnm',
    '--pkg=polkit-agent-1',
    '--pkg=polkit-gobject-1',
    '--pkg=gcr-4',
    '--pkg=mutter-rpc-' + mutter_api_version,
    '--pkg=gsr-rpc-16',
    '--pkg=gsr-rpc-shared',
    '--pkg=mutter-clutter-rpc-' + mutter_api_version,
    '--pkg=st-rpc-' + mutter_api_version,
    '--pkg=shell-' + mutter_api_version,
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--pkg=atk',
    '--pkg=pango',
    '--vapidir', meson.current_source_dir() / 'libmutter-clutter-rpc-16',
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ] + client_vapidir_args,
  c_args: [
    '-I' + mutter_includedir,
    '-I' + meson.current_source_dir() / 'libmutter-clutter-rpc-16',
    '-include', 'mutter-clutter-rpc-' + mutter_api_version + '.h',
    # shell-16.h embeds NetworkAgent → NMSecretAgentOld.
    '-include', 'NetworkManager.h',
    '-include', 'nm-secret-agent-old.h',
    '-DPOLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE',
    '-DGCR_API_SUBJECT_TO_CHANGE',
  ] + client_header_inc + mutter_clutter_cflags,
  link_args: ['-L' + st_rpc_build_dir, '-lst-rpc-' + mutter_api_version],
  link_depends: [st_rpc_lib],
  # libgvc.so lives in the gnome-shell pkglibdir. Gvc.MixerControl
  # is that library; without it on the runpath the type comes out void.
  build_rpath: ocrpc_rpath + ':' + client_lib_rpath + ':' + gnome_shell_pkglibdir,
  install: true,
  install_rpath: get_option('prefix') / get_option('libdir') + ':' + mutter_typelib_dir + ':' + gnome_shell_pkglibdir,
)

# Smoke and debug host. Same link as gsr-client.
gsr_smoke = executable('gsr-smoke',
  files(
    meson.project_source_root() / 'src' / 'ApplicationInterface.vala',
    'namespace.vala',
    'Application.vala',
    'SmokeApplication.vala',
    'smoke-main.vala',
  ) + shell_js_resources + gsr_js_resources,
  gnome_shell_rpc_config,
  dependencies: gjs_shell_deps + [
    mutter_vapi_dep,
    ocrpc_dep,
    dependency('gdk-pixbuf-2.0'),
    # NetworkAgent / Polkit / KeyringPrompt types leak into shell-16.vapi.
    dependency('libnm'),
    dependency('polkit-agent-1'),
    dependency('polkit-gobject-1'),
    dependency('gcr-4'),
    declare_dependency(
      link_with: [gsr_rpc_lib, mutter_rpc_lib, mutter_clutter_rpc_lib, shell_gi_lib],
      dependencies: [
        dependency('mutter-mtk-' + mutter_api_version),
        dependency('mutter-cogl-' + mutter_api_version),
        dependency('atk'),
        dependency('pango'),
      ],
      compile_args: ['-I' + mutter_includedir],
    ),
  ],
  vala_args: gjs_shell_vala_args + ocrpc_vala_args + [
    '--pkg=gdesktopenums-3.0',
    '--pkg=gsr-clutter-effect-abi',
    '--pkg=gdk-pixbuf-2.0',
    '--pkg=libnm',
    '--pkg=polkit-agent-1',
    '--pkg=polkit-gobject-1',
    '--pkg=gcr-4',
    '--pkg=mutter-rpc-' + mutter_api_version,
    '--pkg=gsr-rpc-16',
    '--pkg=gsr-rpc-shared',
    '--pkg=mutter-clutter-rpc-' + mutter_api_version,
    '--pkg=st-rpc-' + mutter_api_version,
    '--pkg=shell-' + mutter_api_version,
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--pkg=atk',
    '--pkg=pango',
    '--vapidir', meson.current_source_dir() / 'libmutter-clutter-rpc-16',
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ] + client_vapidir_args,
  c_args: [
    '-I' + mutter_includedir,
    '-I' + meson.current_source_dir() / 'libmutter-clutter-rpc-16',
    '-include', 'mutter-clutter-rpc-' + mutter_api_version + '.h',
    # shell-16.h embeds NetworkAgent → NMSecretAgentOld.
    '-include', 'NetworkManager.h',
    '-include', 'nm-secret-agent-old.h',
    '-DPOLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE',
    '-DGCR_API_SUBJECT_TO_CHANGE',
  ] + client_header_inc + mutter_clutter_cflags,
  link_args: ['-L' + st_rpc_build_dir, '-lst-rpc-' + mutter_api_version],
  link_depends: [st_rpc_lib],
  build_rpath: ocrpc_rpath + ':' + client_lib_rpath + ':' + gnome_shell_pkglibdir,
  install: true,
  install_rpath: get_option('prefix') / get_option('libdir') + ':' + mutter_typelib_dir + ':' + gnome_shell_pkglibdir,
)
