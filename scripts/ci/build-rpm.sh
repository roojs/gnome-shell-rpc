#!/usr/bin/env bash
# Build the gnome-shell-rpc RPM from the repository checkout (Fedora).
# Usage: scripts/ci/build-rpm.sh [version]
# Version defaults to project() version in meson.build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ "$#" -ge 1 ] && [ -n "$1" ]; then
  ver="$1"
else
  ver="$(sed -n "s/^  version: '\([^']*\)',$/\1/p" meson.build | head -n1)"
fi
if [ -z "$ver" ]; then
  echo "Could not determine package version" >&2
  exit 1
fi

rpm_ver="${ver//-/\~}"
echo "Building gnome-shell-rpc RPM version ${ver} (RPM ${rpm_ver})"

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

. /etc/os-release

install_roojs_fedora_repo() {
  run_root install -d -m 0755 /etc/pki/rpm-gpg
  run_root curl -fsSL https://roojs.github.io/repos/key.gpg \
    -o /etc/pki/rpm-gpg/RPM-GPG-KEY-roojs
  run_root rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-roojs
  run_root curl -fsSL https://roojs.github.io/repos/repo \
    -o /etc/yum.repos.d/roojs.repo
  run_root sed -i \
    's|^gpgkey=.*|gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-roojs|' \
    /etc/yum.repos.d/roojs.repo
}

case "${ID}" in
  fedora)
    install_roojs_fedora_repo
    run_root dnf -y install --setopt=install_weak_deps=False \
      rpm-build rpmdevtools dnf-plugins-core
    run_root dnf -y builddep --setopt=install_weak_deps=False \
      --define "gsr_version ${rpm_ver}" \
      packaging/rpm/gnome-shell-rpc.spec
    ;;
  *)
    echo "Unsupported distro for RPM build: ${ID}" >&2
    exit 1
    ;;
esac

# rpmbuild works from a tarball; put vendor/gnome-shell (48.0) in it so
# meson setup inside rpmbuild does not clone.
./scripts/gnome-shell-fetch.sh

TOPDIR="${ROOT}/.rpmbuild"
rm -rf "$TOPDIR"
mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

tar --exclude='./.git' \
  --exclude='./vendor/gnome-shell/.git' \
  --exclude='./.rpmbuild' \
  --exclude='./build' \
  --exclude='./build-*' \
  --exclude='./artifacts' \
  --transform "s|^\\./|gnome-shell-rpc-${rpm_ver}/|" \
  -czf "${TOPDIR}/SOURCES/gnome-shell-rpc-${rpm_ver}.tar.gz" \
  .

cp packaging/rpm/gnome-shell-rpc.spec "${TOPDIR}/SPECS/gnome-shell-rpc.spec"
rpmbuild -bb \
  --define "_topdir ${TOPDIR}" \
  --define "gsr_version ${rpm_ver}" \
  "${TOPDIR}/SPECS/gnome-shell-rpc.spec"

mkdir -p "${ROOT}/artifacts"
find "${TOPDIR}/RPMS" -type f -name '*.rpm' ! -name '*.src.rpm' \
  ! -name '*debuginfo*' ! -name '*debugsource*' \
  -exec cp -v {} "${ROOT}/artifacts/" \;
ls -lh "${ROOT}/artifacts"
