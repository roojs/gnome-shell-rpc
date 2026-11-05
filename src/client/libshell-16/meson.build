shell_build_dir = meson.current_build_dir()

# 0.7.7 — owned Shell-16 facade (not libshell).
# valac requires NAME-VERSION.gir (cannot be *.vala.gir). That file is the
# stamp, never installed. Inject writes Shell-16.injected.gir — typelib and
# any install use that (installed name Shell-16.gir).
# libsystemd has no Vala vapi — assert found, link with -lsystemd only.
dependency('libsystemd')
shell_api_define = []
if mutter_api_version == '18'
  shell_api_define = ['--define=MUTTER_18']
endif
shell_gi_lib = shared_library(
  'shell-' + mutter_api_version,
  files(
    'namespace.vala',
    'ClutterEventOverride.vala',
    'InputDeviceOverride.vala',
    'PickContextOverride.vala',
    'KeyBindingOverride.vala',
    'BarrierEventOverride.vala',
    'RegionOverride.vala',
    'ActionMode.vala',
    'AppState.vala',
    'AppLaunchGpu.vala',
    'Util.vala',
    'App.vala',
    'AppSystem.vala',
    'app-system-search.c',
    'GLSLEffect.vala',
    'BlurMode.vala',
    'BlurEffect.vala',
    'InvertLightnessEffect.vala',
    'NetworkAgentResponse.vala',
    'NetworkAgentRequest.vala',
    'NetworkAgentKeyringSave.vala',
    'NetworkAgent.vala',
    'MountOperation.vala',
    'PolkitAuthenticationAgent.vala',
    'polkit-authentication-agent-signals.c',
    'SecureTextBuffer.vala',
    'KeyringPrompt.vala',
    'PerfLog.vala',
    'SquareBin.vala',
    'Stack.vala',
    'WindowPreview.vala',
    'WindowPreviewLayout.vala',
    'WorkspaceBackground.vala',
    'Screenshot.vala',
    'WindowTracker.vala',
    'AppUsage.vala',
    'WM.vala',
    'Global.vala',
    'TimeChangeSource.vala',
    'CameraMonitor.vala',
  ) + (mutter_api_version == '18'
    ? files(
        meson.project_source_root() / 'src' / 'client' / 'libshell-18' / 'EdgeDragGesture.vala',
        meson.project_source_root() / 'src' / 'client' / 'libshell-18' / 'Signals.vala',
      )
    : files('Signals.vala')),
  dependencies: [
    mutter_vapi_dep,
    ocrpc_dep,
    dependency('gio-2.0'),
    dependency('gio-unix-2.0'),
    dependency('libnm'),
    dependency('libsecret-1'),
    dependency('polkit-agent-1'),
    dependency('polkit-gobject-1'),
    dependency('gcr-4'),
    declare_dependency(
      link_with: [
        mutter_rpc_lib,
        st_rpc_lib,
        gsr_clutter_boxed_lib,
        gsr_st_boxed_lib,
      ],
      dependencies: [
        mutter_clutter_rpc_client_dep,
        dependency('mutter-mtk-' + mutter_api_version),
        dependency('mutter-cogl-' + mutter_api_version),
        dependency('atk'),
        dependency('pango'),
        dependency('gdk-pixbuf-2.0'),
        dependency('libnm'),
        dependency('libsecret-1'),
        dependency('polkit-agent-1'),
        dependency('polkit-gobject-1'),
        dependency('gcr-4'),
      ],
      compile_args: ['-I' + mutter_includedir],
    ),
  ],
  link_args: ['-lsystemd'],
  vala_args: ocrpc_vala_args + shell_api_define + [
    '--pkg=posix',
    '--pkg=gio-2.0',
    '--pkg=gee-0.8',
    '--pkg=gdesktopenums-3.0',
    '--pkg=gsr-clutter-effect-abi',
    '--pkg=gdk-pixbuf-2.0',
    '--pkg=libnm',
    '--pkg=libsecret-1',
    '--pkg=polkit-agent-1',
    '--pkg=polkit-gobject-1',
    '--pkg=gcr-4',
    '--pkg=mutter-rpc-' + mutter_api_version,
    '--pkg=gsr-rpc-16',
    '--pkg=gsr-rpc-shared',
    '--pkg=mutter-clutter-rpc-' + mutter_api_version,
    '--pkg=st-rpc-' + mutter_api_version,
    '--pkg=mutter-cogl-' + mutter_api_version,
    '--pkg=mutter-mtk-' + mutter_api_version,
    '--pkg=atk',
    '--pkg=pango',
    '--pkg=graphene-gobject-1.0',
    '--pkg=gsr-clutter-boxed',
    '--pkg=gsr-st-boxed',
    '--vapidir', meson.current_source_dir() / '../libmutter-clutter-rpc-16',
    '--vapidir', gsr_rpc_build_dir,
    '--vapidir', clutter_rpc_build_dir,
    '--vapidir', meta_rpc_build_dir,
    '--vapidir', st_rpc_build_dir,
    '--vapidir', meson.project_build_root() / 'vapi',
    '--vapidir', meson.project_source_root() / 'vapi',
  ],
  c_args: [
    '-I' + mutter_includedir,
    '-I' + gsr_rpc_build_dir,
    '-I' + clutter_rpc_build_dir,
    '-I' + meta_rpc_build_dir,
    '-I' + st_rpc_build_dir,
    '-I' + meson.current_build_dir(),
    '-I' + meson.current_source_dir() / '../libmutter-clutter-rpc-16',
    '-I' + meson.current_source_dir(),
    '-include', 'mutter-clutter-rpc-' + mutter_api_version + '.h',
    '-include', 'NetworkManager.h',
    '-include', 'nm-secret-agent-old.h',
    '-include', 'libsecret/secret.h',
    # Vala GLib.dpgettext pulls gi18n-lib.h (needs GETTEXT_PACKAGE).
    '-DGETTEXT_PACKAGE="gnome-shell"',
    '-DPOLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE',
    '-DGCR_API_SUBJECT_TO_CHANGE',
  ] + mutter_clutter_cflags,
  build_rpath: ocrpc_rpath + ':' + gsr_rpc_build_dir + ':' + clutter_rpc_build_dir + ':' + meta_rpc_build_dir + ':' + st_rpc_build_dir,
  vala_header: 'shell-' + mutter_api_version + '.h',
  vala_vapi: 'shell-' + mutter_api_version + '.vapi',
  vala_gir: 'Shell-' + mutter_api_version + '.gir',
  install: true,
  install_dir: [true, false, false, false],
  install_rpath: mutter_typelib_dir,
)

# Injected GIR is what the typelib / install ship (as Shell-16.gir).
# Vala 0.56 GirWriter: no nested GStrv, GLib.DesktopAppInfo. Per-series
# clutch — drop or replace when this tree moves off Shell-16 / valac 0.56.
if mutter_api_version == '18'
  shell_app_info_gir = meson.current_source_dir() / '../libshell-18/app-info.gir'
  shell_app_info_type = 'GioUnix.DesktopAppInfo'
else
  shell_app_info_gir = meson.current_source_dir() / 'app-info.gir'
  shell_app_info_type = 'Gio.DesktopAppInfo'
endif
shell_gi_gir = custom_target(
  'Shell-' + mutter_api_version + '.injected.gir',
  output: 'Shell-' + mutter_api_version + '.injected.gir',
  command: [
    find_program('sh'),
    meson.project_source_root() / 'scripts/gir-xslt-inject.sh',
    meson.current_build_dir() / 'Shell-' + mutter_api_version + '.gir',
    '@OUTPUT@',
    meson.project_source_root() / 'scripts/gir-inject.xsl',
    meson.current_source_dir() / 'search.function.gir',
    shell_app_info_gir,
    xsltproc,
    shell_app_info_type,
  ],
  depend_files: [
    files('search.function.gir'),
    files(mutter_api_version == '18' ? '../libshell-18/app-info.gir' : 'app-info.gir'),
    meson.project_source_root() / 'scripts/gir-inject.xsl',
    meson.project_source_root() / 'scripts/gir-xslt-inject.sh',
  ],
  depends: [shell_gi_lib],
  build_by_default: true,
  install: false,
)
