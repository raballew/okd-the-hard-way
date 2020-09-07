# Services

The following steps are all executed on the services VM. The console can be
accessed trough virsh:

```shell
[root@hypervisor ~]# virsh console services
Connected to domain services
Escape character is ^]
```

In some cases it is necessary to perform the installation in a disconnected
environment. This use case is supported by the fact that all required resources
such as container images and the dependencies to Fedora CoreOS are resolved in
advance and hosted locally. The services VM disk image configured in this way
can then be transported into the disconnected environment. Even though this lab
setup does not require a disconnected installation, all necessary steps are
shown below and can easily be adopted to a real world scenario. In this case the
network configuration and services used might differ but the principles remain
the same.

## Repository

Clone this repository to easily access resource definitions on the services VM:

```shell
[root@services ~]# git clone https://github.com/raballew/okd-the-hard-way.git
```

## Firewall

This VM is going to host several essential services that will be used from other
nodes in the virtual network. These services and several ports need to be
configured in the firewall. Port 6443 is used by the Kubernetes Application
Programming Interface (API) and port 22623 is related to the MachineConfig
service of the cluster. The service the runs the HTTP server is uses port 8080.

```shell
[root@services ~]# firewall-cmd --add-port={6443/tcp,8080/tcp,22623/tcp} --permanent
[root@services ~]# firewall-cmd --add-service={dhcp,dns,http,https,tftp} --permanent
[root@services ~]# firewall-cmd --reload
```

## DHCP server

The Dynamic Host Configuration Protocol (DHCP) is a network management protocol
used on IP networks, whereby a DHCP server dynamically assigns an IP address and
other network configuration parameters to each device on the network, so they
can communicate with other IP networks. Often the IP address assignment is done
dynamically. For this lab IP addresses are configured statically to make it
easier to follow the instructions. Take a look at
[dhcpd.conf](../src/services/dhcpd.conf) and make yourself familiar with MAC and
IP addresses.

```shell
[root@services ~]# \cp okd-the-hard-way/src/services/dhcpd.conf /etc/dhcp/dhcpd.conf
[root@services ~]# systemctl restart dhcpd
```

## BIND server

Berkeley Internet Name Domain (BIND) is an implementation of the Domain Name
System (DNS) of the Internet. It performs both of the main DNS server roles,
acting as an authoritative name server for domains, and acting as a recursive
resolver in the network. The DNS server in included in Fedora and managed by the
named service. Our named service uses two configuration files.
[named.conf](../src/services/named.conf) is the main configuration file with
[example.com.db](../src/services/example.com.db) being the zone file.

```shell
[root@services ~]# \cp okd-the-hard-way/src/services/named.conf /etc/named.conf
[root@services ~]# \cp okd-the-hard-way/src/services/example.com.db /var/named/example.com.db
[root@services ~]# systemctl restart named
```

The current network configuration does not use the freshly setup local BIND
server. Therefore all hosts in the virtual network are not known. By telling the
network interface about the new BIND server, the host should can be resolved.

```shell
[root@services ~]# nmcli connection modify enp1s0 ipv4.dns "192.168.200.254"
[root@services ~]# nmcli connection reload
[root@services ~]# nmcli connection up enp1s0
```

## HTTP server

The Hypertext Transfer Protocol (HTTP) server is going to host some files to
bootstrap the nodes.

```shell
[root@services ~]# \cp okd-the-hard-way/src/services/httpd.conf /etc/httpd/conf/httpd.conf
[root@services ~]# mkdir -p /var/www/html/okd/images/
[root@services ~]# curl -X GET 'https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/32.20200629.3.0/x86_64/fedora-coreos-32.20200629.3.0-metal.x86_64.raw.xz' -o /var/www/html/okd/images/fedora-coreos-32.20200629.3.0-metal.x86_64.raw.xz
[root@services ~]# curl -X GET 'https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/32.20200629.3.0/x86_64/fedora-coreos-32.20200629.3.0-metal.x86_64.raw.xz.sig' -o /var/www/html/okd/images/fedora-coreos-32.20200629.3.0-metal.x86_64.raw.xz.sig
```

Restore SELinux context for the files:

```shell
[root@services ~]# restorecon -RFv /var/www/html/
[root@services ~]# systemctl restart httpd
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
[dhcpd.conf](../src/services/dhcpd.conf) file. A more detailed explaination why
things need to be configured the way shown below can be found
[here](https://wiki.syslinux.org/wiki/index.php?title=PXELINUX). It is important
to use relative soft links from within `/var/lib/tftpboot/pxelinux.cfg/` only to
ensure that the linked files are accessible by the TFTP server.

```shell
[root@services ~]# mkdir -p  /var/lib/tftpboot/pxelinux.cfg/
[root@services ~]# \cp okd-the-hard-way/src/services/{bootstrap,compute,control,default} /var/lib/tftpboot/pxelinux.cfg/
[root@services ~]# cd /var/lib/tftpboot/pxelinux.cfg/
[root@services pxelinux.cfg]# ln -s bootstrap 01-f8-75-a4-ac-01-00
[root@services pxelinux.cfg]# ln -s compute 01-f8-75-a4-ac-02-00
[root@services pxelinux.cfg]# ln -s compute 01-f8-75-a4-ac-02-01
[root@services pxelinux.cfg]# ln -s compute 01-f8-75-a4-ac-02-02
[root@services pxelinux.cfg]# ln -s compute 01-f8-75-a4-ac-04-00
[root@services pxelinux.cfg]# ln -s compute 01-f8-75-a4-ac-04-01
[root@services pxelinux.cfg]# ln -s compute 01-f8-75-a4-ac-04-02
[root@services pxelinux.cfg]# ln -s control 01-f8-75-a4-ac-03-00
[root@services pxelinux.cfg]# ln -s control 01-f8-75-a4-ac-03-01
[root@services pxelinux.cfg]# ln -s control 01-f8-75-a4-ac-03-02
```

Also add a copy of `syslinux` to the tftpboot directory and add all required
files:

```shell
[root@services ~]# \cp -rvf /usr/share/syslinux/* /var/lib/tftpboot/
[root@services ~]# mkdir -p /var/lib/tftpboot/okd/
[root@services ~]# curl -X GET 'https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/32.20200629.3.0/x86_64/fedora-coreos-32.20200629.3.0-live-kernel-x86_64' -o /var/lib/tftpboot/okd/fedora-coreos-32.20200629.3.0-live-kernel-x86_64
[root@services ~]# curl -X GET 'https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/32.20200629.3.0/x86_64/fedora-coreos-32.20200629.3.0-live-kernel-x86_64.sig' -o /var/lib/tftpboot/okd/fedora-coreos-32.20200629.3.0-live-kernel-x86_64.sig
[root@services ~]# curl -X GET 'https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/32.20200629.3.0/x86_64/fedora-coreos-32.20200629.3.0-live-initramfs.x86_64.img' -o /var/lib/tftpboot/okd/fedora-coreos-32.20200629.3.0-live-initramfs.x86_64.img
[root@services ~]# curl -X GET 'https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/32.20200629.3.0/x86_64/fedora-coreos-32.20200629.3.0-live-initramfs.x86_64.img.sig' -o /var/lib/tftpboot/okd/fedora-coreos-32.20200629.3.0-live-initramfs.x86_64.img.sig
```

Restore the SELinux context for the files:

```shell
[root@services ~]# restorecon -RFv /var/lib/tftpboot/
```

The xinetd daemon is a TCP wrapped super service which controls access to a
subset of popular network services. TFTP can be managed by xinetd:

```shell
[root@services ~]# \cp okd-the-hard-way/src/services/tftp /etc/xinetd.d/tftp
[root@services ~]# systemctl restart xinetd
[root@services ~]# systemctl restart tftp
```

## HAProxy server

An external load balancer as a passthrough is the most lightweight integration
possible between OKD and an external load balancer. It is commonly used when
traffic hitting the cluster first goes through a public network. The load
balancer passes any request trough to OKD's routing layer. The OKD routers then
handle things like SSL termination and making routing decisions.

As shown in [haproxy.cfg](../src/services/haproxy.cfg) there are multiple load
balancers defined. Most notably load balancer for the machines that run the
ingress router pods that balances ports 443 and 80. Both the ports must be
accessible to both clients external to the cluster and nodes within the cluster.

As well as a load balancer for the control plane and bootstrap machines that
targets port 6443 and 22623. Port 6443 must be accessible to both clients
external to the cluster and nodes within the cluster, and port 22623 must be
accessible to nodes within the cluster.

```shell
[root@services ~]# \cp okd-the-hard-way/src/services/haproxy.cfg /etc/haproxy/haproxy.cfg
[root@services ~]# semanage port -a 6443 -t http_port_t -p tcp
[root@services ~]# semanage port -a 22623 -t http_port_t -p tcp
[root@services ~]# systemctl restart haproxy
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

The directories used by the registry will be located at `/okd/registry`.

```shell
[root@services ~]# mkdir -p /okd/registry/{auth,certs,data}
```

In order to make the registry accessible by external host Transport Layer
Security (TLS) certificates need to be supplied. The common name should match
the FQDN of the services VM.

```shell
[root@services ~]# cd /okd/registry/certs
[root@services certs]# openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt

Generating a RSA private key
..................................................................................++++
...............................................................++++
writing new private key to 'domain.key'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [XX]:
State or Province Name (full name) []:
Locality Name (eg, city) [Default City]:
Organization Name (eg, company) [Default Company Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (eg, your name or your server's hostname) []:services.okd.example.com
Email Address []:
```

Move the self-signed certificate to the trusted store of the services VM.

```shell
[root@services ~]# cp /okd/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
[root@services ~]# update-ca-trust
```

For authentication a username and password is provided via `htpasswd`.

```shell
[root@services ~]# htpasswd -bBc /okd/registry/auth/htpasswd okd okd
```

The registy can be started with the following command:

```shell
[root@services ~]# podman run --name mirror-registry -p 5000:5000 \
  -v /okd/registry/auth:/auth:z \
  -v /okd/registry/certs:/certs:z \
  -v /okd/registry/data:/var/lib/registry:z \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM=Registry \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -d docker.io/library/registry:2
```

Podman wasn’t designed to manage containers startup order, dependency checking
or failed container recovery. In fact, this job can be done by external tools.
The systemd initialization service can be configured to work with Podman
containers.

```shell
[root@services ~]# \cp ~/okd-the-hard-way/src/services/mirror-registry.service /etc/systemd/system/
[root@services ~]# sudo systemctl enable mirror-registry.service
[root@services ~]# sudo systemctl start mirror-registry.service
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

- [Overview](https://github.com/openshift/installer/blob/master/docs/user/overview.md)
- [Customization](https://github.com/openshift/installer/blob/master/docs/user/customization.md)
- [Ignition](https://github.com/coreos/ignition/blob/master/doc/getting-started.md)
- [Installation](https://docs.okd.io/latest/installing/installing_bare_metal/installing-restricted-networks-bare-metal.html)

The installer is available in [stable
versions](https://github.com/openshift/okd/releases) as well as [nightly
builds](https://origin-release.apps.ci.l2s4.p1.openshiftapps.com/). In this lab
a stable version is used.

Download the installer and client with:

```shell
[root@services ~]# curl -X GET 'https://github.com/openshift/okd/releases/download/4.5.0-0.okd-2020-09-04-180756/openshift-client-linux-4.5.0-0.okd-2020-09-04-180756.tar.gz' -o ~/openshift-client.tar.gz -L
[root@services ~]# curl -X GET 'https://github.com/openshift/okd/releases/download/4.5.0-0.okd-2020-09-04-180756/openshift-install-linux-4.5.0-0.okd-2020-09-04-180756.tar.gz' -o ~/openshift-install.tar.gz -L
[root@services ~]# tar -xvf ~/openshift-install.tar.gz
[root@services ~]# tar -xvf ~/openshift-client.tar.gz
[root@services ~]# \cp -v oc kubectl openshift-install /usr/local/bin/
```

During the installation several container images are required and need to be
downloaded to the local registry first to ensure operability in a disconnected
environment. Therefore the pull secrets need to be defined. It can be obtained
from the [Pull Secret
page](https://cloud.redhat.com/openshift/install/pull-secret) on the Red Hat
OpenShift Cluster Manager site. This pull secret allows you to authenticate with
the services that are provided by the included authorities, including Quay.io,
which serves the container images for OKD components. Click Download pull secret
and you will receive a file called `pull-secret.json`.

The file should look similar to this:

```shell
[root@services ~]# cat pull-secret.json
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

```shell
[root@services ~]# echo -n 'okd:okd' | base64 -w0
b2tkOm9rZA==
```

Add the token to the `pull-secret.txt` file:

```shell
[root@services ~]# vi /root/pull-secret.json

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
      "auth": "b2tkOm9rZA==",
      "email": "you@example.com"
    }
  }
}
```

Authentication to Quay.io and the local registry is possible now. To mirror the
required images run:

```shell
[root@services ~]# oc adm -a /root/pull-secret.json release mirror \
  --from=quay.io/openshift/okd@sha256:eeb7ba7c0ca5749f2e27e0951da70263658301f5bfa4fdd86524d73bfdeb7cac \
  --to=services.okd.example.com:5000/openshift/okd \
  --to-release-image=services.okd.example.com:5000/openshift/okd:4.5.0-0.okd-2020-09-04-180756
```

When OKD is installed on restricted networks, also known as a disconnected
cluster, Operator Lifecycle Manager (OLM) can no longer use the default
OperatorHub sources because they require full Internet connectivity. Cluster
administrators can disable those default sources and create local mirrors so
that OLM can install and manage Operators from the local sources instead. For
now lets download the container images into the mirror registry.

```shell
[root@services ~]# export REG_CREDS=/root/pull-secret.json
[root@services ~]# oc adm catalog build \
  --appregistry-org redhat-operators \
  --from=registry.redhat.io/openshift4/ose-operator-registry:v4.5 \
  --filter-by-os="linux/amd64" \
  --to=services.okd.example.com:5000/olm/redhat-operators:v1 \
  -a ${REG_CREDS} \
  --insecure
[root@services ~]# lvextend -L 200G /dev/mapper/fedora_services-root
[root@services ~]# xfs_growfs /dev/mapper/fedora_services-root
[root@services ~]# oc adm catalog mirror \
  services.okd.example.com:5000/olm/redhat-operators:v1 \
  services.okd.example.com:5000 \
  -a ${REG_CREDS} \
  --insecure \
  --filter-by-os="linux/amd64" \
  --manifests-only
[root@services ~]# while IFS== read src dst; do skopeo copy --authfile ${REG_CREDS} --all docker://$src docker://$dst ; done <./redhat-operators-manifests/mapping.txt
```

Create a SSH key pair to authenticate at the Fedora CoreOS nodes later:

```shell
[root@services ~]# ssh-keygen -t rsa -N "" -f ~/.ssh/fcos
```

Once all required secrets are created, lets adjust the installation
configuration to work with our environment:

```shell
[root@services ~]# mkdir installer/
[root@services ~]# cd installer/
[root@services installer]# oc adm -a /root/pull-secret.json release extract --command=openshift-install "services.okd.example.com:5000/openshift/okd:4.5.0-0.okd-2020-09-04-180756"
[root@services installer]# \cp ~/okd-the-hard-way/src/services/install-config-base.yaml install-config-base.yaml
```

The file `install-config-base.yaml` contains serveral placeholders for the
secrets that have been created in the previous steps of this lab. Obtain the
values for `PULL_SECRET` by running `cat ~/pull-secret.json`. The
`SSH_PUBLIC_KEY` can be viewed by executing `cat ~/.ssh/fcos.pub`. The
`SELF_SIGNED_CERT` for the local registry can be viewed with `cat
/okd/registry/certs/domain.crt`.

Creating the ignition-configs will result in the install-config.yaml file being
removed by the installer, you may want to create a copy and store it outside of
this directory.

```shell
[root@services installer]# \cp install-config-base.yaml install-config.yaml
[root@services installer]# openshift-install create ignition-configs
[root@services installer]# ls -l

total 360000
drwxr-x---. 2 root root        50 Aug 26 08:11 auth
-rw-r-----. 1 root root    315822 Aug 26 08:12 bootstrap.ign
-rw-r--r--. 1 root root      6321 Aug 26 08:11 install-config-base.yaml
-rw-r-----. 1 root root      1846 Aug 26 08:11 master.ign
-rw-r-----. 1 root root        94 Aug 26 08:12 metadata.json
-rwxr-xr-x. 1 root root 368300032 Jul 22 07:46 openshift-install
-rw-r-----. 1 root root      1846 Aug 26 08:11 worker.ign
```

Copy the created ignition files to our `httpd` server:

```shell
[root@services ~]# mkdir -p /var/www/html/okd/ignitions/
[root@services ~]# \cp ~/installer/*.ign /var/www/html/okd/ignitions/
[root@services ~]# \mv /var/www/html/okd/ignitions/master.ign /var/www/html/okd/ignitions/control.ign
[root@services ~]# \mv /var/www/html/okd/ignitions/worker.ign /var/www/html/okd/ignitions/compute.ign
[root@services ~]# chown -R apache.apache /var/www/html
[root@services ~]# restorecon -RFv /var/www/html/
```

Enable all services:

```shell
[root@services ~]# systemctl enable --now haproxy dhcpd httpd tftp named xinetd
```

Next: [Installation](03-installation.md)
