# Phase 0.7: vendored upstream gnome-shell for build/CI.
# Stock libst / St GIR still come from the distro gnome-shell package when present.
# Runtime JS prefers distro; falls back to vendor for dev machines without a full install.

fs = import('fs')

# --- Build-time: vendor checkout (required for JS gresource / shell-js) ---
# auto (default): use vendor/gnome-shell if present; else clear error (no -D flag after fetch).
# enabled: run scripts/gnome-shell-fetch.sh when missing or when refresh is set.
# disabled: refuse even if the tree exists.

vendor_root = meson.project_source_root() / 'vendor' / 'gnome-shell'
fetch_script = meson.project_source_root() / 'scripts' / 'gnome-shell-fetch.sh'
vendor_js = vendor_root / 'js'
vendor_gnome_shell = get_option('vendor_gnome_shell')
gnome_shell_vendor_root = ''

if vendor_gnome_shell.disabled()
  error(
    'vendor_gnome_shell=disabled, but the build needs vendor/gnome-shell for the JS gresource.\n' +
    '  Reconfigure without that flag (default is auto), then:\n' +
    '    ./scripts/gnome-shell-fetch.sh\n' +
    '  and re-run meson setup/configure — no -Dvendor_gnome_shell needed once the tree exists.',
  )
endif

ref = get_option('gnome_shell_vendor_ref')
refresh = get_option('gnome_shell_vendor_refresh')
need_clone = not fs.exists(vendor_js)

# Only network-fetch when explicitly enabled (or refresh requested under enabled).
if vendor_gnome_shell.enabled() and (need_clone or refresh)
  fetch_env = environment()
  fetch_env.set('GNOME_SHELL_VENDOR_REF', ref)
  fetch_env.set('GNOME_SHELL_VENDOR_REFRESH', refresh ? '1' : '0')
  fetch_cmd = run_command(
    fetch_script,
    env: fetch_env,
    check: false,
  )
  if fetch_cmd.returncode() != 0
    error('scripts/gnome-shell-fetch.sh failed:\n@0@'.format(fetch_cmd.stderr()))
  endif
  message(fetch_cmd.stdout().strip())
elif fs.exists(vendor_root / '.git')
  sha_cmd = run_command('git', '-C', vendor_root, 'rev-parse', '--short', 'HEAD', check: true)
  message('gnome-shell vendor: using existing checkout @0@'.format(sha_cmd.stdout().strip()))
endif

if not fs.exists(vendor_js)
  error(
    'vendor/gnome-shell is missing (needed for JS gresource / config.js app lists).\n' +
    '  Fetch once, then reconfigure — Meson auto-detects the tree (no -D flag):\n' +
    '    ./scripts/gnome-shell-fetch.sh\n' +
    '    meson setup --reconfigure build\n' +
    '  Or let Meson clone: meson setup build -Dvendor_gnome_shell=enabled',
  )
endif

gnome_shell_vendor_root = vendor_root
message('gnome-shell vendor root: @0@ (build/CI only; JS not installed)'.format(gnome_shell_vendor_root))

# --- Stock distro St (server only) + St-16.gir schema ---
# mutter-rpc links stock libst-16.so (same model as Meta via libmutter).
# Client St is libst-rpc-16.so + build-tree St-16.typelib — NOT these distro typelibs.
# Distro St-16.gir is only the API schema input for gi-stub-gen / g-ir-compiler.

gnome_shell_pkglibdir = '/usr/lib/gnome-shell'
gnome_shell_girdir = '/usr/share/gnome-shell'
gnome_shell_st_lib = gnome_shell_pkglibdir / 'libst-16.so'
gnome_shell_st_gir = gnome_shell_girdir / 'St-16.gir'

missing_stock = []
if not fs.exists(gnome_shell_st_lib)
  missing_stock += ['@0@ — stock libst for mutter-rpc (server)'.format(gnome_shell_st_lib)]
endif
if not fs.exists(gnome_shell_st_gir)
  missing_stock += ['@0@ — St API schema for libst-rpc (client stubs)'.format(gnome_shell_st_gir)]
endif
if missing_stock.length() > 0
  error(
    'Stock gnome-shell St inputs missing:\n  - '
    + '\n  - '.join(missing_stock)
    + '\nInstall the distro package, then re-run meson setup:\n'
    + '  sudo apt install gnome-shell\n'
    + 'Client runtime still uses build/src St-16.typelib → libst-rpc-16.so, not distro St typelib.',
  )
endif

message('gnome-shell stock pkglibdir (server libst/Gvc): @0@'.format(gnome_shell_pkglibdir))
message('gnome-shell stock girdir (St-16.gir schema only): @0@'.format(gnome_shell_girdir))

# --- Runtime JS search path (gjs-embed / overrides) ---
# Prefer distro; if absent, fall back to vendor (dev machines without gnome-shell.pc / unpacked js/).

js_dir_override = get_option('gnome_shell_js_dir')
js_runtime_source = ''
if js_dir_override != ''
  gnome_shell_js_runtime_dir = js_dir_override
  js_runtime_source = 'option -Dgnome_shell_js_dir'
else
  # Prefer on-disk paths (no pkg-config noise when gnome-shell.pc is absent).
  gnome_shell_js_runtime_dir = ''
  prefix_js = get_option('prefix') / get_option('datadir') / 'gnome-shell' / 'js'
  if fs.exists('/usr/share/gnome-shell/js')
    gnome_shell_js_runtime_dir = '/usr/share/gnome-shell/js'
    js_runtime_source = '/usr/share/gnome-shell/js'
  elif fs.exists(prefix_js)
    gnome_shell_js_runtime_dir = prefix_js
    js_runtime_source = 'prefix'
  else
    gnome_shell_pc = dependency('gnome-shell', required: false)
    if gnome_shell_pc.found()
      jsdir = gnome_shell_pc.get_variable('jsdir', default_value: '')
      if jsdir != '' and fs.exists(jsdir)
        gnome_shell_js_runtime_dir = jsdir
        js_runtime_source = 'gnome-shell.pc jsdir'
      else
        pkgdatadir = gnome_shell_pc.get_variable('pkgdatadir', default_value: '')
        if pkgdatadir != '' and fs.exists(pkgdatadir / 'js')
          gnome_shell_js_runtime_dir = pkgdatadir / 'js'
          js_runtime_source = 'gnome-shell.pc pkgdatadir/js'
        endif
      endif
    endif
  endif

  if gnome_shell_js_runtime_dir == ''
    if fs.exists(vendor_js)
      gnome_shell_js_runtime_dir = vendor_js
      js_runtime_source = 'vendor (no distro gnome-shell JS tree)'
    else
      error(
        'No gnome-shell JS directory found for GNOME_SHELL_JS_DIR.\n' +
        '  Distro tree missing and vendor/gnome-shell/js missing.\n' +
        '  Fix one of:\n' +
        '    ./scripts/gnome-shell-fetch.sh\n' +
        '    sudo apt install gnome-shell\n' +
        '    meson setup -Dgnome_shell_js_dir=/path/to/js',
      )
    endif
  endif
endif

message(
  'gnome-shell runtime JS dir: @0@ (@1@)'.format(
    gnome_shell_js_runtime_dir,
    js_runtime_source,
  ),
)
