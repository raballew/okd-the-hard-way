# Services

The following steps are all executed on a services VM. The console can be
accessed trough virsh:

```bash
[root@okd ~]# virsh console services.$HOSTNAME

Connected to domain services
Escape character is ^]
```

Login as user `okd`. The password is stored in
`~/okd-the-hard-way/src/01-hypervisor/services.ks`.

In some cases it is necessary to perform the installation in a disconnected
environment. This use case is supported by the fact that all required resources
such as container images and the dependencies to Fedora CoreOS (FCOS) are
resolved in advance and hosted locally. The services VM disk image configured
this way can then be transported into the disconnected environment. Even though
this lab setup does not require a disconnected installation, all necessary steps
are shown in the following steps and can easily be adopted to a real world
scenario. In this case the network configuration and services used might differ
but the principles remain the same.

## Variables

Repeat the steps mentioned [in the previous
section](./01-hypervisor.md#variables).

## Repository

Repeat the steps mentioned [in the previous
section](./01-hypervisor.md#repository).

## Firewall

This VM is going to host several essential services that will be used from other
nodes in the virtual network. These services and several ports need to be
configured in the firewall. Port 6443 is used by the Kubernetes Application
Programming Interface (API) and port 22623 is related to the MachineConfig
service of the cluster. The service that runs the Hypertext Transfer Protocol
(HTTP) server uses port 8080. Port 5000 is used by the mirror registry. All of
the firewall rules have already been in the [kickstart
file](../src/01-hypervisor/services.ks).

## DHCP server

The Dynamic Host Configuration Protocol (DHCP) is a network management protocol
used on Internet Protocol (IP) networks, whereby a DHCP server dynamically
assigns an IP address and other network configuration parameters to devices on
the network, so they can communicate with other IP networks. Often the IP
address assignment is done dynamically. For this lab IP addresses are configured
statically to make it easier to follow the instructions. Take a look at
[dhcpd.conf](../src/02-services/dhcpd.conf) and make yourself familiar with the
configured Media Access Control (MAC) and IP addresses.

```bash
[root@services ~]# \cp ~/okd-the-hard-way/src/02-services/dhcpd.conf /etc/dhcp/dhcpd.conf
[root@services ~]# systemctl restart dhcpd
```

## BIND server

Berkeley Internet Name Domain (BIND) is an implementation of the DNS of the
Internet. It performs both of the main DNS server roles, acting as an
authoritative name server for domains, and acting as a recursive resolver in the
network. The DNS server in included in Fedora and managed by the named service.
Our named service uses two configuration files.
[named.conf](../src/02-services/named.conf) is the main configuration file with
[example.com.db](../src/02-services/zone.db) being the zone file.

```bash
[root@services ~]# \cp ~/okd-the-hard-way/src/02-services/named.conf /etc/named.conf
[root@services ~]# \cp ~/okd-the-hard-way/src/02-services/zone.db /var/named/zone.db
[root@services ~]# systemctl restart named
```

The current network configuration does not use the freshly setup local BIND
server. Therefore all hosts in the virtual network are not known. By telling the
network interface about the new BIND server, the host should can be resolved.

```bash
[root@services ~]# nmcli connection modify enp2s0 ipv4.dns "192.168.200.254"
[root@services ~]# nmcli connection reload
[root@services ~]# nmcli connection up enp2s0
```

## TFTP server

Trivial File Transfer Protocol (TFTP) servers allow connections from a TFTP
client for sending and receiving files. It is used typically for boot-loading
remote devices.

Because the environment is meant to be used in a headless way VMs will be
configured to choose the correct image and igniton file for installation
automatically. Create a file for each node in `/var/lib/tftpboot/pxelinux.cfg/`
whereas the filenames are derived from the unique identifier, IP address or MAC
address for each VM. The MAC addresses can be found in the
[dhcpd.conf](../src/02-services/dhcpd.conf) file. A more detailed explaination
why things need to be configured the way shown below can be found
[here](https://wiki.syslinux.org/wiki/index.php?title=PXELINUX). It is important
to use relative soft links from within `/var/lib/tftpboot/pxelinux.cfg/` only to
ensure that the linked files are accessible by the TFTP server.

```bash
[root@services ~]# mkdir -p  /var/lib/tftpboot/pxelinux.cfg/
[root@services ~]# \cp ~/okd-the-hard-way/src/02-services/{bootstrap,master,default,worker} /var/lib/tftpboot/pxelinux.cfg/
[root@services ~]# cd /var/lib/tftpboot/pxelinux.cfg/
[root@services pxelinux.cfg]# ln -s bootstrap 01-f8-75-a4-ac-01-00
[root@services pxelinux.cfg]# ln -s master 01-f8-75-a4-ac-03-00
[root@services pxelinux.cfg]# ln -s master 01-f8-75-a4-ac-03-01
[root@services pxelinux.cfg]# ln -s master 01-f8-75-a4-ac-03-02
[root@services pxelinux.cfg]# ln -s worker 01-f8-75-a4-ac-02-00
[root@services pxelinux.cfg]# ln -s worker 01-f8-75-a4-ac-02-01
[root@services pxelinux.cfg]# ln -s worker 01-f8-75-a4-ac-02-02
[root@services pxelinux.cfg]# ln -s worker 01-f8-75-a4-ac-04-00
[root@services pxelinux.cfg]# ln -s worker 01-f8-75-a4-ac-04-01
[root@services pxelinux.cfg]# ln -s worker 01-f8-75-a4-ac-04-02
[root@services pxelinux.cfg]# ln -s worker 01-f8-75-a4-ac-05-00
[root@services pxelinux.cfg]# ln -s worker 01-f8-75-a4-ac-05-01
[root@services pxelinux.cfg]# ln -s worker 01-f8-75-a4-ac-05-02
[root@services pxelinux.cfg]# cd
```

Also add a copy of `syslinux` to the tftpboot directory.

```bash
[root@services ~]# \cp -rvf /usr/share/syslinux/* /var/lib/tftpboot/
```

Security Enhanced Linux (SELinux) is a set of kernel modifications and
user-space tools that have been added to various Linux distributions to provide
a mechanism for supporting access control security policies. Restore the proper
SELinux context for the files:

```bash
[root@services ~]# restorecon -RFv /var/lib/tftpboot/
[root@services ~]# systemctl restart tftp
```

## HAProxy server

An external load balancer as a passthrough is the most lightweight integration
possible between OKD and an external load balancer. It is commonly used when
traffic hitting the cluster first goes through a public network. The load
balancer passes any request trough to OKD's routing layer. The OKD routers then
handle things like SSL termination and making routing decisions.

As shown in [haproxy.cfg](../src/02-services/haproxy.cfg) there are multiple
load balancers defined. Most notably load balancer for the machines that run the
ingress router pods that balances ports 443 and 80. Both the ports must be
accessible to both clients external to the cluster and nodes within the cluster.

As well as a load balancer for the control plane and bootstrap machines that
targets port 6443 and 22623. Port 6443 must be accessible to both clients
external to the cluster and nodes within the cluster, and port 22623 must be
accessible to nodes within the cluster.

```bash
[root@services ~]# \cp ~/okd-the-hard-way/src/02-services/haproxy.cfg /etc/haproxy/haproxy.cfg
[root@services ~]# semanage port -a 6443 -t http_port_t -p tcp
[root@services ~]# semanage port -a 22623 -t http_port_t -p tcp
[root@services ~]# systemctl restart haproxy
```

## Network Time Protocol server

The Network Time Protocol (NTP) is a networking protocol for clock
synchronization between computer systems over packet-switched, variable-latency
data networks. In our case it is needed to synchonize the clocks of the nodes in
the disconnected environment so that logging, certificates and other curtial
components use the same timestamps.

The Chrony NTP daemon can act as both, NTP server or as NTP client. To turn
Chrony into an NTP server add the following line into the main Chrony
/etc/chrony.conf configuration file:

```bash
[root@services ~]# echo "allow 192.168.200.0/24" >> /etc/chrony.conf
```

Then restart the Chrony daemon.

```bash
[root@services ~]# systemctl restart chronyd
```

## Certificate Authority

Asymmetric cryptography solves the problem of two entities communicating
securely without ever exchanging a common key, by using two related keys, one
private, one public.

Ciphered text with the public key can only be deciphered by the corresponding
private key, and verifiable signatures with the public key can only be created
with the private key.

But if the two entities do not know each other yet they a way to know for sure
that a public key corresponds to the private key of the other identity.

In other words, when Alice speaks to Bob, Bob tells Alice "this is my public key
K, use it to communicate with me" Alice needs to know it is really Bob's public
key and not Eve's.

The usual solution to this problem is to use a public key infrastructure (PKI).

A PKI is an arrangement that binds public keys to identities by means of a
Certificate Authority (CA).

A CA is a centralized trusted third party whose public key is already known.

This way when Alice speaks to Bob, Bob shows Alice a signed message by Trent,
who Alice knows and trusts, that says "this public key K belongs to Bob". That
signed message is called a certificate, and it can contain other info. Alice is
able to verify the signature using Trent's public key, and can know speak
confidently to Bob.

It is also common to have a chain of trust. Alice speaks to Bob, Trent does not
know Bob but knows Carol who knows Bob, so Bob shows Alice a chain of
certificates, one from Carol that says which key belongs to Bob and one from
Trent who says which key belongs to Carol. Even without knowing Carol, Alice can
verify the certificate from Trent, be sure of Carol's key, and if her trust in
Trent is transitive then she can also trust Carol as to who Bob is.

As this is a disconnected environment, we can not rely on public infrastructure
and will setup our own CA instead. Generate an RSA key and a certificate for the
CA:

```bash
[okd@services ~]# mkdir ~/registry/
[okd@services ~]# openssl req \
  -newkey rsa:4096 \
  -nodes \
  -sha256 \
  -keyout ~/registry/ca.key \
  -x509 \
  -days 1825 \
  -out ~/registry/ca.crt \
  -subj "/"

Generating a RSA private key
.............................++++
....++++
writing new private key to '~/registry/ca.key'
-----
```

Any copy of the private key should only be help by the entity who is going to be
certified. This means the key should never be sent to anyone else, including the
certificate issuer.

Move the certificate signed by our own CA to the trusted store of the services
VM.

```bash
[okd@services ~]# \cp ~/registry/ca.crt /etc/pki/ca-trust/source/anchors/
[okd@services ~]# update-ca-trust
```

## Mirror container image registy server

A registry is an instance of the registry image, and runs within the container
runtime. A production-ready registry must be protected by Transport Layer
Security (TLS) and should ideally use an access-control mechanism. Both will be
configured. Also by default, your registry data is persisted as a volume on the
host filesystem. To achieve higher performances a bind mount for will be used
instead of a volume. A more detailed instruction on how to tweak your settings
can be found [here](https://docs.docker.com/registry/deploying/). This registry
is used to mirror all required container images for the installation to a
location reachable in a disconnected setup.

The directories used by the registry will be located at `~/okd/registry`.

```bash
[okd@services ~]# mkdir -p ~/registry/{auth,certs,data}
```

In order to make the registry accessible by external host Transport Layer
Security (TLS) certificates need to be supplied. The common name should match
the FQDN of the services VM.

```bash
[okd@services ~]# openssl genrsa -out  ~/registry/$HOSTNAME.key 4096
[okd@services ~]# openssl req -new -sha256 \
  -key ~/registry/$HOSTNAME.key \
  -subj "/CN=$HOSTNAME" \
  -addext "subjectAltName=DNS:$HOSTNAME,DNS:www.$HOSTNAME" \
  -out ~/registry/$HOSTNAME.csr
[okd@services ~]# openssl x509 -req \
  -in ~/registry/$HOSTNAME.csr \
  -CA ~/registry/ca.crt \
  -CAkey ~/registry/ca.key \
  -CAcreateserial \
  -out ~/registry/$HOSTNAME.crt \
  -days 730 \
  -extfile <(printf "subjectAltName=DNS:$HOSTNAME,DNS:www.$HOSTNAME") \
  -sha256
[okd@services ~]# \cp ~/registry/$HOSTNAME.crt ~/registry/certs
[okd@services ~]# \cp ~/registry/$HOSTNAME.key ~/registry/certs
```

For authentication a username and password is provided via `htpasswd`.

```bash
[okd@services ~]# USER_PASSWORD=$(openssl rand -hex 64)
[okd@services ~]# echo $USER_PASSWORD > ~/registry/password
[okd@services ~]# htpasswd -bBc ~/registry/auth/htpasswd okd $USER_PASSWORD
```

Podman was not designed to manage containers startup order, dependency checking
or failed container recovery. In fact, this job can be done by external tools.
The systemd initialization service can be configured to work with Podman
containers.

```bash
[root@services ~]# \cp ~/okd-the-hard-way/src/02-services/registry.service /etc/systemd/system/
[root@services ~]# systemctl restart registry.service
```

## Installer

The installer is a commandline tool designed to help experts and beginners to
setup and configure OKD in various
[environments](https://github.com/openshift/installer/blob/master/README.md#supported-platforms).
Think of it as an installation wizard with different levels of customization
ranging from changing the default configuration to replacing or extending a
Kubernetes resource definition. Look trough the links for a better understanding
about what happens in the background while executing the next steps. Really take
your time here to fully understand what happens, then continue with this lab.

* [Overview](https://github.com/openshift/installer/blob/master/docs/user/overview.md)
* [Customization](https://github.com/openshift/installer/blob/master/docs/user/customization.md)
* [Ignition](https://github.com/coreos/ignition/blob/main/docs/getting-started.md)
* [Installation](https://docs.okd.io/latest/installing/installing_bare_metal/installing-restricted-networks-bare-metal.html)

The installer is available in [stable
versions](https://github.com/openshift/okd/releases) as well as [other developer
builds](https://origin-release.apps.ci.l2s4.p1.openshiftapps.com/). In this lab
a stable version is used.

First download the client tools:

```bash
[okd@services ~]# curl -X GET 'https://github.com/openshift/okd/releases/download/$OKD_VERSION/openshift-client-linux-$OKD_VERSION.tar.gz' -o ~/openshift-client.tar.gz -L
[okd@services ~]# tar -xvf ~/openshift-client.tar.gz
[root@services ~]# \mv oc kubectl /usr/local/bin/
[okd@services ~]# rm -rf ~/openshift-client.tar.gz README.md
```

### Mirror container images

During the installation several container images are required and need to be
downloaded to the local registry first to ensure operability in a disconnected
environment. Therefore the pull secrets need to be defined. It can be obtained
on [cloud.redhat.com](https://cloud.redhat.com/openshift/install/pull-secret) on
the Red Hat OpenShift Cluster Manager site. This pull secret allows you to
authenticate with the services that are provided by the included authorities,
including Quay.io, which serves the container images for OKD components. Click
Download pull secret and you will receive a file called `pull-secret.txt`.

The file should look similar to this:

```bash
[okd@services ~]# cat pull-secret.txt

{
  "auths": {
    "cloud.openshift.com": {
      "auth": "b3BlbnNo...",
      "email": "you@example.com"
    },
    "quay.io": {
      "auth": "b3BlbnNo...",
      "email": "you@example.com"
    },
    "registry.connect.redhat.com": {
      "auth": "NTE3Njg5Nj...",
      "email": "you@example.com"
    },
    "registry.redhat.io": {
      "auth": "NTE3Njg5Nj...",
      "email": "you@example.com"
    }
  }
}
```

Since Quay.io cannot be the container image source in a disconnected
environment, the authentication token for the local registry needs to be added.

> The token uses the username and password that was used to create the htpasswd
> file for the registry

```bash
[okd@services ~]# echo -n "okd:$(cat ~/registry/password)" | base64 -w0
```

Add the token to the `pull-secret.txt` file:

```bash
[okd@services ~]# vi ~/pull-secret.txt

{
  "auths": {
    "cloud.openshift.com": {
      "auth": "b3BlbnNo...",
      "email": "you@example.cpm"
    },
    "quay.io": {
      "auth": "b3BlbnNo...",
      "email": "you@example.cpm"
    },
    "registry.connect.redhat.com": {
      "auth": "NTE3Njg5Nj...",
      "email": "you@example.cpm"
    },
    "registry.redhat.io": {
      "auth": "NTE3Njg5Nj...",
      "email": "you@example.cpm"
    },
    "services.okd.example.com:5000": {
      "auth": "b2tkOm9r...",
      "email": "you@example.com"
    }
  }
}
```

If you have access to other private registries such as `gcr.io` or
`hub.docker.com` you should add their pull secrets here as well. They will
useful at a later point of time. `pull-secret.txt` will be used whenever images
are mirrored. The cluster itself does not need to know anything else other than
the credentials for the mirror registry. This has the benefit, that remote
health reporting is disabled by default. Create a file named
`pull-secret-cluster.txt`:

```bash
[okd@services ~]# vi ~/pull-secret-cluster.txt

{
  "auths": {
    "services.okd.example.com:5000": {
      "auth": "b2tkOm9r...",
      "email": "you@example.com"
    }
  }
}
```

Now mirror the required images for the release:

```bash
[okd@services ~]# oc adm -a ~/pull-secret.txt release mirror \
  --from=quay.io/openshift/okd:$OKD_VERSION \
  --to=$HOSTNAME:5000/openshift/okd \
  --to-release-image=$HOSTNAME:5000/openshift/okd:$OKD_VERSION
```

### Create SSH key pair

Create a Secure Shell (SSH) key pair to authenticate at the FCOS nodes later:

```bash
[okd@services ~]# ssh-keygen -t rsa -N "" -f ~/.ssh/okd -b 4096
```

### Adjust installation configuration

Once all required secrets are created, lets adjust the installation
configuration to be compatible with our environment:

```bash
[okd@services ~]# mkdir installer/
[okd@services ~]# cd installer/
[okd@services installer]# oc adm -a ~/pull-secret.txt release extract --command=openshift-install "$HOSTNAME:5000/openshift/okd:$OKD_VERSION"
[okd@services installer]# \cp ~/okd-the-hard-way/src/02-services/install-config-base.yaml install-config-base.yaml
[okd@services installer]# sed -i "s%{{ PULL_SECRET }}%$(cat ~/pull-secret-cluster.txt | jq -c)%g" install-config-base.yaml
[okd@services installer]# sed -i "s%{{ SSH_PUBLIC_KEY }}%$(cat ~/.ssh/okd.pub)%g" install-config-base.yaml
[okd@services installer]# REGISTRY_CERT=$(sed -e 's/^/  /' ~/registry/ca.crt)
[okd@services installer]# REGISTRY_CERT=${REGISTRY_CERT//$'\n'/\\n}
[okd@services installer]# sed -i "s%{{ REGISTRY_CERT }}%${REGISTRY_CERT}%g" install-config-base.yaml
```

### Mirror FCOS release artifacts

The installer has references to tested Fedora CoreOS artifacts and can be used
to mirror them to a Hypertext Transfer Protocol (HTTP) server. On this server
all files consumed during the Preboot Execution Environment (PXE) boot step a
hosted.

```bash
[okd@services installer]# INITRAMFS=$(./openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.metal.formats["pxe"]'.initramfs.location)
[okd@services installer]# KERNEL=$(./openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.metal.formats["pxe"]'.kernel.location)
[okd@services installer]# ROOTFS=$(./openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.metal.formats["pxe"]'.rootfs.location)
[root@services installer]# \cp ~/okd-the-hard-way/src/02-services/httpd.conf /etc/httpd/conf/httpd.conf
[root@services installer]# mkdir -p /var/www/html/okd/initramfs/
[root@services installer]# curl -X GET "$INITRAMFS" -o /var/www/html/okd/initramfs/fedora-coreos-live-initramfs.x86_64.img
[root@services installer]# curl -X GET "$INITRAMFS.sig" -o /var/www/html/okd/initramfs/fedora-coreos-live-initramfs.x86_64.img.sig
[root@services installer]# mkdir -p /var/www/html/okd/kernel/
[root@services installer]# curl -X GET "$KERNEL" -o /var/www/html/okd/kernel/fedora-coreos-live-kernel-x86_64
[root@services installer]# curl -X GET "$KERNEL.sig" -o /var/www/html/okd/kernel/fedora-coreos-live-kernel-x86_64.sig
[root@services installer]# mkdir -p /var/www/html/okd/rootfs/
[root@services installer]# curl -X GET "$ROOTFS" -o /var/www/html/okd/rootfs/fedora-coreos-live-rootfs.x86_64.img
[root@services installer]# curl -X GET "$ROOTFS.sig" -o /var/www/html/okd/rootfs/fedora-coreos-live-rootfs.x86_64.img.sig
```

### Prepare Ignition

Creating the ignition-configs will result in the install-config.yaml file being
removed by the installer, you may want to create a copy and store it outside of
this directory. After creating you have 24 hours time to finish the installation
of the cluster until the initial certificates expire.

> Only run this command if you are able to start the
> [installation](03-installation.md) right away. Otherwise continue at a later
> point of time.

```bash
[okd@services installer]# \cp install-config-base.yaml install-config.yaml
[okd@services installer]# ./openshift-install create ignition-configs
```

Copy the created ignition files to our `httpd` server:

```bash
[root@services ~]# mkdir -p /var/www/html/okd/ignitions/
[root@services ~]# \cp ~/installer/*.ign /var/www/html/okd/ignitions/
[root@services ~]# chown -R apache.apache /var/www/html
[root@services ~]# restorecon -RFv /var/www/html/
```

Then enable all services:

```bash
[root@services ~]# systemctl enable --now chronyd dhcpd haproxy httpd registry named tftp
```

## High Availability

Lets start with the good things first. The services required by OKD are now
configured in a way that is usable by both the installer and the cluster itself.
The cluster will consist of at least three nodes per node type which in fact is
an high availability setup. In case a single node is down and another node is
currently maintained there will always be a node that can serve traffic, no
matter which node type is affected.

The bad thing is, that the services node currently acts as a single point of
failure. If a single service or the entire services host goes down chances are
high that this will have a direct impact on the cluster itself resulting in
either a partial loss of usage if for example the mirror registry is unavailable
or a unreachable cluster if the BIND service is down.

The only way to mitiage this issue is by setting up the services in a way that
can handle the failure of a services node. In an enterprise environment, most of
this issues should already be solved as the network would need to provide its
own servers for DCHP, DNS e.g. Sometimes nothing is in place or some parts of
the services stack are missing. In a disconnected environment it is quite common
that no container registry exists. Therfore one could use the solutions
described above to fill the gap. But always keep in mind, that this is only an
intermediate solution for test environments. Independent of which solution is
used, make sure to also monitor systems required by the cluster. To better
understand what an outage of a particular service means check the list below:

### Critical

Critical means that an outage of the service will lead to a degraded and
potentially unavailable cluster.

* DHCP
* DNS
* Load balancer
* Container registry

### Major

Major means that parts of the cluster will be affected but the system stays
operational. Unexpected behaviour might occur immediately or in the long run.

* NTP - Logging, storage and certifcates might be out of sync, operators might
  become degraded

### Minor

A minor incident will not impact the cluster itself directly but additional
features might not be available anymore.

* HTTP - New nodes can not join the cluster
* TFTP - New nodes can not join the cluster

Next: [Installation](03-installation.md)
