# Hypervisor

## Packages

Install the virtualization tools via the command line using the Virtualization
Package Group. To view the packages, run:

```shell
[root@hypervisor ~]# dnf groupinfo virtualization

Group: Virtualization
 Description: These packages provide a graphical virtualization environment.
 Mandatory Packages:
   virt-install
 Default Packages:
   libvirt-daemon-config-network
   libvirt-daemon-kvm
   qemu-kvm
   virt-manager
   virt-viewer
 Optional Packages:
   guestfs-browser
   libguestfs-tools
   python3-libguestfs
   virt-top
```

Run the following command to install the mandatory and default packages in the
virtualization group:

```shell
[root@hypervisor ~]# dnf install @virtualization
```

After the packages install, start the libvirtd service:

```shell
[root@hypervisor ~]# systemctl start libvirtd
```

To start the service on boot, run:

```shell
[root@hypervisor ~]# systemctl enable libvirtd --now
```

To verify that the KVM kernel modules are properly loaded:

```shell
[root@hypervisor ~]# lsmod | grep kvm

kvm_amd                55563  0
kvm                   419458  1 kvm_amd
```

If this command lists kvm_intel or kvm_amd, KVM is properly configured.

Now install all additional required packages:

```shell
[root@hypervisor ~]# dnf install git virt-install -y
```

## Hostname

It is also a good idea to set the hostname to match fully qualified domain name
(FQDN) of the hypervisors machine:

```shell
[root@hypervisor ~]# hostnamectl set-hostname okd.example.com
```

## Repository

Clone this repository to easily access resource definitions on the hypervisor:

```shell
[root@hypervisor ~]# git clone https://github.com/raballew/okd-the-hard-way.git
```

## Storage

Libvirt provides storage management on the physical host through storage pools
and volumes. A storage pool is a dedicated quantity of storage usually reserved
by a dedicated storage administrator. Storage pools are not required for proper
operation of VMs but it is a good way to manage VM related storage.

### Storage Pool

Special disk formats such as qcow2,raw, iso, etc as supported by the qemu-img
program are used while setting up the VMs. The recommended type of pool to
manage this files is `dir`.

Create the storage pool which will be used to serve the VM disk images:

```shell
[root@hypervisor ~]# mkdir -p /okd/images/
[root@hypervisor ~]# virsh pool-define okd-the-hard-way/src/hypervisor/storage-pool.xml
[root@hypervisor ~]# virsh pool-autostart okd
[root@hypervisor ~]# virsh pool-start okd
```

### Volumes

Creating an empty disk image for each VM ensures that the content of each VM is
stored in a predefined location. This is not a mandatory step, but it helps to
simplyfy things later on.

Create the disk images:

```shell
[root@hypervisor ~]# for node in \
  bootstrap \
  control-0 control-1 control-2 \
  compute-0 compute-1 compute-2 \
  infra-0 infra-1 infra-2 ; \
do \
  qemu-img create -f qcow2 /okd/images/$node.qcow2 50G ; \
done
[root@hypervisor ~]# qemu-img create -f qcow2 /okd/images/services.qcow2 250G
```

### Fedora ISO

The services machine is the first machine that needs to be setup. All other VMs
will be bootstrapped using Preboot eXecution Environment (PXE) procedures.
Therefore the services machine is going to host PXE boot services and more.
Fedora offers all required packages to do so and will be used as the operating
system on the services VM.

Download the Fedora Server ISO file:

```shell
[root@hypervisor ~]# curl -X GET 'https://download.fedoraproject.org/pub/fedora/linux/releases/32/Server/x86_64/iso/Fedora-Server-dvd-x86_64-32-1.6.iso' -o /okd/images/Fedora-Server-dvd-x86_64-32-1.6.iso -L
```

## Network

### Virtual Network

It is a good practice to move network traffic into a seperate virual network,
but even the default network created by libvirt could be used. The network
should have Network Address Translation (NAT) enabled and all desired Media
Access Control (MAC) and Internet Protocol (IP) addresses need to be defined.

Create a network for OKD:

```shell
[root@hypervisor ~]# virsh net-define okd-the-hard-way/src/hypervisor/network.xml
[root@hypervisor ~]# virsh net-autostart okd
[root@hypervisor ~]# virsh net-start okd
```

## Services

Kickstart installations offer a way to automate every task in the installation
process. Kickstart files provide answers to all questions asked during the
installation process. Therefore, if you provide a Kickstart file when the
installation begins, the installation will be partially or fully automated. The
Kickstart file for the services machine can be found at
[../src/hypervisor/services.ks](../src/hypervisor/services.ks).

Start the installation of the services VM:

```shell
[root@hypervisor ~]# virt-install \
    --name services \
    --description "Services" \
    --os-type Linux \
    --os-variant fedora32 \
    --disk /okd/images/services.qcow2,bus=scsi,size=50,sparse=yes \
    --controller scsi,model=virtio-scsi \
    --network network=okd \
    --location /okd/images/Fedora-Server-dvd-x86_64-32-1.6.iso \
    --initrd-inject=/root/okd-the-hard-way/src/hypervisor/services.ks \
    --extra-args "console=ttyS0,115200 ks=file:/services.ks" \
    --ram 8192 \
    --vcpus 2 \
    --cpu host \
    --accelerate \
    --graphics none \
    --boot useserial=on
[root@hypervisor ~]# virsh autostart services
```

Once the installation finished, login with username `root` and password
`secret_password_123`. Exit the session with `CTRL+]`.

Next: [Services](02-services.md)
