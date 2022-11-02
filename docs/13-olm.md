# Operator Lifecycle Manager

For OKD clusters that are installed on restricted networks, also known as
disconnected clusters, Operator Lifecycle Manager (OLM) by default cannot access
the sources hosted remotely because those remote sources require full Internet
connectivity. Administrators need to mirror the registries on a node with full
internet access instead and configure OKD to use images from the mirror instead.

## Disable openshift-samples cluster operator

The samples operator manages the sample image streams and templates stored in the
openshift namespace, and any docker credentials, stored as a secret, needed for
the image streams to import the images they reference. Most of the time those
image streams reference images that are not available in the mirror registry.
Using one of those templates will most likely fail when trying to pull the
images. Therefore disabling the operator is the easiest way to solve this issue:

```bash
[okd@services ~]$ oc patch configs.samples.operator.openshift.io cluster -p '{"spec":{"managementState":"Removed"}}' --type=merge
```

## Disable default OperatorHub sources

Before configuring OperatorHub to instead use local catalog sources in a
restricted network environment, you must disable the default catalogs.

```bash
[okd@services ~]$ oc patch operatorhub cluster -p '{"spec":{"disableAllDefaultSources":true}}' --type=merge
```

## Mirror content

If you do not have access to an account that does not get rate limited at Docker
Hub, feel free to skip this section. Otherwise make sure that your access token
is configured correctly in your `pull-secret.txt` file.

Mirroring the operator catalog will consume a lot of space. A valid approach
might be to configure a pull trough registry but for disconnected environments
this is usually not an option. Lets make sure that the services node can handle
this:

```bash
[okd@services ~]$ sudo lvresize -L +200G --resizefs /dev/mapper/fedora_services-root
```

The `oc adm catalog mirror` command extracts the contents of an index image to
generate the manifests required for mirroring. The default behavior of the
command automatically mirror all of the image content from the index image to
the mirror registry after generating manifests. This process might take several
hours depending on the network connection used. As this will download a large
number of container images you most likely will hit the Docker pull rate limit.
If so, retry at a later point of time again or try to increase the rate limit.

```bash
[okd@services ~]$ oc adm catalog mirror \
    quay.io/operator-framework/upstream-community-operators:latest \
    $HOSTNAME:5000 \
    -a ~/pull-secret.txt \
    --index-filter-by-os='.*'
[okd@services ~]$ oc apply -f ~/manifests-upstream-community-operators-*/imageContentSourcePolicy.yaml
```

Then run:

```bash
[okd@services ~]$ oc image mirror \
    -a ~/pull-secret.txt \
    quay.io/operator-framework/upstream-community-operators:latest \
    $HOSTNAME:5000/upstream-community-operators/upstream-community-operators:latest
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/13-olm/catalog-source.yaml
[okd@services ~]$ oc patch operatorhubs.config.openshift.io cluster -n openshift-marketplace --type merge \
    --patch '{"spec":{"sources":[{"disabled": true,"name": "community-operators"}]}}'
```

Next: [Network](14-network.md)
