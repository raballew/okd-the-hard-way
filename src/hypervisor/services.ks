# Keyboard layout
keyboard us

# Language of the installer
lang en_US.UTF-8

# Use text mode for installation
text

# Ignore disks other than sda
ignoredisk --only-use=sda

# Remove all partitions
clearpart --all --drives=sda

# Format partions automatically
autopart --type=lvm

# Disable initial setup
firstboot --disable

rootpw --plaintext secret_password_123

# Configure network settings
network --activate --bootproto=static --device=enp1s0 --gateway=192.168.200.1 --ip=192.168.200.254 --ipv6=auto --nameserver=192.168.200.1 --netmask=255.255.255.0
network --hostname=services.okd.example.com

# Use CDROM as installation device
install
url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-32&arch=x86_64"
repo --name=fedora-updates --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f32&arch=x86_64" --cost=0
repo --name=rpmfusion-free --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-32&arch=x86_64" --includepkgs=rpmfusion-free-release
repo --name=rpmfusion-free-updates --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-updates-released-32&arch=x86_64" --cost=0
repo --name=rpmfusion-nonfree --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-32&arch=x86_64" --includepkgs=rpmfusion-nonfree-release
repo --name=rpmfusion-nonfree-updates --mirrorlist="https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-updates-released-32&arch=x86_64" --cost=0

bootloader --location=mbr --driveorder=sda

# Reboot after installation is complete
reboot

%packages
bind
bind-utils
dhcp-server
git
haproxy
httpd
httpd-tools
podman
syslinux
tftp-server
xinetd
%end
