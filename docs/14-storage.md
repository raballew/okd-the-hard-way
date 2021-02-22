# Storage

## Operators

### Rook CephFS

oc create -f src/okd/storage/rook-ceph/crds.yaml
oc create -f src/okd/storage/rook-ceph/common.yaml
oc create -f src/okd/storage/rook-ceph/operator.yaml
oc create -f src/okd/storage/rook-ceph/cluster.yaml

skopeo copy --authfile /root/pull-secret.txt --all --format v2s2 \
    docker://quay.io/openshift/okd@$line \
    docker://services.okd.example.com:5000/ceph/ceph

https://github.com/rook/rook/blob/release-1.0/cluster/examples/kubernetes/ceph/cluster.yaml
https://rook.io/docs/rook/v1.0/openshift.html

### Default storage class

## Configure

### Registry

//local storage
//kostenlose alternative zu ocs

//registry
//openshift monitoring
//openshift logging

Next: [Network](15-network.md)
