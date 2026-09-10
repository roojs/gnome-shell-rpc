# Phase 0.7: vendored upstream gnome-shell for build/CI.
# Stock libst / St GIR still come from the distro gnome-shell package when present.
# Runtime JS prefers distro; falls back to vendor for dev machines without a full install.

fs = import('fs')

# --- Build-time: vendor checkout (required for JS gresource / shell-js) ---
# Target is gnome-shell 48 only. No -Dgnome_shell_vendor_ref needed: configure
# always pins vendor to 48.0 when missing or when the tree is another major.
# auto (default): use/fix vendor under vendor/gnome-shell/.
# enabled: same + honor gnome_shell_vendor_refresh.
# disabled: refuse.

vendor_root = meson.project_source_root() / 'vendor' / 'gnome-shell'
fetch_script = meson.project_source_root() / 'scripts' / 'gnome-shell-fetch.sh'
vendor_js = vendor_root / 'js'
vendor_gnome_shell = get_option('vendor_gnome_shell')
gnome_shell_vendor_root = ''

# Hard target while this project supports 48 only (ignore stale builddir "head").
gnome_shell_target_ref = '48.0'
ref_opt = get_option('gnome_shell_vendor_ref').to_lower()
if ref_opt == '' or ref_opt == 'head' or ref_opt == 'main'
  ref = gnome_shell_target_ref
elif ref_opt.startswith('48.')
  ref = get_option('gnome_shell_vendor_ref')
else
  error(
    'gnome_shell_vendor_ref=@0@ is not a 48.x ref — this project only targets gnome-shell 48.\n'.format(
      get_option('gnome_shell_vendor_ref'),
    ) +
    '  Omit the option (defaults to 48.0) or pass e.g. -Dgnome_shell_vendor_ref=48.1',
  )
endif

refresh = get_option('gnome_shell_vendor_refresh')

if vendor_gnome_shell.disabled()
  error(
    'vendor_gnome_shell=disabled, but the build needs vendor/gnome-shell for the JS gresource.\n' +
    '  Reconfigure without that flag (default is auto).',
  )
endif

# Read upstream project() version from vendor meson.build (empty if missing).
vendor_version = ''
if fs.exists(vendor_root / 'meson.build')
  vendor_ver_cmd = run_command(
    'python3', '-c',
    'import re, sys\n' +
    'text = open(sys.argv[1], encoding="utf-8").read()\n' +
    'm = re.search(r"project\\(\\s*[\'\\"]gnome-shell[\'\\"][^)]*?version:\\s*[\'\\"]([^\'\\"]+)[\'\\"]", text, re.S)\n' +
    'print(m.group(1) if m else "")\n',
    vendor_root / 'meson.build',
    check: true,
  )
  vendor_version = vendor_ver_cmd.stdout().strip()
endif

need_clone = not fs.exists(vendor_js)
vendor_major = vendor_version != '' ? vendor_version.split('.')[0] : ''
need_repin = vendor_major != '' and vendor_major != '48'
need_fetch = need_clone or refresh or need_repin or (not fs.exists(vendor_js))

if need_fetch
  if need_repin
    message(
      'gnome-shell vendor is @0@ (not 48.x) — checking out @1@'.format(
        vendor_version,
        ref,
      ),
    )
  elif need_clone
    message('gnome-shell vendor missing — fetching @0@'.format(ref))
  endif
  fetch_env = environment()
  fetch_env.set('GNOME_SHELL_VENDOR_REF', ref)
  # Always refresh when re-pinning or explicitly requested so checkout moves.
  fetch_env.set(
    'GNOME_SHELL_VENDOR_REFRESH',
    (refresh or need_repin or need_clone) ? '1' : '0',
  )
  fetch_cmd = run_command(
    fetch_script,
    env: fetch_env,
    check: false,
  )
  if fetch_cmd.returncode() != 0
    error(
      'scripts/gnome-shell-fetch.sh failed (need network once for vendor @0@):\n'.format(ref)
      + fetch_cmd.stderr()
      + fetch_cmd.stdout(),
    )
  endif
  message(fetch_cmd.stdout().strip())
  # Re-read version after fetch/checkout.
  vendor_ver_cmd = run_command(
    'python3', '-c',
    'import re, sys\n' +
    'text = open(sys.argv[1], encoding="utf-8").read()\n' +
    'm = re.search(r"project\\(\\s*[\'\\"]gnome-shell[\'\\"][^)]*?version:\\s*[\'\\"]([^\'\\"]+)[\'\\"]", text, re.S)\n' +
    'print(m.group(1) if m else "")\n',
    vendor_root / 'meson.build',
    check: true,
  )
  vendor_version = vendor_ver_cmd.stdout().strip()
elif fs.exists(vendor_root / '.git')
  sha_cmd = run_command('git', '-C', vendor_root, 'rev-parse', '--short', 'HEAD', check: true)
  message(
    'gnome-shell vendor: using existing checkout @0@ (@1@)'.format(
      sha_cmd.stdout().strip(),
      vendor_version,
    ),
  )
endif

if not fs.exists(vendor_js)
  error(
    'vendor/gnome-shell/js still missing after fetch.\n' +
    '  Run: ./scripts/gnome-shell-fetch.sh\n' +
    '  then: meson setup --reconfigure build',
  )
endif

if vendor_version == ''
  error(
    'Could not read project version from @0@/meson.build — cannot verify target 48.'.format(
      vendor_root,
    ),
  )
endif
vendor_major = vendor_version.split('.')[0]
if vendor_major != '48'
  error(
    'vendor/gnome-shell is still version @0@ after checkout of @1@ — expected 48.x.\n'.format(
      vendor_version,
      ref,
    ) +
    '  Run: ./scripts/gnome-shell-fetch.sh --ref=@0@ --refresh'.format(ref),
  )
endif

gnome_shell_vendor_root = vendor_root
message(
  'gnome-shell vendor root: @0@ (version @1@; build/CI only; JS not installed)'.format(
    gnome_shell_vendor_root,
    vendor_version,
  ),
)
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
