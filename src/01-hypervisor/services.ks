# Keyboard layout
keyboard us

# Language of the installer
lang en_US

# Remove all partitions
clearpart --all

# Reinitialize partion tables
zerombr

# Format partions automatically
autopart --type=thinp

# Disable initial setup
firstboot --disable

# Configure network settings
network --activate --bootproto=static --gateway=192.168.200.1 --ip=192.168.200.254 --ipv6=auto --nameserver=192.168.200.1 --netmask=255.255.255.0
network --hostname=services.okd.example.com

# Use CDROM as installation device
url --mirrorlist="https://mirrors.fedoraproject.org/metalink?repo=fedora-34&arch=x86_64"
repo --name=fedora-updates --mirrorlist="https://mirrors.fedoraproject.org/metalink?repo=updates-released-f34&arch=x86_64" --cost=0
repo --name=rpmfusion-free --mirrorlist="https://mirrors.rpmfusion.org/metalink?repo=free-fedora-34&arch=x86_64" --includepkgs=rpmfusion-free-release
repo --name=rpmfusion-free-updates --mirrorlist="https://mirrors.rpmfusion.org/metalink?repo=free-fedora-updates-released-34&arch=x86_64" --cost=0
repo --name=rpmfusion-nonfree --mirrorlist="https://mirrors.rpmfusion.org/metalink?repo=nonfree-fedora-34&arch=x86_64" --includepkgs=rpmfusion-nonfree-release
repo --name=rpmfusion-nonfree-updates --mirrorlist="https://mirrors.rpmfusion.org/metalink?repo=nonfree-fedora-updates-released-34&arch=x86_64" --cost=0

bootloader --location=mbr

# Use text mode for installation
text

%packages
bind
bind-utils
chrony
dhcp-server
git
haproxy
httpd
httpd-tools
jq
libvirt
podman
skopeo
syslinux
tftp-server
xinetd
openssl
%end

# Reboot after installation is complete
reboot --eject
