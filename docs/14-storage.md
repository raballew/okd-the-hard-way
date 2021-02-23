# Storage

## Install

oc create -f okd-the-hard-way/src/okd/storage/rook-ceph/crds.yaml -f okd-the-hard-way/src/okd/storage/rook-ceph/common.yaml
oc create -f okd-the-hard-way/src/okd/storage/rook-ceph/operator.yaml
oc create -f okd-the-hard-way/src/okd/storage/rook-ceph/cluster.yaml
oc create -R -f okd-the-hard-way/src/okd/storage/rook-ceph/storageclasses/

configure private network with no access to host to pull images only from mirror

mirror to private registry:
skopeo copy --authfile /root/pull-secret.txt --all --format v2s2 \
    docker://quay.io/openshift/okd@$line \
    docker://services.okd.example.com:5000/ceph/ceph

https://github.com/rook/rook/blob/release-1.0/cluster/examples/kubernetes/ceph/cluster.yaml
https://rook.io/docs/rook/v1.0/openshift.html

## Configure

### Default storage class

### Registry

//local storage
//kostenlose alternative zu ocs

//registry
//openshift monitoring
//openshift logging

Next: [Network](15-network.md)
