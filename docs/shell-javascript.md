# Where the shell JavaScript comes from

GNOME Shell’s JavaScript is source under `js/` in the upstream tree. A normal
install does not leave that tree on disk for the shell to execute. The package
build compiles it into a **GResource** and links that into `libshell`. At run
time the process loads modules as `resource:///org/gnome/shell/…` (for example
`resource:///org/gnome/shell/ui/init.js`). On this kind of system that blob
lives inside `/usr/lib/gnome-shell/libshell-16.so`. There is no
`/usr/share/gnome-shell/js` directory to point a program at.

This client does the same kind of compile, from our own checkout, into our own
binary:

1. `meson setup` fetches upstream gnome-shell into `vendor/gnome-shell/` and
   pins it to **48.0** when that directory is missing or is not 48.x. The
   checkout is gitignored. Open `vendor/gnome-shell/js/` when you need to read
   the shell sources; workspace search will not see them.
2. The build compiles that `js/` tree (plus a generated `misc/config.js`) into
   a GResource and links it into **`gsr-client`**.
3. The client runs that resource: `resource:///org/gnome/shell/ui/init.js` and
   the modules it imports.

We do not install `vendor/gnome-shell/js`, and we do not execute the copy
inside the distro `libshell`. The distro `gnome-shell` package is still
required for **`libst-16.so`**, **`St-16.gir`**, and **`Gvc`**.

`GNOME_SHELL_JS_DIR` or **`-Dgnome_shell_js_dir=`** is an optional override
that loads a `js/` directory from disk instead. Leave both unset for the
normal client, which uses the resource built in step 2.
