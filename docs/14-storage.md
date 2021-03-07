# Storage

Dynamic volume provisioning allows storage volumes to be created on-demand.
Without dynamic provisioning, cluster administrators have to manually make calls
to their cloud or storage provider to create new storage volumes, and then
create persistent volume objects to represent them in Kubernetes. This can be a
tidious task as one might to request NFS share or alike in a more or less
automated fashion. As long as there are only the default applications requiring
storage such as the registry, alerting and monitoring the number and variety of
volumes is quite low. As soon as one starts to onboard new projects demand and
time spend managing those resources will increase. The dynamic provisioning
feature eliminates the need for cluster administrators to pre-provision storage.
Instead, it automatically provisions storage when it is requested by users.

## Install

Ceph is a highly scalable distributed storage solution for block storage, object
storage, and shared filesystems with years of production deployments.

The Rook operator is a simple container that has all that is needed to bootstrap
and monitor the storage cluster. Rook automatically configures the Ceph-CSI
driver to mount the storage to your pods.

Before starting the installation we need to make sure that all necessary images
are available in the mirror registry and image content source policies point to
the correct registries.

The list of needed images can be easily retrieved by running:

```bash
[root@services ~]# awk '/image:/ {print $2}' ./okd-the-hard-way/src/okd/storage/rook-ceph/operator.yaml ./okd-the-hard-way/src/okd/storage/rook-ceph/cluster.yaml | tee -a rook-ceph-images.txt && awk '/quay.io/ || /k8s.gcr.io/ {print $3}' ./okd-the-hard-way/src/okd/storage/rook-ceph/operator.yaml | tr -d '"' | tee -a rook-ceph-images.txt
[root@services ~]# echo "apiVersion: operator.openshift.io/v1alpha1" >> rook-images.yaml
[root@services ~]# echo "kind: ImageContentSourcePolicy" >> rook-images.yaml
[root@services ~]# echo "metadata:" >> rook-images.yaml
[root@services ~]# echo "  name: rook-ceph" >> rook-images.yaml
[root@services ~]# echo "spec:" >> rook-images.yaml
[root@services ~]# echo "  repositoryDigestMirrors:" >> rook-images.yaml
[root@services ~]# while read source; do
    target=$(echo "$source" | sed 's#^[^/]*#services.okd.example.com:5000#g'); \
    echo $source
    echo $target
    skopeo copy --authfile /root/pull-secret.txt --all --format v2s2 docker://$source docker://$target ; \
    no_tag_source=$(echo "$source" | sed 's#[^:]*$##' | sed 's#.$##') ; \
    no_tag_target=$(echo "$target" | sed 's#[^:]*$##' | sed 's#.$##') ; \
    echo "  - mirrors:" >> rook-images.yaml ; \
    echo "    - $no_tag_target" >> rook-images.yaml ; \
    echo "    source: $no_tag_source" >> rook-images.yaml ; \
done <rook-ceph-images.txt
```

Then mirror the images and create the image content source policy. Rolling out a
new image content source policy will take some time. Make sure to wait until all
nodes are rebooted by using the same method as describe when creating a new
machine config pool.

```bash
[root@services ~]# oc apply -f rook-images.yaml
```

Installing Rook Ceph is as simple as creating several custom resources and
deploying the operator to a dedicated namespace and configuring the required
storage classes.

```bash
[root@services ~]# oc create -f ./okd-the-hard-way/src/okd/storage/rook-ceph/crds.yaml -f okd-the-hard-way/src/okd/storage/rook-ceph/common.yaml
[root@services ~]# oc create -f ./okd-the-hard-way/src/okd/storage/rook-ceph/operator.yaml
[root@services ~]# oc create -f ./okd-the-hard-way/src/okd/storage/rook-ceph/cluster.yaml
[root@services ~]# oc create -R -f ./okd-the-hard-way/src/okd/storage/rook-ceph/storageclasses/
```

## Configure

### Default storage class

For persistent volumes claims that do not require any specific storage class the
default storage class will be used when requesting dynamic provisioned storage.
The default storage class has an annotation
`storageclass.kubernetes.io/is-default-class` set to true. Any other value or
absence of the annotation is interpreted as false. For this cluster the storage
class [filesystem](/src/okd/storage/rook-ceph/storageclasses/filesystem.yaml) is
configured to be the default.

```bash
[root@services ~]# oc get storageclass
NAME                   PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
block                  rook-ceph.rbd.csi.ceph.com      Delete          Immediate           true                   83m
filesystem (default)   rook-ceph.cephfs.csi.ceph.com   Delete          Immediate           true                   84m
object                 rook-ceph.ceph.rook.io/bucket   Delete          Immediate           false                  83m
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

When using image builds ontop of OKD the image registry is configured as the
default target where to push the images to. While resources such as image
streams are configured to be standard API resources, the image data is stored on
a dedicated volumes. Now that dynamic storage provisioning is configured, lets
configure the registry properly. For a scaled highly available registry object
storage is recommended but can only be configured for public cloud providers.
Therefore OKD will use the default storage class `filesystem` to create a
persistent volume.

```bash
[root@services ~]# oc apply -f ./okd-the-hard-way/src/okd/storage/registry/configuration.yaml
```

### Monitoring

OKD includes a pre-configured, pre-installed, and self-updating monitoring stack
that provides monitoring for core platform components. OKD delivers monitoring
best practices out of the box. A set of alerts are included by default that
immediately notify cluster administrators about issues with a cluster. Default
dashboards in the OKD web console include visual representations of cluster
metrics to help you to quickly understand the state of your cluster.

```bash
[root@services ~]# oc apply -f ./okd-the-hard-way/src/okd/storage/monitoring/cluster-configuration.yaml
```

Next: [Network](15-network.md)
