# One package per distro release, built for that release's mutter. This spec
# is the mutter 16 (shell 48) generation: libmutter-rpc-16, mutter-rpc-16/.
#
# Build with scripts/ci/build-rpm.sh, or:
#   rpmbuild -bb --define "gsr_version 0.1.0" packaging/rpm/gnome-shell-rpc.spec

Name: gnome-shell-rpc
Version: %{gsr_version}
Release: 1%{?dist}
Summary: GNOME Shell RPC
License: GPL-2.0-or-later
URL: https://github.com/roojs/gnome-shell-rpc
Source0: gnome-shell-rpc-%{version}.tar.gz

BuildRequires: meson
BuildRequires: ninja-build
BuildRequires: gcc
BuildRequires: vala
BuildRequires: gobject-introspection
BuildRequires: gobject-introspection-devel
BuildRequires: python3
BuildRequires: libxslt
BuildRequires: git-core
BuildRequires: systemd-rpm-macros
BuildRequires: pkgconfig(systemd)
BuildRequires: pkgconfig(libsystemd)
BuildRequires: pkgconfig(libmutter-16) >= 48
BuildRequires: pkgconfig(libmutter-16) < 49
BuildRequires: gnome-shell >= 48
BuildRequires: gnome-shell < 49
BuildRequires: gjs
BuildRequires: pkgconfig(gjs-1.0)
BuildRequires: libocrpc-devel >= 1.4.0
BuildRequires: pkgconfig(gee-0.8)
BuildRequires: pkgconfig(glib-2.0)
BuildRequires: pkgconfig(gio-unix-2.0)
BuildRequires: pkgconfig(json-glib-1.0)
BuildRequires: pkgconfig(libsoup-3.0)
BuildRequires: pkgconfig(atk)
BuildRequires: pkgconfig(cairo)
BuildRequires: pkgconfig(pango)
BuildRequires: pkgconfig(pangocairo)
BuildRequires: pkgconfig(graphene-gobject-1.0)
BuildRequires: pkgconfig(gdk-pixbuf-2.0)
BuildRequires: pkgconfig(x11)
BuildRequires: pkgconfig(libnm)
BuildRequires: pkgconfig(libsecret-1)
BuildRequires: pkgconfig(polkit-agent-1)
BuildRequires: pkgconfig(polkit-gobject-1)
BuildRequires: pkgconfig(gcr-4)
BuildRequires: pkgconfig(gtk4)

Requires: gnome-shell >= 48
Requires: gnome-shell < 49
Requires: gnome-session
Requires: libocrpc%{?_isa} >= 1.4.0
Recommends: (gdm or lightdm)

%description
GNOME Shell RPC session for GDM and LightDM, built for mutter 16.

%prep
%autosetup -p1

%build
%meson
%meson_build

%install
# gsr-server / gsr-client RUNPATH lists %{_libdir} beside mutter-16 and
# gnome-shell's pkglibdir.
export QA_RPATHS=$(( 0x0001 ))
%meson_install

%files
%license COPYING
%{_bindir}/gsr-client
%{_bindir}/gsr-server
%{_bindir}/gsr-session
%{_libdir}/libgsr-rpc-16.so
%{_libdir}/libmutter-clutter-rpc-16.so
%{_libdir}/libmutter-rpc-16.so
%{_libdir}/libshell-16.so
%{_libdir}/libst-rpc-16.so
%{_libdir}/mutter-rpc-16/
%{_libdir}/pkgconfig/libmutter-clutter-rpc-16.pc
%{_libdir}/pkgconfig/libmutter-rpc-16.pc
%{_libdir}/pkgconfig/libst-rpc-16.pc
%{_includedir}/mutter-clutter-rpc-16/
%{_datadir}/wayland-sessions/gsr.desktop
%{_datadir}/gnome-session/sessions/gsr.session
%{_datadir}/applications/org.gnome.ShellRpc.desktop
%{_userunitdir}/org.gnome.ShellRpc.target
%{_userunitdir}/org.gnome.ShellRpc@.service
%{_userunitdir}/gnome-session@gsr.target.d/
