# Installation

A good practice is to start the bootstrap VM first. Then step by step all other
machines. They will start and boot up. Because of the `--pxe` flag the VMs will
send DHCP broadcasts that request PXE boots. The DHCP server then picks up this
broadcast and replies with an IP address to use. In this case the returned IP
address will be the services VMs IP address. Then the proper FCOS image and
ignition file are selected and the installation begins.

// TODO continue here

```shell
[root@okd ~]# su - okd
[okd@okd ~]$ export LIBVIRT_DEFAULT_URI=qemu:///system
[okd@okd ~]# declare -A nodes \
nodes["bootstrap"]="f8:75:a4:ac:01:00" \
nodes["compute-0"]="f8:75:a4:ac:02:00" \
nodes["compute-1"]="f8:75:a4:ac:02:01" \
nodes["compute-2"]="f8:75:a4:ac:02:02" \
nodes["master-0"]="f8:75:a4:ac:03:00" \
nodes["master-1"]="f8:75:a4:ac:03:01" \
nodes["master-2"]="f8:75:a4:ac:03:02" \
nodes["infra-0"]="f8:75:a4:ac:04:00" \
nodes["infra-1"]="f8:75:a4:ac:04:01" \
nodes["infra-2"]="f8:75:a4:ac:04:02" ; \
for key in ${!nodes[@]} ; \
do \
    virt-install \
      -n ${key}.$HOSTNAME \
      --description "${key}.$HOSTNAME" \
      --os-type=Linux \
      --os-variant=fedora33 \
      --ram=16384 \
      --vcpus=4 \
      --disk okd/images/${key}.$HOSTNAME.0.qcow2,bus=virtio,size=128 \
      --nographics \
      --pxe \
      --network network=okd,mac=${nodes[${key}]} \
      --boot menu=on,useserial=on --noreboot --noautoconsole ; \
done
[okd@okd ~]# declare -A storage \
storage["storage-0"]="f8:75:a4:ac:05:00" \
storage["storage-1"]="f8:75:a4:ac:05:01" \
storage["storage-2"]="f8:75:a4:ac:05:02" ; \
for key in ${!storage[@]} ; \
do \
    virt-install \
      -n ${key}.$HOSTNAME \
      --description "${key}.$HOSTNAME" \
      --os-type=Linux \
      --os-variant=fedora33 \
      --ram=32768 \
      --vcpus=8 \
      --disk okd/images/${key}.$HOSTNAME.0.qcow2,bus=virtio,size=128 \
      --nographics \
      --pxe \
      --network network=okd,mac=${storage[${key}]} \
      --boot menu=on,useserial=on --noreboot --noautoconsole ; \
done
```

You can check the current state of the installation with:

```shell
[okd@okd ~]# watch virsh list --all
```

Once the services VM is the only one running, add additional disk and power on
all virtual machines again:

```shell
[okd@okd ~]# for node in \
  storage-0 storage-1 storage-2 ; \
do \
  virsh attach-disk $node.$HOSTNAME \
    --source /home/okd/okd/images/$node.$HOSTNAME.1.qcow2\
    --targetbus virtio \
    --target vdb \
    --persistent
done
[okd@okd ~]# for node in \
  bootstrap \
  master-0 master-1 master-2 \
  compute-0 compute-1 compute-2 \
  infra-0 infra-1 infra-2 \
  storage-0 storage-1 storage-2 ; \
do \
  virsh autostart $node.$HOSTNAME ; \
  virsh start $node.$HOSTNAME ; \
done
```

Wait until the cluster-bootstrapping process is complete. To check if the
cluster is up run the following commands:

```shell
[root@services ~]# export KUBECONFIG=~/installer/auth/kubeconfig
[root@services ~]# watch oc whoami

system:admin
```

As of now the cluster is bootstrapped but more steps need to be done before the
installation can be considered complete.

If you experience any trouble take a look at the offical [OKD
documentation](https://docs.okd.io/latest/installing/installing_bare_metal/installing-restricted-networks-bare-metal.html)
first. If you are sure that you found a bug related to OKD, create a new issue
[here](https://github.com/openshift/okd/issues/new/choose).

## Approving the CSRs for your machines

When you add machines to a cluster, two pending certificates signing request
(CSRs) are generated for each machine that you added. You must verify that these
CSRs are approved or, if necessary, approve them yourself.

Review the pending CSRs and ensure that the you see a client and server request
with `Pending` or `Approved` status for each machine that you added to the
cluster:

```shell
[root@services ~]# oc get csr
```

> Because the initial CSRs rotate automatically, approve your CSRs within an
> hour of adding the machines to the cluster.

Manually approve CSRs if they are pending:

```shell
[root@services ~]# oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
```

> This command might need to be executed multiple times as more and more CSRs
> are created.

After that the status of each CSR should become `Approved,Issued` and all nodes
should be in status `Ready`.

```shell
[root@services ~]# oc get nodes

NAME        STATUS   ROLES           AGE     VERSION
compute-0   Ready    worker          2m21s   v1.18.3
compute-1   Ready    worker          2m23s   v1.18.3
compute-2   Ready    worker          2m24s   v1.18.3
master-0   Ready    master          12m     v1.18.3
master-1   Ready    master          12m     v1.18.3
master-2   Ready    master          12m     v1.18.3
infra-0     Ready    worker          2m27s   v1.18.3
infra-1     Ready    worker          2m30s   v1.18.3
infra-2     Ready    worker          2m21s   v1.18.3
```

## Define upgrade repository

To use the new mirrored repository for upgrades create an image content source
policy:

```shell
[root@services ~]# oc apply -f okd-the-hard-way/src/okd/installation/okd-image-content-source-policy.yaml
```

## Wait until all cluster operators become online

The cluster is fully up and running once all cluster operators become available.

```shell
[root@services ~]# oc get clusteroperator

NAME                                       VERSION                         AVAILABLE   PROGRESSING   DEGRADED   SINCE
authentication                             4.5.0-0.okd-2020-08-12-020541   True        False         False      22m
cloud-credential                           4.5.0-0.okd-2020-08-12-020541   True        False         False      33m
cluster-autoscaler                         4.5.0-0.okd-2020-08-12-020541   True        False         False      26m
config-operator                            4.5.0-0.okd-2020-08-12-020541   True        False         False      26m
console                                    4.5.0-0.okd-2020-08-12-020541   True        False         False      23m
csi-snapshot-controller                    4.5.0-0.okd-2020-08-12-020541   True        False         False      22m
dns                                        4.5.0-0.okd-2020-08-12-020541   True        False         False      29m
etcd                                       4.5.0-0.okd-2020-08-12-020541   True        True          True       29m
image-registry                             4.5.0-0.okd-2020-08-12-020541   True        False         False      26m
ingress                                    4.5.0-0.okd-2020-08-12-020541   True        False         False      23m
insights                                   4.5.0-0.okd-2020-08-12-020541   True        False         False      26m
kube-apiserver                             4.5.0-0.okd-2020-08-12-020541   True        True          True       29m
kube-controller-manager                    4.5.0-0.okd-2020-08-12-020541   True        False         False      28m
kube-scheduler                             4.5.0-0.okd-2020-08-12-020541   True        False         False      29m
kube-storage-version-migrator              4.5.0-0.okd-2020-08-12-020541   True        False         False      23m
machine-api                                4.5.0-0.okd-2020-08-12-020541   True        False         False      27m
machine-approver                           4.5.0-0.okd-2020-08-12-020541   True        False         False      29m
machine-config                             4.5.0-0.okd-2020-08-12-020541   True        False         False      28m
marketplace                                4.5.0-0.okd-2020-08-12-020541   True        False         False      25m
monitoring                                 4.5.0-0.okd-2020-08-12-020541   True        False         False      16m
network                                    4.5.0-0.okd-2020-08-12-020541   True        False         False      31m
node-tuning                                4.5.0-0.okd-2020-08-12-020541   True        False         False      31m
openshift-apiserver                        4.5.0-0.okd-2020-08-12-020541   True        False         False      27m
openshift-controller-manager               4.5.0-0.okd-2020-08-12-020541   True        False         False      27m
openshift-samples                          4.5.0-0.okd-2020-08-12-020541   True        False         False      25m
operator-lifecycle-manager                 4.5.0-0.okd-2020-08-12-020541   True        False         False      30m
operator-lifecycle-manager-catalog         4.5.0-0.okd-2020-08-12-020541   True        False         False      30m
operator-lifecycle-manager-packageserver   4.5.0-0.okd-2020-08-12-020541   True        False         False      27m
service-ca                                 4.5.0-0.okd-2020-08-12-020541   True        False         False      31m
storage                                    4.5.0-0.okd-2020-08-12-020541   True        False         False      26m
```

## Remove the bootstrap resources

Once the cluster is up and running it is save to remove the temporary
bootstrapping node.

```shell
[root@okd ~]# virsh shutdown bootstrap
[root@okd ~]# virsh undefine bootstrap
[root@services ~]# sed -i '/bootstrap/d' /etc/haproxy/haproxy.cfg
[root@services ~]# systemctl restart haproxy
```

Next: [Authentication](10-authentication.md)
