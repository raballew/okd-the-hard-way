# Installation

A good practice is to start the bootstrap VM first. Then step by step all other
machines. They will start and boot up. Because of the `--pxe` flag the VMs will
send DHCP broadcasts that request PXE boots. The DHCP server then picks up this
broadcast and replies with an IP address to use. In this case the returned IP
address will be the services VMs IP address. Then the proper FCOS image and
ignition file are selected and the installation begins.

```bash
[root@okd ~]# su - okd
[okd@okd ~]$ echo "export LIBVIRT_DEFAULT_URI=qemu:///system" >> ~/.bash_profile
[okd@okd ~]$ source ~/.bash_profile
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

```bash
[okd@okd ~]# watch virsh list --all
```

Once the services VM is the only one running, add additional disk and power on
all virtual machines again:

```bash
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

```bash
[root@services ~]# \cp ~/installer/auth/kubeconfig ~/
[root@services ~]# echo "export KUBECONFIG=~/kubeconfig" >> ~/.bash_profile
[root@services ~]# source ~/.bash_profile
[root@services ~]# watch oc whoami

system:admin
```

The cluster is bootstrapped now but more steps need to be done before the
installation can be considered complete.

If you experience any trouble take a look at the offical [OKD
documentation](https://docs.okd.io/latest/installing/installing_bare_metal/installing-restricted-networks-bare-metal.html)
first. If you are sure that you found a bug related to OKD, create a new issue
[here](https://github.com/openshift/okd/issues/new/choose).

## Approving the CSRs for your machines

When you add machines to a cluster, two pending certificates signing request
(CSRs) are generated for each machine that you added. You must verify that these
CSRs are approved or, if necessary, approve them yourself. Due to the matter of
fact that we PXE booted all nodes with proper Ignition files in place, after a
few minutes, some CSRs should show up.

Review the pending CSRs and ensure that the you see a client and server request
with `Pending` or `Approved` status for each machine that you added to the
cluster:

```bash
[root@services ~]# oc get csr
```

> Because the initial CSRs rotate automatically, approve your CSRs within an
> hour of adding the machines to the cluster.

Manually approve CSRs if they are pending:

```bash
[root@services ~]# oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
```

> This command might need to be executed multiple times as more and more CSRs
> are created.

After that the status of each CSR should become `Approved,Issued` and all nodes
should be in status `Ready`.

```bash
[root@services ~]# oc get nodes

NAME                        STATUS   ROLES           AGE     VERSION
compute-0.okd.example.com   Ready    worker          2m33s   v1.19.2+4cad5ca-1023
compute-1.okd.example.com   Ready    worker          2m45s   v1.19.2+4cad5ca-1023
compute-2.okd.example.com   Ready    worker          2m37s   v1.19.2+4cad5ca-1023
infra-0.okd.example.com     Ready    worker          2m34s   v1.19.2+4cad5ca-1023
infra-1.okd.example.com     Ready    worker          2m44s   v1.19.2+4cad5ca-1023
infra-2.okd.example.com     Ready    worker          2m40s   v1.19.2+4cad5ca-1023
master-0.okd.example.com    Ready    master,worker   27m     v1.19.2+4cad5ca-1023
master-1.okd.example.com    Ready    master,worker   27m     v1.19.2+4cad5ca-1023
master-2.okd.example.com    Ready    master,worker   27m     v1.19.2+4cad5ca-1023
storage-0.okd.example.com   Ready    worker          2m43s   v1.19.2+4cad5ca-1023
storage-1.okd.example.com   Ready    worker          2m40s   v1.19.2+4cad5ca-1023
storage-2.okd.example.com   Ready    worker          2m40s   v1.19.2+4cad5ca-1023
```

## Wait until all cluster operators become online

The cluster is fully up and running once all cluster operators become available.

```bash
[root@services ~]# oc get clusteroperator

NAME                                       VERSION                         AVAILABLE   PROGRESSING   DEGRADED   SINCE
authentication                             4.6.0-0.okd-2021-01-23-132511   True        False         False      7m53s
cloud-credential                           4.6.0-0.okd-2021-01-23-132511   True        False         False      29m
cluster-autoscaler                         4.6.0-0.okd-2021-01-23-132511   True        False         False      24m
config-operator                            4.6.0-0.okd-2021-01-23-132511   True        False         False      25m
console                                    4.6.0-0.okd-2021-01-23-132511   True        False         False      13m
csi-snapshot-controller                    4.6.0-0.okd-2021-01-23-132511   True        False         False      25m
dns                                        4.6.0-0.okd-2021-01-23-132511   True        False         False      24m
etcd                                       4.6.0-0.okd-2021-01-23-132511   True        False         False      23m
image-registry                             4.6.0-0.okd-2021-01-23-132511   True        False         False      17m
ingress                                    4.6.0-0.okd-2021-01-23-132511   True        False         False      16m
insights                                   4.6.0-0.okd-2021-01-23-132511   True        False         False      25m
kube-apiserver                             4.6.0-0.okd-2021-01-23-132511   True        False         False      22m
kube-controller-manager                    4.6.0-0.okd-2021-01-23-132511   True        False         False      22m
kube-scheduler                             4.6.0-0.okd-2021-01-23-132511   True        False         False      22m
kube-storage-version-migrator              4.6.0-0.okd-2021-01-23-132511   True        False         False      24m
machine-api                                4.6.0-0.okd-2021-01-23-132511   True        False         False      25m
machine-approver                           4.6.0-0.okd-2021-01-23-132511   True        False         False      25m
machine-config                             4.6.0-0.okd-2021-01-23-132511   True        False         False      24m
marketplace                                4.6.0-0.okd-2021-01-23-132511   True        False         False      24m
monitoring                                 4.6.0-0.okd-2021-01-23-132511   True        False         False      16m
network                                    4.6.0-0.okd-2021-01-23-132511   True        False         False      25m
node-tuning                                4.6.0-0.okd-2021-01-23-132511   True        False         False      25m
openshift-apiserver                        4.6.0-0.okd-2021-01-23-132511   True        False         False      17m
openshift-controller-manager               4.6.0-0.okd-2021-01-23-132511   True        False         False      22m
openshift-samples                          4.6.0-0.okd-2021-01-23-132511   True        False         False      16m
operator-lifecycle-manager                 4.6.0-0.okd-2021-01-23-132511   True        False         False      24m
operator-lifecycle-manager-catalog         4.6.0-0.okd-2021-01-23-132511   True        False         False      25m
operator-lifecycle-manager-packageserver   4.6.0-0.okd-2021-01-23-132511   True        False         False      17m
service-ca                                 4.6.0-0.okd-2021-01-23-132511   True        False         False      25m
storage                                    4.6.0-0.okd-2021-01-23-132511   True        False         False      25m
```

## Remove the bootstrap resources

Once the cluster is up and running it is save to remove the temporary
bootstrapping node.

```bash
[root@okd ~]# virsh shutdown bootstrap.$HOSTNAME
[root@okd ~]# virsh undefine bootstrap.$HOSTNAME
[root@services ~]# sed -i '/bootstrap/d' /etc/haproxy/haproxy.cfg
[root@services ~]# systemctl restart haproxy
```

Next: [Authentication](10-authentication.md)
