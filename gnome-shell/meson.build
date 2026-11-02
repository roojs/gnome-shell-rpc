# Phase 0.7: vendored upstream gnome-shell for build/CI.
# meson setup checks out vendor/gnome-shell if it is missing or the wrong major.
# Stock libst / St GIR still come from the distro gnome-shell package.
# vendor/gnome-shell/js is compiled into the client gresource. The client runs that.

fs = import('fs')

# --- Build-time: vendor checkout (required for JS gresource / shell-js) ---
# Pin follows the mutter detected in the parent meson.build (48.0 or 50.0).
# auto (default): use/fix vendor under vendor/gnome-shell/.
# enabled: same + honor gnome_shell_vendor_refresh.
# disabled: refuse.

vendor_root = meson.project_source_root() / 'vendor' / 'gnome-shell'
fetch_script = meson.project_source_root() / 'scripts' / 'gnome-shell-fetch.sh'
vendor_js = vendor_root / 'js'
vendor_gnome_shell = get_option('vendor_gnome_shell')
gnome_shell_vendor_root = ''

# Pin follows the mutter detected in the parent meson.build.
# Option default 48.0 means "use that pin", including 50.0 when mutter is 18.
ref_opt = get_option('gnome_shell_vendor_ref')
ref_opt_lower = ref_opt.to_lower()
if ref_opt_lower == '' or ref_opt_lower == 'head' or ref_opt_lower == 'main' or ref_opt == '48.0'
  ref = gnome_shell_target_ref
elif ref_opt.startswith(gnome_shell_target_major + '.')
  ref = ref_opt
else
  error(
    'gnome_shell_vendor_ref=@0@ is not a @1@.x ref — this configure is mutter @2@, gnome-shell @1@.\n'.format(
      ref_opt,
      gnome_shell_target_major,
      mutter_api_version,
    ) +
    '  Omit the option or pass e.g. -Dgnome_shell_vendor_ref=@0@'.format(gnome_shell_target_ref),
  )
endif

refresh = get_option('gnome_shell_vendor_refresh')

if vendor_gnome_shell.disabled()
  error(
    'vendor_gnome_shell=disabled, but the build needs vendor/gnome-shell for the JS gresource.\n' +
    '  Reconfigure without that flag (default is auto).',
  )
endif

# First "version:" line in vendor meson.build is project(). Empty if missing.
vendor_version = ''
if fs.exists(vendor_root / 'meson.build')
  foreach line : fs.read(vendor_root / 'meson.build').split('\n')
    stripped = line.strip()
    if stripped.startswith('version:')
      vendor_version = stripped.contains('\'') ? stripped.split('\'')[1] : stripped.split('"')[1]
      break
    endif
  endforeach
endif

need_clone = not fs.exists(vendor_js)
vendor_major = vendor_version != '' ? vendor_version.split('.')[0] : ''
need_repin = vendor_major != '' and vendor_major != gnome_shell_target_major
need_fetch = need_clone or refresh or need_repin or (not fs.exists(vendor_js))

if need_fetch
  if need_repin
    message(
      'gnome-shell vendor is @0@ (not @1@.x) — checking out @2@'.format(
        vendor_version,
        gnome_shell_target_major,
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
  vendor_version = ''
  foreach line : fs.read(vendor_root / 'meson.build').split('\n')
    stripped = line.strip()
    if stripped.startswith('version:')
      vendor_version = stripped.contains('\'') ? stripped.split('\'')[1] : stripped.split('"')[1]
      break
    endif
  endforeach
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
    'Could not read project version from @0@/meson.build — cannot verify target @1@.'.format(
      vendor_root,
      gnome_shell_target_major,
    ),
  )
endif
vendor_major = vendor_version.split('.')[0]
if vendor_major != gnome_shell_target_major
  error(
    'vendor/gnome-shell is still version @0@ after checkout of @1@ — expected @2@.x.\n'.format(
      vendor_version,
      ref,
      gnome_shell_target_major,
    ) +
    '  Run: ./scripts/gnome-shell-fetch.sh --ref=@0@ --refresh'.format(ref),
  )
endif

gnome_shell_vendor_root = vendor_root
message(
  'gnome-shell vendor root: @0@ (version @1@; compiled into client gresource; not installed)'.format(
    gnome_shell_vendor_root,
    vendor_version,
  ),
)
# --- Stock distro St (server only) + St-16.gir schema ---
# mutter-rpc links stock libst-16.so (same model as Meta via libmutter).
# Client St is libst-rpc-16.so + build-tree St-16.typelib — NOT these distro typelibs.
# Distro St-16.gir is only the API schema input for gi-stub-gen / g-ir-compiler.

# Debian/Ubuntu: /usr/lib/gnome-shell. Fedora: /usr/lib64/gnome-shell.
gnome_shell_pkglibdir = '/usr/lib/gnome-shell'
foreach candidate : ['/usr/lib/gnome-shell', '/usr/lib64/gnome-shell']
  if fs.exists(candidate / 'libst-@0@.so'.format(mutter_api_version))
    gnome_shell_pkglibdir = candidate
    break
  endif
endforeach
gnome_shell_girdir = '/usr/share/gnome-shell'
gnome_shell_st_lib = gnome_shell_pkglibdir / 'libst-@0@.so'.format(mutter_api_version)
gnome_shell_st_girdir = gnome_shell_girdir
gnome_shell_st_gir = gnome_shell_girdir / 'St-@0@.gir'.format(mutter_api_version)

missing_stock = []
if not fs.exists(gnome_shell_st_lib)
  missing_stock += ['@0@ — stock libst for mutter-rpc (server)'.format(gnome_shell_st_lib)]
endif
# Ubuntu 26.04 ships St-18.typelib next to libst-18.so and does not install St-18.gir.
# g-ir-generate rebuilds the schema the client typelib compiler needs.
if not fs.exists(gnome_shell_st_gir)
  st_typelib = gnome_shell_pkglibdir / 'St-@0@.typelib'.format(mutter_api_version)
  if fs.exists(st_typelib)
    g_ir_generate = find_program('g-ir-generate', required: true)
    xsltproc = find_program('xsltproc', required: true)
    gnome_shell_st_girdir = meson.current_build_dir()
    gnome_shell_st_gir = gnome_shell_st_girdir / 'St-@0@.gir'.format(mutter_api_version)
    run_command(
      find_program('sh'),
      meson.project_source_root() / 'scripts/st-gir-from-typelib.sh',
      g_ir_generate.full_path(),
      gnome_shell_st_gir,
      st_typelib,
      gnome_shell_pkglibdir + ':' + mutter_typelib_dir,
      xsltproc.full_path(),
      meson.project_source_root() / 'scripts/st-gir-fix.xsl',
      check: true,
    )
    message('St-@0@.gir generated from @1@'.format(mutter_api_version, st_typelib))
  else
    missing_stock += ['@0@ — St API schema for libst-rpc (client stubs)'.format(gnome_shell_st_gir)]
  endif
endif
if missing_stock.length() > 0
  error(
    'Stock gnome-shell St inputs missing:\n  - '
    + '\n  - '.join(missing_stock)
    + '\nInstall the distro package, then re-run meson setup:\n'
    + '  sudo apt install gnome-shell\n'
    + 'Client runtime still uses build/src St-@0@.typelib → libst-rpc-@0@.so, not distro St typelib.'.format(mutter_api_version),
  )
endif

message('gnome-shell stock pkglibdir (server libst/Gvc): @0@'.format(gnome_shell_pkglibdir))
message('gnome-shell stock girdir (St-@0@.gir schema only): @1@'.format(mutter_api_version, gnome_shell_st_girdir))

# --- Optional disk override (gjs-embed / GNOME_SHELL_JS_DIR) ---
# The client runs resource:///org/gnome/shell from the gresource built out of
# vendor/gnome-shell/js. A directory is only used when this option or the env
# var is set.

js_dir_override = get_option('gnome_shell_js_dir')
if js_dir_override != ''
  gnome_shell_js_runtime_dir = js_dir_override
  js_runtime_source = 'option -Dgnome_shell_js_dir'
else
  gnome_shell_js_runtime_dir = ''
  js_runtime_source = 'client gresource (vendor JS compiled in)'
endif

message(
  'gnome-shell runtime JS dir: @0@ (@1@)'.format(
    gnome_shell_js_runtime_dir,
    js_runtime_source,
  ),
)
