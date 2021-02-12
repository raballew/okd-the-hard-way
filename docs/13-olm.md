# Operator Lifecycle Manager

For OKD clusters that are installed on restricted networks, also known as
disconnected clusters, Operator Lifecycle Manager (OLM) by default cannot access
the sources hosted remotely because those remote sources require full Internet
connectivity. Administrators need to mirror the registries on a node with full
internet access instead and configure OKD to use images from the mirror instead.

## Disable default OperatorHub sources

Before configuring OperatorHub to instead use local catalog sources in a
restricted network environment, you must disable the default catalogs.

```shell
[root@services ~]# oc patch OperatorHub cluster --type json \
  -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
```

## Mirror content

Mirroring the operator catalog will consume a lot of space. Lets make sure that
the services node can handle this:

```shell
[root@services ~]# lvresize -L +100G --resizefs /dev/mapper/fedora_services-root
```

The `oc adm catalog mirror` command extracts the contents of an index image to
generate the manifests required for mirroring. The default behavior of the
command automatically mirror all of the image content from the index image to
the mirror registry after generating manifests.

```shell
[root@services ~]# oc adm catalog mirror \
  quay.io/operator-framework/upstream-community-operators:latest \
  services.okd.example.com:5000 \
  -a /root/pull-secret.txt \
  --filter-by-os='.*'
[root@services ~]# oc apply -f ./upstream-community-operators-manifests/imageContentSourcePolicy.yaml
[root@services ~]# oc image mirror \
  -a /root/pull-secret.txt \
  quay.io/operator-framework/upstream-community-operators:latest \
  services.okd.example.com:5000/upstream-community-operators/upstream-community-operators:latest
```

## Configure operators

### Disable insights cluster operator

A disconnected cluster should not communicate anywhere. Opting out of remote
health reporting is a logical step to do.

### Disable openshift-samples cluster operator




// mirror olm for current release // explain where to get it // ist image
content source auf registry anstatt image möglich?

Next: [Storage](14-storage.md)
