# Storage

Dynamic volume provisioning allows storage volumes to be created on-demand.
Without dynamic provisioning, cluster administrators have to manually make calls
to their cloud or storage provider to create new storage volumes, and then
create persistent volume objects to represent them in Kubernetes. This can be a
challenging task as one might to request NFS share or alike in a more or less
automated fashion. As long as there are only the default applications requiring
storage such as the registry, alerting and monitoring the number and variety of
volumes is quite low. As soon as one starts to onboard new projects demand and
time spend managing those resources will increase. The dynamic provisioning
feature eliminates the need for cluster administrators to pre-provision storage.
Instead, it automatically provisions storage when it is requested by users.

## Install

Ceph is a highly scalable distributed storage solution for block storage, object
storage, and shared filesystem with years of production deployments.

The Rook operator is a simple container that has all that is needed to bootstrap
and monitor the storage cluster. Rook automatically configures the Ceph-CSI
driver to mount the storage to your pods.

Before starting the installation we need to make sure that all necessary images
are available in the mirror registry and image content source policies point to
the correct registries.

The list of needed images can be retrieved by running:

```bash
[okd@services ~]$ awk '/image:/ {print $2}' ~/okd-the-hard-way/src/15-storage/rook-ceph/operator.yaml ~/okd-the-hard-way/src/15-storage/rook-ceph/cluster.yaml | tr -d '"' | tee -a ~/rook-ceph-images.txt && awk '/quay.io/ || /k8s.gcr.io/ {print $2}' ~/okd-the-hard-way/src/15-storage/rook-ceph/operator.yaml | tr -d '"' | tee -a ~/rook-ceph-images.txt
```

Then mirror the images and create the image content source policy. Rolling out a
new image content source policy will take some time.

```bash
while read source; do
    target=$(echo "$source" | sed "s#^[^/]*#$HOSTNAME:5000#g"); \
    skopeo copy --authfile ~/pull-secret.txt --all --format v2s2 docker://$source docker://$target ; \
done <~/rook-ceph-images.txt
[okd@services ~]$ oc apply -f  ~/okd-the-hard-way/src/15-storage/rook-ceph/image-content-source-policy.yaml
```

Installing Rook Ceph is as simple as creating several custom resources and
deploying the operator to a dedicated namespace and configuring the required
storage classes.

```bash
[okd@services ~]$ oc create -f ~/okd-the-hard-way/src/15-storage/rook-ceph/crds.yaml -f okd-the-hard-way/src/15-storage/rook-ceph/common.yaml
[okd@services ~]$ oc create -f ~/okd-the-hard-way/src/15-storage/rook-ceph/operator.yaml
[okd@services ~]$ oc create -f ~/okd-the-hard-way/src/15-storage/rook-ceph/cluster.yaml
[okd@services ~]$ oc create -R -f ~/okd-the-hard-way/src/15-storage/rook-ceph/storageclasses/
```

## Configure

### Default storage class

For persistent volumes claims that do not require any specific storage class the
default storage class will be used when requesting dynamic provisioned storage.
The default storage class has an annotation
`storageclass.kubernetes.io/is-default-class` set to true. Any other value or
absence of the annotation is interpreted as false. For this cluster the storage
class [filesystem](../src/15-storage/rook-ceph/storageclasses/filesystem.yaml)
is configured to be the default.

```bash
[okd@services ~]$ oc get storageclass

NAME                   PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
block                  rook-ceph.rbd.csi.ceph.com      Delete          Immediate           true                   3m40s
filesystem (default)   rook-ceph.cephfs.csi.ceph.com   Delete          Immediate           true                   3m40s
object                 rook-ceph.ceph.rook.io/bucket   Delete          Immediate           false                  3m40s
```

### Registry

OKD provides a built-in container image registry that runs as a standard
workload on the cluster. The registry is configured and managed by an
infrastructure operator. It provides an out-of-the-box solution for users to
manage the images that run their workloads, and runs on top of the existing
cluster infrastructure. This registry can be scaled up or down like any other
cluster workload and does not require specific infrastructure provisioning. In
addition, it is integrated into the cluster user authentication and
authorization system, which means that access to create and retrieve images is
controlled by defining user permissions on the image resources.

When using image builds on top of OKD the image registry is configured as the
default target where to push the images to. While resources such as image
streams are configured to be standard API resources, the image data is stored on
a dedicated volumes. Now that dynamic storage provisioning is configured, lets
configure the registry properly. For a scaled highly available registry object
storage is recommended but can only be configured for public cloud providers.
Therefore OKD will use the default storage class `filesystem` to create a
persistent volume.

```bash
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/15-storage/registry/configuration.yaml
```

### Monitoring

OKD includes a pre-configured, pre-installed, and self-updating monitoring stack
that provides monitoring for core platform components. OKD delivers monitoring
best practices out of the box. A set of alerts are included by default that
immediately notify cluster administrators about issues with a cluster. Default
dashboards in the OKD web console include visual representations of cluster
metrics to help you to quickly understand the state of your cluster.

```bash
[okd@services ~]$ oc apply -f ./okd-the-hard-way/src/15-storage/monitoring/configuration.yaml
```

Next: [Operations](16-operations.md)
