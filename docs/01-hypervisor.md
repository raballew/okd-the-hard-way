# Hypervisor

In this section you will prepare the bare metal host in a way, that it will be
capable of running virtualized workload. This will include the initial setup of
storage and networking.

## Variables

For convinience and readability set the following variables. `FEDORA_VERSION`
defines the release of Fedora that should be used for installing the services
machine. `FQDN` should be set to the fully qualified domain name in the tree
hierarchy of the Domain Name System (DNS):

```bash
export FEDORA_VERSION=34
# Change FQDN so that it fits your environment
export SUB_DOMAIN=okd
export BASE_DOMAIN=example.com
```

## Packages

Install the virtualization tools via the command line using the virtualization
package group. To view the packages, run:

```bash
[root@okd ~]# dnf groupinfo virtualization
```

Run the following command to install the mandatory and default packages in the
virtualization group:

```bash
[root@okd ~]# dnf install @virtualization -y
```

After installation, start the libvirtd service:

```bash
[root@okd ~]# systemctl enable libvirtd --now
```

Verify that the KVM kernel modules are properly loaded:

```bash
[root@okd ~]# lsmod | grep kvm

kvm_amd                55563  0
kvm                   419458  1 kvm_amd
```

If this command lists `kvm_intel` or `kvm_amd`, KVM is properly configured.

Now install all additional required packages:

```bash
[root@okd ~]# dnf install git virt-install -y
```

## Hostname

It is also a good idea to set the hostname to the FQDN of the hypervisor
machine:

```bash
[root@okd ~]# hostnamectl set-hostname --static $FQDN
```

## User

The sudo command allows you to run programs with the security privileges of
another user (by default, as the superuser). It prompts you for your personal
password and confirms your request to execute a command by checking a file,
called sudoers , which the system administrator configures. All other commands
can be executed as non-root user. Create the user `okd` and assign any password
you like.

```bash
[root@okd ~]# useradd okd
[root@okd ~]# passwd okd
```

On Fedora, it is the wheel group the user has to be added to, as this group has
full administrative privileges. libvirt is needed to manage virtual machines and
networks. Those tasks usually requires more permissions. Add the `okd` user to
the group using the following command:

```bash
[root@okd ~]# usermod -aG wheel okd
[root@okd ~]# usermod -aG libvirt okd
```

Then switch to the user `okd`.

```bash
[root@okd ~]# su -w FEDORA_VERSION -w FQDN - okd
```

## Repository

Clone this repository to easily access resource definitions on the hypervisor:

```bash
[okd@okd ~]$ git clone https://github.com/raballew/okd-the-hard-way.git
```

Then replace all occurences of `FQDN` in the sources files, so that the
configuration is tailored to your specific environment.

```bash
[okd@okd ~]$ grep -rl "{{ FQDN }}" ~/okd-the-hard-way/src/ | xargs sed -i 's/{{ FQDN }}/$FQDN/g'
```

## Configure libvirt

If not explicitly stated, the virsh binary uses the `qemu:///session` URI which
will not work in our case, as we need to use virtual networks defined in
`qemu:///system`. Defining `LIBVIRT_DEFAULT_URI` will configure virsh to connect
to the URI specified per default. By appending the `export` of the environment
variable to the `.bash_profile`, personal initialization for the user `okd` is
configured to use `qemu:///system` per default.

```bash
[okd@okd ~]$ echo "export LIBVIRT_DEFAULT_URI=qemu:///system" >> ~/.bash_profile
[okd@okd ~]$ source ~/.bash_profile
```

Then fix potential permission issues by running libvirt as `okd` user instead of
`qemu`.

```bash
[okd@okd ~]$ sudo sed -i 's/#user = "root"/user = "okd"/g' /etc/libvirt/qemu.conf
[okd@okd ~]$ sudo sed -i 's/#group = "root"/group = "okd"/g' /etc/libvirt/qemu.conf
[okd@okd ~]$ sudo systemctl restart libvirtd
```

## Storage

Libvirt provides storage management on the physical host through storage pools
and volumes. A storage pool is a dedicated quantity of storage usually reserved
by a dedicated storage administrator. Storage pools are not required for proper
operation of VMs but it is a good way to manage storage related and used by VMs.

### Storage Pool

Special disk formats such as qcow2, raw, iso, e.g. are supported by the qemu-img
program and used while setting up the VMs. The recommended type of pool to
manage this files is `dir`.

Create the storage pool which will be used to serve the VM disk images:

```bash
[okd@okd ~]$ mkdir -p ~/images/
[okd@okd ~]$ virsh pool-define ~/okd-the-hard-way/src/01-hypervisor/storage-pool.xml
[okd@okd ~]$ virsh pool-autostart okd
[okd@okd ~]$ virsh pool-start okd
```

### Volumes

Creating an empty disk image for each VM ensures that the content of each VM is
stored in a predefined location. This is not a mandatory step, but it helps to
simplyfy things later on and keep track of which storage is consumed by which
VM.

Each node of the cluster will get a 128G large disk attached to it, with
exception of the services and storage nodes as their demand is slightly higher:

```bash
# The services machine needs a larger disk as it will serve all artifacts
[okd@okd ~]$ qemu-img create -f qcow2 ~/images/services.$HOSTNAME.0.qcow2 256G
# Default sized disks for all OKD nodes
[okd@okd ~]$ for node in \
    bootstrap \
    master-0 master-1 master-2 \
    compute-0 compute-1 compute-2 \
    storage-0 storage-1 storage-2 \
    infra-0 infra-1 infra-2 ; \
do \
    qemu-img create -f qcow2 ~/images/$node.$HOSTNAME.0.qcow2 128G ; \
done
# Additional disks for storage nodes
[okd@okd ~]$ for node in \
    storage-0 storage-1 storage-2 ; \
do \
    qemu-img create -f qcow2 ~/images/$node.$HOSTNAME.1.qcow2 256G ; \
done
```

### Fedora ISO

The services machine is the first machine that needs to be setup. All other VMs
will be bootstrapped using Preboot eXecution Environment (PXE) procedures.
Therefore the services machine is going to host PXE boot services and more.
Fedora offers all required packages to do so and will be used as the operating
system on the services VM.

Download the Fedora Server ISO file:

```bash
[okd@okd ~]$ curl -X GET "https://download.fedoraproject.org/pub/fedora/linux/releases/$FEDORA_VERSION/Server/x86_64/iso/Fedora-Server-dvd-x86_64-$FEDORA_VERSION-1.2.iso" -o ~/images/Fedora-Server-dvd-x86_64-$FEDORA_VERSION-1.2.iso -L
```

## Network

### Virtual Network

It is a good practice to move network traffic into a seperate virual network,
but even the default network created by libvirt could be used. The network
should have no Network Address Translation (NAT) enabled to setup an isolated
network and all desired Media Access Control (MAC) and Internet Protocol (IP)
addresses need to be defined.

When creating and starting the network virsh will attempt to create a bridge
interface.

```bash
[okd@okd ~]$ virsh net-define ~/okd-the-hard-way/src/01-hypervisor/network.xml
[okd@okd ~]$ virsh net-autostart okd
[okd@okd ~]$ virsh net-start okd
```

## Services

Kickstart installations offer a way to automate every task in the installation
process. Kickstart files provide answers to all questions asked during the
installation process. Therefore, if you provide a Kickstart file when the
installation begins, the installation will be partially or fully automated. The
Kickstart file for the services machine can be found at
[services.ks](../src/01-hypervisor/services.ks).

The services VM will be the only node with direct internet access trough the
default libvirt network. Start the installation of the services VM:

```bash
[okd@okd ~]$ USER_PASSWORD=$(openssl rand -hex 128)
[okd@okd ~]$ echo "user --name=okd --password=$USER_PASSWORD --plaintext --groups=wheel" >> ~/okd-the-hard-way/src/01-hypervisor/services.ks
[okd@okd ~]$ virt-install \
    --name services.okd.$HOSTNAME \
    --description "services" \
    --os-type Linux \
    --os-variant fedora$FEDORA_VERSION \
    --disk ~/images/services.$HOSTNAME.0.qcow2,bus=scsi,size=256,sparse=yes \
    --controller scsi,model=virtio-scsi \
    --network network=default \
    --network network=okd \
    --location ~/images/Fedora-Server-dvd-x86_64-$FEDORA_VERSION-1.2.iso \
    --initrd-inject=/home/okd/okd-the-hard-way/src/01-hypervisor/services.ks \
    --extra-args "console=ttyS0,115200 inst.ks=file:/services.ks" \
    --ram 8192 \
    --vcpus 2 \
    --cpu host \
    --accelerate \
    --graphics none \
    --boot useserial=on
```

Once the installation finished, login with username `okd` and password equal to
the value stored in the `USER_PASSWORD` variable. Exit the session with
`CTRL+]`. The console can be accessed trough virsh at any time:

```bash
[okd@okd ~]# virsh console services.okd.$HOSTNAME

Connected to domain services
Escape character is ^]
```

Make sure that the services VM starts automatically:

```bash
[okd@okd ~]# virsh autostart services.okd.$HOSTNAME
```

Next: [Services](02-services.md)
