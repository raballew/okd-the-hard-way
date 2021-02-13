# Operator Lifecycle Manager

For OKD clusters that are installed on restricted networks, also known as
disconnected clusters, Operator Lifecycle Manager (OLM) by default cannot access
the sources hosted remotely because those remote sources require full Internet
connectivity. Administrators need to mirror the registries on a node with full
internet access instead and configure OKD to use images from the mirror instead.

## Disable openshift-samples cluster operator

The samples operator manages the sample imagestreams and templates stored in the
openshift namespace, and any docker credentials, stored as a secret, needed for
the imagestreams to import the images they reference. Most of the time those
imagestreams reference images that are not available in the mirror registry.
Using one of those templates will most likely fail when trying to pull the
images. Therefore disabling the operator is the easiest way to solve this issue:

```bash
[root@services ~]# oc patch configs.samples.operator.openshift.io cluster -p '{"spec":{"managementState":"Removed"}}' --type=merge
```

## Disable default OperatorHub sources

Before configuring OperatorHub to instead use local catalog sources in a
restricted network environment, you must disable the default catalogs.

```bash
[root@services ~]# oc patch operatorhub cluster -p '{"spec":{"disableAllDefaultSources":true}}' --type=merge
```

## Mirror content

Mirroring the operator catalog will consume a lot of space. Lets make sure that
the services node can handle this:

```bash
[root@services ~]# lvresize -L +450G --resizefs /dev/mapper/fedora_services-root
```

The `oc adm catalog mirror` command extracts the contents of an index image to
generate the manifests required for mirroring. The default behavior of the
command automatically mirror all of the image content from the index image to
the mirror registry after generating manifests. This process might take several
hours depending on the network connection used. As this will download a large
number of container images you most likely will hit the Docker pull rate limit.
If so, retry at a later point of time again or try to increase the rate limit.

```bash
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
[root@services ~]# oc apply -f ./okd-the-hard-way/src/okd/olm/catalog-source.yaml
[root@services ~]# oc patch operatorhubs.config.openshift.io cluster -n openshift-marketplace --type merge \
    --patch '{"spec":{"sources":[{"disabled": true,"name": "community-operators"}]}}'
```

Next: [Storage](14-storage.md)
