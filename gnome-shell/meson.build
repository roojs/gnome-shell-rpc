# Phase 0.7: vendored upstream gnome-shell for build/CI reference only.
# Runtime JS comes from the installed gnome-shell package — not installed from here.

fs = import('fs')

# --- Runtime: distro gnome-shell JS (package dependency at install time) ---

js_dir_override = get_option('gnome_shell_js_dir')
if js_dir_override != ''
  gnome_shell_js_runtime_dir = js_dir_override
else
  gnome_shell_pc = dependency('gnome-shell', required: false)
  if gnome_shell_pc.found()
    jsdir = gnome_shell_pc.get_variable('jsdir', default_value: '')
    if jsdir != ''
      gnome_shell_js_runtime_dir = jsdir
    else
      pkgdatadir = gnome_shell_pc.get_variable('pkgdatadir', default_value: '')
      if pkgdatadir != ''
        gnome_shell_js_runtime_dir = pkgdatadir / 'js'
      else
        gnome_shell_js_runtime_dir = get_option('prefix') / get_option('datadir') / 'gnome-shell' / 'js'
      endif
    endif
  else
    prefix_js = get_option('prefix') / get_option('datadir') / 'gnome-shell' / 'js'
    if fs.exists(prefix_js)
      gnome_shell_js_runtime_dir = prefix_js
    elif fs.exists('/usr/share/gnome-shell/js')
      gnome_shell_js_runtime_dir = '/usr/share/gnome-shell/js'
    else
      gnome_shell_js_runtime_dir = prefix_js
      warning(
        'gnome-shell JS directory not found on disk (@0@) — runtime expects an installed gnome-shell package (Depends: gnome-shell)'.format(
          prefix_js,
        ),
      )
    endif
  endif
endif

message('gnome-shell runtime JS dir: @0@ (distro package; not installed by us)'.format(gnome_shell_js_runtime_dir))

# --- Build-time: vendor checkout (optional) ---

gnome_shell_vendor_root = ''
vendor_gnome_shell = get_option('vendor_gnome_shell')
if vendor_gnome_shell.disabled()
  message('vendor gnome-shell disabled — no build-time upstream checkout')
else
  vendor_root = meson.project_source_root() / 'vendor' / 'gnome-shell'
  fetch_script = meson.project_source_root() / 'scripts' / 'gnome-shell-fetch.sh'
  vendor_js = vendor_root / 'js'

  ref = get_option('gnome_shell_vendor_ref')
  refresh = get_option('gnome_shell_vendor_refresh')
  need_clone = not fs.exists(vendor_js)

  if need_clone or refresh
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
    message('gnome-shell vendor: using existing checkout @0@ (no refresh)'.format(sha_cmd.stdout().strip()))
  endif

  if not fs.exists(vendor_js)
    error('vendor/gnome-shell/js missing — run scripts/gnome-shell-fetch.sh or reconfigure with vendor enabled')
  endif

  gnome_shell_vendor_root = vendor_root
  message('gnome-shell vendor root: @0@ (build/CI only; JS not installed)'.format(gnome_shell_vendor_root))
endif
