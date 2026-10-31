# QEMU test guest

One libvirt domain per Ubuntu release. The guest for the current phase is **Ubuntu 26.04** (resolute), used to log into the GNOME Shell 50 package from [`plans/0.9-multi-shell-series.md`](plans/0.9-multi-shell-series.md).

The host is an Ubuntu machine with KVM. Commands use the system connection, `qemu:///system`. Walk the steps in order. Each step ends with a check.

A new release gets a new domain. Name it after the release (`ubuntu26.04`). Leave any existing release’s domain and disk in place.

## 1. Install QEMU and libvirt

```bash
sudo apt install \
  qemu-system-x86 \
  qemu-system-gui \
  ovmf \
  libvirt-daemon-system \
  libvirt-clients \
  virtinst \
  virt-viewer \
  virt-manager \
  libosinfo-bin
```

`ovmf` is the UEFI firmware. `virt-viewer` is the window `virt-install` opens for the desktop installer. `virt-manager` is the separate domain list. `libosinfo-bin` provides `osinfo-query`.

Check:

```bash
test -c /dev/kvm && echo "kvm ok"
systemctl is-active libvirtd
virsh --version
virt-install --version
```

`/dev/kvm` exists and `libvirtd` prints `active`.

`inactive` means the daemon exited. The socket can still be listening. Read the last start:

```bash
journalctl -u libvirtd -n 20 --no-pager
```

`Failed to parse user 'libvirt-qemu'` means that account was missing, so the QEMU driver did not start and the service stopped. The account comes from `libvirt-daemon-driver-qemu`. Confirm it:

```bash
getent passwd libvirt-qemu
```

A line for `libvirt-qemu` means the account is there. If `getent` prints nothing, install the driver again so its postinst creates the account:

```bash
sudo apt install --reinstall libvirt-daemon-driver-qemu
getent passwd libvirt-qemu
```

The daemon stays stopped until a client connects. This login may not be in the `libvirt` group yet, and the socket allows that group. Connect once with the group:

```bash
sg libvirt -c 'virsh -c qemu:///system list --all'
systemctl is-active libvirtd
```

`virsh` prints a table and exits 0. The table may be empty. `libvirtd` prints `active`.

## 2. Groups

The user running `virsh` needs `kvm` and `libvirt`.

```bash
sudo usermod -aG kvm,libvirt "$USER"
```

The group list of this login does not change. A new terminal on the same login still lacks `libvirt`. Open a shell that has the group:

```bash
newgrp libvirt
```

Commands in that shell can open the socket. To run one command from the original shell, use `sg libvirt -c '...'`. `virt-manager` from the application menu still uses this login's groups. Start it with `sg libvirt virt-manager`.

A later login has `libvirt` already. There the commands below run as written, without `sg` or `newgrp`.

Check, in the `newgrp` shell:

```bash
groups | grep -q '\bkvm\b' && groups | grep -q '\blibvirt\b' && echo "groups ok"
virsh -c qemu:///system list --all
```

The list command prints a table and exits 0. The table may be empty. From the original shell the same list is `sg libvirt -c 'virsh -c qemu:///system list --all'`.

## 3. Default NAT network

Guests use `192.168.122.0/24`.

From this login, every `virsh` and `virt-install` below is wrapped with `sg libvirt -c`. A later login that already has the group can drop that wrapper and run the inner command.

```bash
sg libvirt -c 'virsh -c qemu:///system net-start default'
sg libvirt -c 'virsh -c qemu:///system net-autostart default'
```

`net-start` prints “already active” when the network came up with libvirt. That still counts as success.

Check:

```bash
sg libvirt -c 'virsh -c qemu:///system net-list'
```

`default` is `active`, and autostart is `yes`.

## 4. Desktop ISO

Use the desktop amd64 image so the guest has GDM and GNOME Shell. Point releases live in the same directory. Take the newest `ubuntu-26.04.*-desktop-amd64.iso` listed at:

https://releases.ubuntu.com/26.04/

The commands below use the 26.04.1 image. Substitute the filename you downloaded.

```bash
cd "$HOME/Downloads"
wget -c https://releases.ubuntu.com/26.04/SHA256SUMS
wget -c https://releases.ubuntu.com/26.04/ubuntu-26.04.1-desktop-amd64.iso
grep ubuntu-26.04.1-desktop-amd64.iso SHA256SUMS | sha256sum -c -
```

Check: `sha256sum -c` prints `OK` for that ISO.

QEMU runs as `libvirt-qemu`. That account cannot search a home directory that mode `750` closes to other users, so an ISO under `~/Downloads` fails with `Permission denied`. Copy it to `/var/lib/libvirt/boot/`, which is already traversable by that account:

```bash
sudo install -m 0644 \
  "$HOME/Downloads/ubuntu-26.04.1-desktop-amd64.iso" \
  /var/lib/libvirt/boot/
```

Check:

```bash
sudo -u libvirt-qemu test -r /var/lib/libvirt/boot/ubuntu-26.04.1-desktop-amd64.iso && echo "iso readable"
```

`iso readable` means the hypervisor can open the file.

## 5. Create the domain

These sizes suit a GNOME desktop: 8 GiB RAM, 4 vCPUs, 48 GiB sparse qcow2. libvirt stores the disk in the default pool, `/var/lib/libvirt/images/ubuntu26.04.qcow2`.

`--os-variant` selects default hardware. The installed release is the ISO. Use `ubuntu26.04` when the database has that id. Otherwise use the newest Ubuntu id it does have. A database that stops at 25.10 uses `ubuntu25.10`. `generic` warns and picks a poorer machine profile.

```bash
osinfo-query os | grep ubuntu26.04 || osinfo-query os | grep '| Ubuntu ' | tail -1
```

Put that short id in `--os-variant`. The command below uses `ubuntu25.10` for a database with no 26.04 row.

```bash
sg libvirt -c "virt-install \
  --connect qemu:///system \
  --name ubuntu26.04 \
  --memory 8192 \
  --vcpus 4 \
  --cpu host-passthrough \
  --disk size=48,format=qcow2,bus=virtio \
  --cdrom /var/lib/libvirt/boot/ubuntu-26.04.1-desktop-amd64.iso \
  --os-variant ubuntu25.10 \
  --network network=default,model=virtio \
  --graphics spice \
  --video virtio \
  --boot uefi \
  --autoconsole graphical"
```

A virt-viewer window opens on the Ubuntu installer. If the launch fails with `No such file or directory`, the domain is still running and `virt-viewer` is missing. Install it, then connect:

```bash
sudo apt install virt-viewer
sg libvirt -c 'virt-viewer --connect qemu:///system --wait ubuntu26.04'
```

- Choose a normal installation.
- Turn on **Install OpenSSH server**.
- Create the user you will `ssh` in as.

After the installer reboots, the ISO can still be attached. If the guest boots the installer again, eject it and start from the disk:

```bash
sg libvirt -c 'virsh -c qemu:///system destroy ubuntu26.04'
sg libvirt -c 'virsh -c qemu:///system change-media ubuntu26.04 sda --eject'
sg libvirt -c 'virsh -c qemu:///system start ubuntu26.04'
```

`sda` is the CD target in `sg libvirt -c 'virsh -c qemu:///system dumpxml ubuntu26.04'`. Use the target name that dump shows.

Check:

```bash
sg libvirt -c 'virsh -c qemu:///system list --all'
sg libvirt -c 'virsh -c qemu:///system domblklist ubuntu26.04'
```

The domain exists. After eject, the CD row has no ISO path. The qcow2 row remains.

## 6. Confirm the release

On the guest, install the guest agent so libvirt can report the address:

```bash
sudo apt install qemu-guest-agent
```

On the host:

```bash
sg libvirt -c 'virsh -c qemu:///system domifaddr ubuntu26.04'
```

`ssh` to that address. On the guest, confirm the release, give that user passwordless sudo, and add the [roojs package repository](https://roojs.github.io/repos/). The sudoers line is `$USER ALL=(ALL) NOPASSWD: ALL`. The suite in the source entry comes from `lsb_release -cs` (`resolute` on this guest). Same APT setup as [`build.md`](build.md).

```bash
. /etc/os-release && echo "$VERSION"
gnome-shell --version
sudo tee "/etc/sudoers.d/$USER" >/dev/null <<EOF
$USER ALL=(ALL) NOPASSWD: ALL
EOF
sudo chmod 0440 "/etc/sudoers.d/$USER"
sudo visudo -cf "/etc/sudoers.d/$USER"
sudo -n true && echo "nopasswd ok"
sudo apt install curl gnupg
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://roojs.github.io/repos/key.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/roojs.gpg
curl -fsSL https://roojs.github.io/repos/sources \
  | sed "s/@suite@/$(lsb_release -cs)/" \
  | sudo tee /etc/apt/sources.list.d/roojs.sources
sudo apt update
sudo apt install libocrpc-dev
```

`VERSION` contains `26.04`, `gnome-shell --version` prints a 50.x release, `visudo` prints `parsed OK`, and `sudo -n true` prints `nopasswd ok`. `apt update` reads the roojs source, and `libocrpc-dev` installs from it. Installing the resolute `gnome-shell-rpc` package comes later, in the 0.9 plan.
