# Hypervisor

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
[root@okd ~]# systemctl start libvirtd
```

To start the service automatically on restart and if not running now, run:

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

It is also a good idea to set the hostname to match the fully qualified domain
name (FQDN) of the hypervisor machine:

```bash
[root@okd ~]# hostnamectl set-hostname --transient okd.example.com
[root@okd ~]# hostnamectl set-hostname --static okd.example.com

```

> If you use a different hostname here, you will manually need to replace each
> occurrence of `okd.example.com` with your domain.

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
networks a task that usually requires more permissions. Add a user to the group
using the following command:

```bash
[root@okd ~]# usermod -aG wheel okd
[root@okd ~]# usermod -aG libvirt okd
```

Then switch to the user `okd` with the password previously set.

```bash
[root@okd ~]# su - okd
```

## Repository

Clone this repository to easily access resource definitions on the hypervisor:

```bash
[okd@okd ~]$ git clone https://github.com/raballew/okd-the-hard-way.git
```

## Configure libvirt

If not explicitly stated, the virsh binary uses the `qemu:///session` URI which
will not work in our case, as we need to use virtual networks defined in
`qemu:///system`. Defining `LIBVIRT_DEFAULT_URI` will configure virsh to connect
to the URI specified per default.

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

Special disk formats such as qcow2, raw, iso, e.g. as supported by the qemu-img
program are used while setting up the VMs. The recommended type of pool to
manage this files is `dir`.

Create the storage pool which will be used to serve the VM disk images:

```bash
[okd@okd ~]$ mkdir -p ~/okd/images/
[okd@okd ~]$ virsh pool-define okd-the-hard-way/src/hypervisor/storage-pool.xml
[okd@okd ~]$ virsh pool-autostart okd
[okd@okd ~]$ virsh pool-start okd
```

### Volumes

Creating an empty disk image for each VM ensures that the content of each VM is
stored in a predefined location. This is not a mandatory step, but it helps to
simplyfy things later on and keep track of which storage is consumed by which
VM.

Each node of the cluster will get a 128G large disk attached to it, with
exception of the services and storage nodes as their demand is slightly bigger:

```bash
[okd@okd ~]$ qemu-img create -f qcow2 okd/images/services.$HOSTNAME.0.qcow2 256G
[okd@okd ~]$ for node in \
    bootstrap \
    master-0 master-1 master-2 \
    compute-0 compute-1 compute-2 \
    storage-0 storage-1 storage-2 \
    infra-0 infra-1 infra-2 ; \
do \
    qemu-img create -f qcow2 okd/images/$node.$HOSTNAME.0.qcow2 128G ; \
done
[okd@okd ~]$ for node in \
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

```bash
[okd@okd ~]$ curl -X GET 'https://ftp.plusline.net/fedora/linux/releases/33/Server/x86_64/iso/Fedora-Server-dvd-x86_64-33-1.2.iso' -o okd/images/Fedora-Server-dvd-x86_64-33-1.2.iso -L
```

## Network

### Virtual Network

It is a good practice to move network traffic into a seperate virual network,
but even the default network created by libvirt could be used. The network
should have Network Address Translation (NAT) enabled and all desired Media
Access Control (MAC) and Internet Protocol (IP) addresses need to be defined.

When creating and starting the network virsh will attempt to create a bridge
interface.

```bash
[okd@okd ~]$ virsh net-define okd-the-hard-way/src/hypervisor/network.xml
[okd@okd ~]$ virsh net-autostart okd
[okd@okd ~]$ virsh net-start okd
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

```bash
[okd@okd ~]$ virt-install \
    --name services.$HOSTNAME \
    --description "services" \
    --os-type Linux \
    --os-variant fedora33 \
    --disk /home/okd/okd/images/services.$HOSTNAME.0.qcow2,bus=scsi,size=256,sparse=yes \
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
[okd@okd ~]# virsh autostart services.$HOSTNAME
```

By default VMs that reside in the network `okd` can access the internet. For a
disconnected setup we are going to disable this behavious to only allow the
services machine to access the internet. As we are using static IPs for each
host, this is fairly easy. Iptables is used to set up, maintain, and inspect the
tables of IP packet filter rules in the Linux kernel. Lets have a look on what
is currently configured:

```bash
[root@okd ~]# iptables --list --line-numbers

Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    LIBVIRT_INP  all  --  anywhere             anywhere

Chain FORWARD (policy ACCEPT)
num  target     prot opt source               destination
1    LIBVIRT_FWX  all  --  anywhere             anywhere
2    LIBVIRT_FWI  all  --  anywhere             anywhere
3    LIBVIRT_FWO  all  --  anywhere             anywhere

Chain OUTPUT (policy ACCEPT)
num  target     prot opt source               destination
1    LIBVIRT_OUT  all  --  anywhere             anywhere

Chain LIBVIRT_INP (1 references)
num  target     prot opt source               destination
1    ACCEPT     udp  --  anywhere             anywhere             udp dpt:domain
2    ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:domain
3    ACCEPT     udp  --  anywhere             anywhere             udp dpt:bootps
4    ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:bootps
5    ACCEPT     udp  --  anywhere             anywhere             udp dpt:domain
6    ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:domain
7    ACCEPT     udp  --  anywhere             anywhere             udp dpt:bootps
8    ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:bootps

Chain LIBVIRT_OUT (1 references)
num  target     prot opt source               destination
1    ACCEPT     udp  --  anywhere             anywhere             udp dpt:domain
2    ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:domain
3    ACCEPT     udp  --  anywhere             anywhere             udp dpt:bootpc
4    ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:bootpc
5    ACCEPT     udp  --  anywhere             anywhere             udp dpt:domain
6    ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:domain
7    ACCEPT     udp  --  anywhere             anywhere             udp dpt:bootpc
8    ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:bootpc

Chain LIBVIRT_FWO (1 references)
num  target     prot opt source               destination
1    ACCEPT     all  --  192.168.200.0/24     anywhere
2    REJECT     all  --  anywhere             anywhere             reject-with icmp-port-unreachable
3    ACCEPT     all  --  192.168.122.0/24     anywhere
4    REJECT     all  --  anywhere             anywhere             reject-with icmp-port-unreachable

Chain LIBVIRT_FWI (1 references)
num  target     prot opt source               destination
1    ACCEPT     all  --  anywhere             192.168.200.0/24     ctstate RELATED,ESTABLISHED
2    REJECT     all  --  anywhere             anywhere             reject-with icmp-port-unreachable
3    ACCEPT     all  --  anywhere             192.168.122.0/24     ctstate RELATED,ESTABLISHED
4    REJECT     all  --  anywhere             anywhere             reject-with icmp-port-unreachable

Chain LIBVIRT_FWX (1 references)
num  target     prot opt source               destination
1    ACCEPT     all  --  anywhere             anywhere
2    ACCEPT     all  --  anywhere             anywhere
```

The chain `LIBVIRT_FWO` allows sources within the 192.168.200.0/24 subnet to
connect to any destination, while `LIBVIRT_FWI` defines the same for incoming
traffic. Lets modify both rules so that only 192.168.200.254 (static IP of the
services node) is allowed to communicate with others. Make sure to set the right
value for `NUM`.

```bash
[root@okd ~]# NUM=3
[root@okd ~]# iptables -R LIBVIRT_FWO $NUM -s 192.168.200.254 -j ACCEPT
[root@okd ~]# iptables -R LIBVIRT_FWI $NUM -d 192.168.200.254 -j ACCEPT -m conntrack --ctstate RELATED,ESTABLISHED
[root@okd ~]# iptables-save > /etc/iptables.rules
[root@okd ~]# \cp /home/okd/okd-the-hard-way/src/hypervisor/01firewall /etc/NetworkManager/dispatcher.d/
[root@okd ~]# chmod +x /etc/NetworkManager/dispatcher.d/01firewall
```

Once the installation finished, login with username `root` and password
`secret_password_123`. Exit the session with `CTRL+]`.

Next: [Services](02-services.md)
