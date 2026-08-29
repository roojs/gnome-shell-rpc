# Phase 0.7 Phase 4: client Shell/St linked against libmutter-rpc-16 (not libmutter-16).
# Sources live in vendor/gnome-shell/ (pinned 48.x); we port upstream meson slices only.

gnome = import('gnome')
fs = import('fs')
cc = meson.get_compiler('c')

mutter_api_version = '16'
vendor_st_dir = gnome_shell_vendor_root / 'src' / 'st'
vendor_src_dir = gnome_shell_vendor_root / 'src'
client_libdir = meson.current_build_dir()

version_cmd = run_command(
  'git', '-C', gnome_shell_vendor_root, 'describe', '--tags', '--always',
  check: false,
)
if version_cmd.returncode() == 0
  vendor_version = version_cmd.stdout().strip()
  if not vendor_version.startswith('48.')
    warning(
      'vendor gnome-shell @0@ — client libs expect 48.x (mutter API 16); pin with -Dgnome_shell_vendor_ref=48.0'.format(
        vendor_version,
      ),
    )
  endif
endif

# Minimal config.h — St includes it; no HAVE_* symbols used in st/*.c at 48.0.
cdata = configuration_data()
cdata.set_quoted('GETTEXT_PACKAGE', 'gnome-shell')
cdata.set_quoted('VERSION', '48.0')
cdata.set_quoted('PACKAGE_VERSION', '48.0')
cdata.set('HAVE_NETWORKMANAGER', false)
cdata.set('HAVE_PIPEWIRE', false)
cdata.set('HAVE_SYSTEMD', false)
cdata.set('HAVE_X11', false)
cdata.set('HAVE_X11_CLIENT', false)
cdata.set('HAVE_FDWALK', cc.has_function('fdwalk'))
cdata.set('HAVE_MALLINFO', cc.has_function('mallinfo'))
cdata.set('HAVE_MALLINFO2', cc.has_function('mallinfo2'))
cdata.set('HAVE_SYS_RESOURCE_H', cc.has_header('sys/resource.h'))
cdata.set('HAVE_EXE_INTROSPECTION', cc.has_header('elf.h') and cc.has_header('link.h'))
cdata.set('HAVE__NL_TIME_FIRST_WEEKDAY', cc.has_header_symbol('langinfo.h', '_NL_TIME_FIRST_WEEKDAY'))
# Stock clutter headers for #include <clutter/…>; link is stub Clutter inside
# libmutter-rpc-16 (do not link libmutter-clutter).
clutter_dep = dependency('mutter-clutter-16').partial_dependency(
  includes: true,
  compile_args: true,
  link_args: false,
  links: false,
)
mtk_dep = dependency('mutter-mtk-16')
cogl_dep = dependency('mutter-cogl-16')
atk_dep = dependency('atk')
gdk_pixbuf_dep = dependency('gdk-pixbuf-2.0')
pango_dep = dependency('pango')
libxml_dep = dependency('libxml-2.0')
schemas_dep = dependency('gsettings-desktop-schemas')
polkit_dep = dependency('polkit-agent-1')
m_dep = cc.find_library('m', required: false)

polkit_has_autocleanup = cc.compiles(
  '''
  #define POLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE
  #include <polkitagent/polkitagent.h>
  void main(void) { g_autoptr(PolkitAgentListener) agent = NULL; }
  ''',
  dependencies: polkit_dep,
)
cdata.set('HAVE_POLKIT_AUTOCLEANUP', polkit_has_autocleanup)

config_h = configure_file(
  input: gnome_shell_vendor_root / 'config.h.meson',
  output: 'config.h',
  configuration: cdata,
)

# Link Meta + stub Clutter from libmutter-rpc-16, not stock libmutter / clutter.
mutter_rpc_client_dep = declare_dependency(
  link_with: mutter_rpc_lib,
  dependencies: [mtk_dep],
  compile_args: ['-I' + mutter_includedir],
)

client_rpath = mutter_typelib_dir + ':' + meson.project_build_root() / 'src'

# --- libst-16 (from vendor/gnome-shell/src/st/meson.build @ 48.0) ---

st_headers = [
  'st-adjustment.h', 'st-bin.h', 'st-border-image.h', 'st-box-layout.h',
  'st-button.h', 'st-clipboard.h', 'st-drawing-area.h', 'st-entry.h',
  'st-focus-manager.h', 'st-generic-accessible.h', 'st-icon.h',
  'st-icon-colors.h', 'st-icon-theme.h', 'st-image-content.h', 'st-label.h',
  'st-password-entry.h', 'st-scrollable.h', 'st-scroll-bar.h',
  'st-scroll-view.h', 'st-scroll-view-fade.h', 'st-settings.h', 'st-shadow.h',
  'st-spinner-content.h', 'st-texture-cache.h', 'st-theme.h', 'st-theme-context.h',
  'st-theme-node.h', 'st-types.h', 'st-viewport.h', 'st-widget.h',
  'st-widget-accessible.h',
]

st_includes = []
foreach include : st_headers
  st_includes += '#include <@0@>'.format(include)
endforeach

st_h = configure_file(
  input: vendor_st_dir / 'st.h.in',
  output: 'st.h',
  configuration: configuration_data({
    'includes': '\n'.join(st_includes),
  }),
)

# libshell includes <st/st.h>; upstream generates st.h under src/st/.
st_shell_headers = custom_target(
  'st-shell-headers',
  input: st_h,
  output: 'st-shell-headers.stamp',
  command: [
    'sh', '-c',
    'mkdir -p "$0/st" && cp "$1" "$0/st/st.h"',
    meson.current_build_dir(),
    '@INPUT@',
  ],
)

st_inc = include_directories('.')

st_cflags = [
  '-I' + vendor_src_dir,
  '-I' + vendor_st_dir,
  '-I' + meson.current_build_dir(),
  '-DG_LOG_DOMAIN="St"',
  '-DST_COMPILATION',
  '-DCLUTTER_ENABLE_EXPERIMENTAL_API',
  '-DCOGL_ENABLE_EXPERIMENTAL_API',
  '-DPACKAGE_DATA_DIR="/usr/share/gnome-shell"',
]

st_private_headers = [
  'croco/cr-additional-sel.h', 'croco/cr-attr-sel.h', 'croco/cr-cascade.h',
  'croco/cr-declaration.h', 'croco/cr-doc-handler.h', 'croco/cr-enc-handler.h',
  'croco/cr-fonts.h', 'croco/cr-input.h', 'croco/cr-num.h', 'croco/cr-om-parser.h',
  'croco/cr-parser.h', 'croco/cr-parsing-location.h', 'croco/cr-prop-list.h',
  'croco/cr-pseudo.h', 'croco/cr-rgb.h', 'croco/cr-selector.h', 'croco/cr-simple-sel.h',
  'croco/cr-statement.h', 'croco/cr-string.h', 'croco/cr-stylesheet.h', 'croco/cr-term.h',
  'croco/cr-tknzr.h', 'croco/cr-token.h', 'croco/cr-utils.h', 'croco/libcroco-config.h',
  'croco/libcroco.h', 'st-private.h', 'st-theme-private.h', 'st-theme-node-private.h',
  'st-theme-node-transition.h',
]

croco_sources = [
  'croco/cr-additional-sel.c', 'croco/cr-attr-sel.c', 'croco/cr-cascade.c',
  'croco/cr-declaration.c', 'croco/cr-doc-handler.c', 'croco/cr-enc-handler.c',
  'croco/cr-fonts.c', 'croco/cr-input.c', 'croco/cr-num.c', 'croco/cr-om-parser.c',
  'croco/cr-parser.c', 'croco/cr-parsing-location.c', 'croco/cr-prop-list.c',
  'croco/cr-pseudo.c', 'croco/cr-rgb.c', 'croco/cr-selector.c', 'croco/cr-simple-sel.c',
  'croco/cr-statement.c', 'croco/cr-string.c', 'croco/cr-stylesheet.c', 'croco/cr-term.c',
  'croco/cr-tknzr.c', 'croco/cr-token.c', 'croco/cr-utils.c',
]

st_sources = [
  'st-adjustment.c', 'st-bin.c', 'st-border-image.c', 'st-box-layout.c',
  'st-button.c', 'st-clipboard.c', 'st-drawing-area.c', 'st-entry.c',
  'st-focus-manager.c', 'st-generic-accessible.c', 'st-icon.c', 'st-icon-cache.c',
  'st-icon-colors.c', 'st-icon-theme.c', 'st-image-content.c', 'st-label.c',
  'st-password-entry.c', 'st-private.c', 'st-scrollable.c', 'st-scroll-bar.c',
  'st-scroll-view.c', 'st-scroll-view-fade.c', 'st-settings.c', 'st-shadow.c',
  'st-spinner-content.c', 'st-texture-cache.c', 'st-theme.c', 'st-theme-context.c',
  'st-theme-node.c', 'st-theme-node-drawing.c', 'st-theme-node-transition.c',
  'st-viewport.c', 'st-widget.c',
]

st_header_files = []
foreach h : st_headers + st_private_headers
  st_header_files += vendor_st_dir / h
endforeach

st_source_files = []
foreach s : st_sources + croco_sources
  st_source_files += vendor_st_dir / s
endforeach

st_enums = gnome.mkenums_simple('st-enum-types',
  sources: st_header_files,
  header_prefix: '''
#if !defined(ST_H_INSIDE) && !defined(ST_COMPILATION)
#error "Only <st/st.h> can be included directly.h"
#endif''',
)

data_to_c = find_program(vendor_src_dir / 'data-to-c.py')

glsl_sources = custom_target('st-scroll-view-fade-glsl',
  input: vendor_st_dir / 'st-scroll-view-fade.glsl',
  output: 'st-scroll-view-fade-generated.h',
  capture: true,
  command: [data_to_c, '@INPUT@', 'st_scroll_view_fade_glsl'],
)

st_deps = [mtk_dep, cogl_dep, atk_dep, clutter_dep, mutter_rpc_client_dep, gdk_pixbuf_dep, pango_dep]

st_lib_sources = st_source_files + st_header_files
st_lib_sources += st_enums
st_lib_sources += glsl_sources

st_link_deps = st_deps + [libxml_dep, schemas_dep, dependency('cairo')]
if m_dep.found()
  st_link_deps += m_dep
endif

libst = shared_library(
  'st-' + mutter_api_version,
  st_lib_sources,
  c_args: st_cflags,
  dependencies: st_link_deps,
  include_directories: st_inc,
  build_rpath: client_rpath,
  name_prefix: 'lib',
  install: false,
)

libst_dep = declare_dependency(
  link_with: libst,
  sources: st_enums[1],
  dependencies: st_deps,
  include_directories: st_inc,
)

st_gir_sources = st_source_files + st_header_files + st_enums

mutter_gir_dir = mutter_typelib_dir
meta_gir_dir = meson.project_source_root() / 'src' / 'meta-mini'

libst_gir = gnome.generate_gir(
  libst,
  sources: st_gir_sources,
  nsversion: mutter_api_version,
  namespace: 'St',
  includes: [
    'Clutter-' + mutter_api_version,
    'GdkPixbuf-2.0',
    'Meta-' + mutter_api_version,
  ],
  dependencies: [mutter_rpc_client_dep, gdk_pixbuf_dep, clutter_dep],
  include_directories: st_inc,
  extra_args: [
    '-DST_COMPILATION',
    '--quiet',
    '--add-include-path=' + mutter_gir_dir,
    '--add-include-path=' + meta_gir_dir,
    '-I' + vendor_src_dir,
    '-I' + vendor_st_dir,
    '-I' + meson.current_build_dir(),
  ],
  install: false,
)

gnome_shell_client_libdir = client_libdir
gnome_shell_client_typelibdir = client_libdir

message(
  'gnome-shell client libs: @0@ (libst linked to libmutter-rpc-16)'.format(client_libdir),
)

# --- libshell-16 (vendor src/meson.build @ 48.0, Wayland-only client) ---

vendor_js_dir = gnome_shell_vendor_root / 'js'
vendor_data_dir = gnome_shell_vendor_root / 'data'
generate_app_list = find_program(gnome_shell_vendor_root / 'meson' / 'generate-app-list.py')

gio_unix_dep = dependency('gio-unix-2.0')
atk_bridge_dep = dependency('atk-bridge-2.0')
gjs_dep = dependency('gjs-1.0')
gi_dep = dependency('gobject-introspection-1.0')
gcr_dep = dependency('gcr-4')
gnome_desktop_dep = dependency('gnome-desktop-4')

shell_inc = include_directories('.')

shell_cflags = [
  '-I' + vendor_src_dir,
  '-I' + vendor_st_dir,
  '-I' + vendor_src_dir / 'tray',
  '-I' + meson.current_build_dir(),
  '-I' + meson.project_source_root() / 'src/shell-client',
  '-DCLUTTER_ENABLE_EXPERIMENTAL_API',
  '-DCOGL_ENABLE_EXPERIMENTAL_API',
  '-DVERSION="48.0"',
  '-DLOCALEDIR="/usr/share/locale"',
  '-DDATADIR="/usr/share"',
  '-DGNOME_SHELL_LIBEXECDIR="/usr/libexec/gnome-shell"',
  '-DGNOME_SHELL_DATADIR="/usr/share/gnome-shell"',
  '-DGNOME_SHELL_PKGLIBDIR="/usr/lib/gnome-shell"',
]

shell_deps = [
  gio_unix_dep,
  libxml_dep,
  atk_bridge_dep,
  gdk_pixbuf_dep,
  gjs_dep,
  mtk_dep,
  clutter_dep,
  polkit_dep,
  gcr_dep,
  pango_dep,
  gnome_desktop_dep,
  dependency('cairo'),
  mutter_rpc_client_dep,
  libst_dep,
]

libshell_menu = static_library(
  'gnome-shell-menu',
  sources: [
    vendor_src_dir / 'gtkactionmuxer.c',
    vendor_src_dir / 'gtkactionobservable.c',
    vendor_src_dir / 'gtkactionobserver.c',
  ],
  dependencies: [dependency('gio-2.0'), clutter_dep, mtk_dep],
  include_directories: shell_inc,
)

libshell_menu_dep = declare_dependency(link_with: libshell_menu)

subdir('shell-js')

libshell_public_headers = [
  'shell-app.h', 'shell-app-system.h', 'shell-app-usage.h', 'shell-blur-effect.h',
  'shell-camera-monitor.h', 'shell-glsl-effect.h', 'shell-global.h',
  'shell-invert-lightness-effect.h', 'shell-action-modes.h', 'shell-mount-operation.h',
  'shell-perf-log.h', 'shell-screenshot.h', 'shell-square-bin.h', 'shell-stack.h',
  'shell-time-change-source.h', 'shell-util.h', 'shell-window-preview.h',
  'shell-window-preview-layout.h', 'shell-window-tracker.h', 'shell-wm.h',
  'shell-workspace-background.h',
]

libshell_private_headers = [
  'shell-app-private.h', 'shell-app-cache-private.h', 'shell-app-system-private.h',
  'shell-global-private.h', 'shell-window-tracker-private.h', 'shell-wm-private.h',
]

libshell_sources = [
  'gnome-shell-plugin.c', 'shell-app.c', 'shell-app-system.c', 'shell-app-usage.c',
  'shell-blur-effect.c', 'shell-camera-monitor.c', 'shell-global.c', 'shell-glsl-effect.c',
  'shell-invert-lightness-effect.c', 'shell-keyring-prompt.c', 'shell-keyring-prompt.h',
  'shell-mount-operation.c', 'shell-perf-log.c', 'shell-polkit-authentication-agent.c',
  'shell-polkit-authentication-agent.h', 'shell-screenshot.c', 'shell-secure-text-buffer.c',
  'shell-secure-text-buffer.h', 'shell-square-bin.c', 'shell-stack.c',
  'shell-time-change-source.c', 'shell-util.c', 'shell-window-preview.c',
  'shell-window-preview-layout.c', 'shell-window-tracker.c', 'shell-wm.c',
  'shell-workspace-background.c', 'shell-app-cache.c',
]

libshell_header_files = []
foreach h : libshell_public_headers + libshell_private_headers
  libshell_header_files += vendor_src_dir / h
endforeach

shell_global_rpc_append = meson.project_source_root() / 'src/shell-client/shell-global-rpc-append.c'
shell_global_patched = custom_target(
  'shell-global-patched.c',
  input: [vendor_src_dir / 'shell-global.c', shell_global_rpc_append],
  output: 'shell-global-patched.c',
  command: [
    'sh', '-c', 'cat "$1" "$2" > "$3"', 'sh',
    '@INPUT0@', '@INPUT1@', '@OUTPUT@',
  ],
)

libshell_source_files = []
foreach s : libshell_sources
  if s == 'shell-global.c'
    libshell_source_files += shell_global_patched
  else
    libshell_source_files += vendor_src_dir / s
  endif
endforeach

libshell_enums = gnome.mkenums_simple('shell-enum-types',
  sources: libshell_header_files,
)

dbus_generated = gnome.gdbus_codegen(
  'org-gtk-application',
  vendor_src_dir / 'org.gtk.Application.xml',
  namespace: 'Shell',
)

dbus_generated += gnome.gdbus_codegen(
  'switcheroo-control',
  vendor_data_dir / 'dbus-interfaces' / 'net.hadess.SwitcherooControl.xml',
  namespace: 'Shell',
)

libshell = shared_library(
  'shell-' + mutter_api_version,
  libshell_enums,
  libshell_header_files,
  libshell_source_files,
  js_resources,
  dbus_generated,
  st_shell_headers,
  c_args: shell_cflags,
  dependencies: shell_deps + [libshell_menu_dep],
  include_directories: shell_inc,
  build_rpath: client_rpath,
  name_prefix: 'lib',
  install: false,
)

libshell_dep = declare_dependency(
  link_with: libshell,
  dependencies: [libst_dep, mutter_rpc_client_dep],
  include_directories: shell_inc,
)

gvc_gir_dir = '/usr/share/gnome-shell'
gvc_gir = gvc_gir_dir / 'Gvc-1.0.gir'
if not fs.exists(gvc_gir)
  error('Gvc-1.0.gir not found at @0@ — install gnome-shell dev/reference package'.format(gvc_gir))
endif

libshell_gir_includes = [
  'Clutter-' + mutter_api_version,
  'Meta-' + mutter_api_version,
  'Gcr-4',
  'PolkitAgent-1.0',
  'GdkPixbuf-2.0',
  'Gvc-1.0',
  libst_gir[0],
]

libshell_gir = gnome.generate_gir(
  libshell,
  sources: libshell_enums + libshell_header_files + libshell_source_files,
  nsversion: mutter_api_version,
  namespace: 'Shell',
  includes: libshell_gir_includes,
  dependencies: shell_deps,
  include_directories: shell_inc,
  extra_args: [
    '--quiet',
    '--add-include-path=' + mutter_gir_dir,
    '--add-include-path=' + meta_gir_dir,
    '--add-include-path=' + gvc_gir_dir,
    '-I' + vendor_src_dir,
    '-I' + vendor_st_dir,
    '-I' + meson.current_build_dir(),
  ],
  install: false,
)

message('gnome-shell client libs: libshell-16 linked to libmutter-rpc-16')
