# Network

## Configure NTP server

As the cluster is already bootstrapped, update the machine configuration by
encoding the desired content of a /etc/chrony.conf file to tell the nodes where
to get the base time from. The services machine hosts the NTP server.

```bash
[okd@services ~]# config=$(cat ~/okd-the-hard-way/src/14-network/ntp/chrony.conf | base64 -w0)
[okd@services ~]# sed -i "s/<BASE64-ENCODED-STRING>/$config/" ~/okd-the-hard-way/src/14-network/ntp/90-{compute,infra,master,storage,worker}-chrony-config.yaml
[okd@services ~]# oc apply -f ~/okd-the-hard-way/src/14-network/ntp/
```

## Dynamic assignment of IP addresses for services

Kubernetes does not offer an implementation of network load balancers (services
of type load balancer) for bare metal clusters. The implementations of network
load balancer that Kubernetes does ship with are all glue code that calls out to
various public cloud platforms. If you’re not running on a supported platform,
load balancer services will remain in the pending state indefinitely when
created.

Bare metal cluster operators are left with two lesser tools to bring user
traffic into their clusters, node ports and external IP services. Both of these
options have significant downsides for production use, which makes bare metal
clusters second class citizens in the Kubernetes ecosystem.

According to the design of the service resource, you should not choose your own
port number if that choice might collide with someone else's choice. That is an
isolation failure. In order to allow you to choose a port number for your
services, we must ensure that no two services can collide. Kubernetes does that
by allocating each service its own IP address. So node port services are not
recommended and external IP services can only be created by cluster admins. Both
solutions are not favourable and will increase the workload on platform
operations side, the same way as static storage provisioning would.

OKD also does not solve this issue out of the box. MetalLB, an operator, aims to
redress this imbalance by offering a network load balancer implementation that
integrates with standard network equipment, so that external services on bare
metal clusters also just work as much as possible.

### Install

Before starting the installation we need to make sure that all necessary images
are available in the mirror registry and image content source policies point to
the correct registries.

The list of needed images can be easily retrieved by running:

```bash
[okd@services ~]# cat ~/okd-the-hard-way/src/14-network/metallb/* | grep image: | sed 's/^.*: //' > metallb-images.txt
```

Then mirror the images and create the image content source policy. Rolling out a
new image content source policy will take some time. Make sure to wait until all
nodes are rebooted.

```bash
[okd@services ~]# echo "apiVersion: operator.openshift.io/v1alpha1" >> metallb-images.yaml
[okd@services ~]# echo "kind: ImageContentSourcePolicy" >> metallb-images.yaml
[okd@services ~]# echo "metadata:" >> metallb-images.yaml
[okd@services ~]# echo "  name: metallb" >> metallb-images.yaml
[okd@services ~]# echo "spec:" >> metallb-images.yaml
[okd@services ~]# echo "  repositoryDigestMirrors:" >> metallb-images.yaml
[okd@services ~]# while read source; do
    target=$(echo "$source" | sed "s#^[^/]*#$HOSTNAME:5000#g"); \
    skopeo copy --authfile ~/pull-secret.txt --all --format v2s2 docker://$source docker://$target ; \
    no_tag_source=$(echo "$source" | sed 's#[^@]*$##' | sed 's#.$##') ; \
    no_tag_target=$(echo "$target" | sed 's#[^@]*$##' | sed 's#.$##') ; \
    echo "  - mirrors:" >> metallb-images.yaml ; \
    echo "    - $no_tag_target" >> metallb-images.yaml ; \
    echo "    source: $no_tag_source" >> metallb-images.yaml ; \
done <metallb-images.txt
[okd@services ~]# oc apply -f metallb-images.yaml
```

Installing MetalLB is as simple as creating several custom resources and
deploying the operator to a dedicated namespace, fixing permissions and
configuring the allowed range of IP addresses.

```bash
[okd@services ~]# oc apply -f okd-the-hard-way/src/14-network/metallb/namespace.yaml
[okd@services ~]# oc apply -f okd-the-hard-way/src/14-network/metallb/operator.yaml
[okd@services ~]# oc adm policy add-scc-to-user privileged -n metallb-system -z speaker
[okd@services ~]# oc create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```

### Configure

MetalLB can work in two modes. Layer 2 and Border Gateway Protocol (BGP) mode.
BGP is the protocol the literally makes the internet work and it is used to
route traffic. Since BGP is at the absolute core of the internet, when it is
misconfigured or abused it can cause havoc across large portions of the
internet. As BGP requires a high level of trust, usually even if BGP is
available one does not have access to this solution and therefore layer 2 mode
must be configured.

In layer 2 mode, one of the nodes advertises the load balanced IP (VIP) via
either the ARP (IPv4) or NDP (IPv6) protocol. This mode has several limitations:
first, given a VIP, all the traffic for that VIP goes through a single node
potentially limiting the bandwidth. The second limitation is a potentially very
slow failover as detecting unhealthy nodes is a slow operation in Kubernetes
which can take several minutes.

Configuring a layer 2 MetalLB is as simple a specifing ranges of IP addresses
that can be consumed automatically. When configuring the range make sure it is
in the subnet defined in [dhcpd.conf](../src/02-services/dhcpd.conf) and that it
does not collide with the IP of a node.

```bash
[okd@services ~]# oc apply -f okd-the-hard-way/src/14-network/metallb/configuration.yaml
```

Next: [Storage](15-storage.md)
