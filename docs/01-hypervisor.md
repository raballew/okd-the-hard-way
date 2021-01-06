# Hypervisor

## Packages

Install the virtualization tools via the command line using the virtualization
package group. To view the packages, run:

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
[root@hypervisor ~]# dnf install @virtualization -y
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

If this command lists `kvm_intel` or `kvm_amd`, KVM is properly configured.

Now install all additional required packages:

```shell
[root@hypervisor ~]# dnf install git virt-install -y
```

## Hostname

It is also a good idea to set the hostname to match the fully qualified domain
name (FQDN) of the hypervisor machine:

```shell
[root@hypervisor ~]# hostnamectl set-hostname hypervisor.example.com
```

## User

The sudo command allows you to run programs with the security privileges of
another user (by default, as the superuser). It prompts you for your personal
password and confirms your request to execute a command by checking a file,
called sudoers , which the system administrator configures. All other commands
can be executed as non-root user. Create the user `okd` and assign any password
you like.

```shell
[root@hypervisor ~]# useradd okd
[root@hypervisor ~]# passwd okd
```

On Fedora, it is the wheel group the user has to be added to, as this group has
full admin privileges. libvirt is needed to manage virtual machines a networks.
Add a user to the group using the following command:

```shell
[root@hypervisor ~]# usermod -aG wheel okd
[root@hypervisor ~]# usermod -aG libvirt okd
```

Then switch to the user `okd` with the password previously set.

```shell
[root@hypervisor ~]# su - okd
```

## Repository

Clone this repository to easily access resource definitions on the hypervisor:

```shell
[okd@hypervisor ~]$ git clone https://github.com/raballew/okd-the-hard-way.git
```

## Configure libvirt

If not explicitly stated, the virsh binary uses the `qemu:///session` URI which
will not work in our case, as we need to use virtual networks defined in
`qemu:///system`. Defining `LIBVIRT_DEFAULT_URI` will configure virsh to connect
to the URI specified per default.

```shell
[okd@hypervisor ~]$ export LIBVIRT_DEFAULT_URI=qemu:///system
```

Then fix potential permission issues by running libvirt as okd user instead of
qemu.

```shell
[okd@hypervisor ~]$ sudo sed -i 's/#user = "root"/user = "okd"/g' /etc/libvirt/qemu.conf
[okd@hypervisor ~]$ sudo sed -i 's/#group = "root"/group = "okd"/g' /etc/libvirt/qemu.conf
[okd@hypervisor ~]$ sudo systemctl restart libvirtd
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
[okd@hypervisor ~]$ mkdir -p okd/images/
[okd@hypervisor ~]$ virsh pool-define okd-the-hard-way/src/hypervisor/storage-pool.xml
[okd@hypervisor ~]$ virsh pool-autostart okd
[okd@hypervisor ~]$ virsh pool-start okd
```

### Volumes

Creating an empty disk image for each VM ensures that the content of each VM is
stored in a predefined location. This is not a mandatory step, but it helps to
simplyfy things later on.

Create the disk images:

```shell
[okd@hypervisor ~]$ for node in \
  load-balancer-0 load-balancer-1\
  services \
  bootstrap \
  etcd-0 etcd-1 etcd-2 \
  compute-0 compute-1 compute-2 \
  storage-0 storage-1 storage-2 \
  infra-0 infra-1 infra-2 ; \
do \
  qemu-img create -f qcow2 okd/images/$node.$HOSTNAME.0.qcow2 128G ; \
done
[okd@hypervisor ~]$ for node in \
  storage-0 storage-1 storage-2 ; \
do \
  qemu-img create -f qcow2 okd/images/$node.$HOSTNAME.1.qcow2 256G ; \
done
```

### Fedora ISO

The services machine is the first machine that needs to be setup. All other VMs
will be bootstrapped using Preboot eXecution Environment (PXE) procedures.
Therefore the services machine is going to host PXE boot services and more.
Fedora offers all required packages to do so and will be used as the operating
system on the services VM.

Download the Fedora Server ISO file:

```shell
[okd@hypervisor ~]$ curl -X GET 'https://ftp.plusline.net/fedora/linux/releases/33/Server/x86_64/iso/Fedora-Server-dvd-x86_64-33-1.2.iso' -o okd/images/Fedora-Server-dvd-x86_64-33-1.2.iso -L
```

## Network

### Virtual Network

It is a good practice to move network traffic into a seperate virual network,
but even the default network created by libvirt could be used. The network
should have Network Address Translation (NAT) enabled and all desired Media
Access Control (MAC) and Internet Protocol (IP) addresses need to be defined.

When creating and starting the network virsh will attempt to create a bridge
interface.

```shell
[okd@hypervisor ~]$ virsh net-define okd-the-hard-way/src/hypervisor/network.xml
[okd@hypervisor ~]$ virsh net-autostart okd
[okd@hypervisor ~]$ virsh net-start okd
```

## Services

Kickstart installations offer a way to automate every task in the installation
process. Kickstart files provide answers to all questions asked during the
installation process. Therefore, if you provide a Kickstart file when the
installation begins, the installation will be partially or fully automated. The
Kickstart file for the services machine can be found at
[../src/hypervisor/services.ks](../src/hypervisor/services.ks).

The services VM will be the only node with direct internet access. Start the
installation of the services VM:

```shell
[okd@hypervisor ~]$ virt-install \
    --name services.$HOSTNAME \
    --description "Services" \
    --os-type Linux \
    --os-variant fedora33 \
    --disk /home/okd/okd/images/services.$HOSTNAME.0.qcow2,bus=scsi,size=128,sparse=yes \
    --controller scsi,model=virtio-scsi \
    --network network=okd \
    --location /home/okd/okd/images/Fedora-Server-dvd-x86_64-33-1.2.iso \
    --initrd-inject=/home/okd/okd-the-hard-way/src/hypervisor/services.ks \
    --extra-args "console=ttyS0,115200 inst.ks=file:/services.ks" \
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
