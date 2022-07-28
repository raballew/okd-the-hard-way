# Nodes

## Machine Config Operator

OKD is an operator focused platform. An operator is a piece of software that
runs on the cluster. It implements the same concepts as a
[controller](https://kubernetes.io/docs/concepts/) by comparing the current
state of the system with the desired state and driving it towards the later one.
This logic however is implemented for a specific application or more specific a
CR rather than a normal cluster resource itself.

Nodes are managed by the machine config operator (MCO), which is an operator
with infrastructure perspective. It manages the operating system (OS) of each
node. This could include updates to systemd, the kernel or cri-o, etc.

An OKD cluster usually runs different workloads. Each of them has different
requirements to the underlying infrastructure. A application might need a
realtime operation system, others need tweaks for a high disk throughput.

In this setup different workloads should be separated from each other so that
OKD infrastructure components such as the software defined network (SDN) do not
compete for compute resources with application workload. Infrastructure workload
such as monitoring, logging and metering should run on nodes labeled with
`node-role.kubernetes.io/infra: ""`. Applications are deployed to nodes with the
label `node-role.kubernetes.io/compute: ""`. Nodes with label
`node-role.kubernetes.io/master: ""` should only execute the control plane
whereas `node-role.kubernetes.io/storage: ""` serves the storage backend. There
are are many more use cases not covered by this lab such as dedicated build nodes
or staging environments which require even more fine tuning but the concepts
show here apply to all of them.

Create separate a machine config pool (MCP) for each use case:

```bash
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/12-nodes/mcp-compute.yaml
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/12-nodes/mcp-infra.yaml
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/12-nodes/mcp-storage.yaml
```

All created MCPs inherit their properties from the MCP worker. Then relabel all
nodes to match the node selectors specified in the resource definitions:

```bash
[okd@services ~]$ oc label node compute-{0,1,2}.$SUB_DOMAIN.$BASE_DOMAIN node-role.kubernetes.io/compute=
[okd@services ~]$ oc label node compute-{0,1,2}.$SUB_DOMAIN.$BASE_DOMAIN node-role.kubernetes.io/worker-
[okd@services ~]$ oc label node infra-{0,1,2}.$SUB_DOMAIN.$BASE_DOMAIN node-role.kubernetes.io/infra=
[okd@services ~]$ oc label node infra-{0,1,2}.$SUB_DOMAIN.$BASE_DOMAIN node-role.kubernetes.io/worker-
[okd@services ~]$ oc label node storage-{0,1,2}.$SUB_DOMAIN.$BASE_DOMAIN node-role.kubernetes.io/storage=
[okd@services ~]$ oc label node storage-{0,1,2}.$SUB_DOMAIN.$BASE_DOMAIN node-role.kubernetes.io/worker-
```

After a few minutes verify that the MCO did its job:

```bash
[okd@services ~]$ oc get mcp

NAME      CONFIG                                              UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
compute   rendered-compute-fe9e4c553333366eaa038ae8b5ddddc6   True      False      False      3              3                   3                     0                      3m5s
infra     rendered-infra-fe9e4c553333366eaa038ae8b5ddddc6     True      False      False      3              3                   3                     0                      2m54s
master    rendered-master-8b59ed4ce8a8cc08726379507a97c746    True      False      False      3              3                   3                     0                      3h20m
storage   rendered-storage-fe9e4c553333366eaa038ae8b5ddddc6   True      False      False      3              3                   3                     0                      2m39s
worker    rendered-worker-fe9e4c553333366eaa038ae8b5ddddc6    True      False      False      0              0                   0                     0                      3h20m
```

## Migrate workload to dedicated nodes

Once the MCO finished configuring the nodes it is time to relocate workloads
running to their destination. For now this applies only to the ingress
controller. Scaling the ingress controller to three replicas ensures a high
availability setup.

```bash
[okd@services ~]$ oc patch ingresscontrollers.operator.openshift.io default -n openshift-ingress-operator -p '{"spec":{"nodePlacement":{"nodeSelector":{"matchLabels":{"node-role.kubernetes.io/infra":""}}}}}' --type=merge
[okd@services ~]$ oc patch ingresscontrollers.operator.openshift.io default -n openshift-ingress-operator --patch '{"spec":{"replicas": 3}}' --type=merge
```

## Default node selector

If there are multiple tenants running on the same cluster, they should not be
able to select a node on their own. Also master nodes should not share their
resources with application workload as this might reduce the performance of the
control plane.

```bash
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/12-nodes/scheduler.yaml
```

After a few minutes all nodes should have the correct roles assigned to them and
be ready now:

```bash
[okd@services ~]$ oc get nodes

NAME                        STATUS   ROLES     AGE     VERSION
compute-0.okd.example.com   Ready    compute   3h15m   v1.21.2+6438632-1505
compute-1.okd.example.com   Ready    compute   3h15m   v1.21.2+6438632-1505
compute-2.okd.example.com   Ready    compute   3h15m   v1.21.2+6438632-1505
infra-0.okd.example.com     Ready    infra     3h15m   v1.21.2+6438632-1505
infra-1.okd.example.com     Ready    infra     3h15m   v1.21.2+6438632-1505
infra-2.okd.example.com     Ready    infra     3h15m   v1.21.2+6438632-1505
master-0.okd.example.com    Ready    master    3h24m   v1.21.2+6438632-1505
master-1.okd.example.com    Ready    master    3h24m   v1.21.2+6438632-1505
master-2.okd.example.com    Ready    master    3h24m   v1.21.2+6438632-1505
storage-0.okd.example.com   Ready    storage   3h15m   v1.21.2+6438632-1505
storage-1.okd.example.com   Ready    storage   3h15m   v1.21.2+6438632-1505
storage-2.okd.example.com   Ready    storage   3h16m   v1.21.2+6438632-1505
```

## Reconfigure HAProxy

The ingress controller is running on the infra nodes only now. Therefore the
HAProxy should point the `https_router` and `http_router` to the infra nodes
only.

```bash
[root@services ~]# sed -i '/compute.*:80/d' /etc/haproxy/haproxy.cfg
[root@services ~]# sed -i '/compute.*:443/d' /etc/haproxy/haproxy.cfg
[root@services ~]# sed -i '/master.*:80/d' /etc/haproxy/haproxy.cfg
[root@services ~]# sed -i '/master.*:443/d' /etc/haproxy/haproxy.cfg
[root@services ~]# sed -i '/storage.*:80/d' /etc/haproxy/haproxy.cfg
[root@services ~]# sed -i '/storage.*:443/d' /etc/haproxy/haproxy.cfg
[root@services ~]# systemctl restart haproxy
```

Next: [Operator Lifecycle Manager](13-olm.md)
