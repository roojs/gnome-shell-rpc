# Phase 0.7: vendored upstream gnome-shell for build/CI reference only.
# Does not install upstream JS — runtime JS comes from distro gnome-shell package.

fs = import('fs')

vendor_gnome_shell = get_option('vendor_gnome_shell')
if vendor_gnome_shell.disabled()
  message('vendor gnome-shell disabled — skipping fetch')
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
  gnome_shell_js_dir = vendor_js
endif
