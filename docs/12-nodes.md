# Nodes

## Machine Config Operator

OKD is an Operator focused platform. An Operator is a piece of software that
runs on the cluster. It implements the same concepts as a
[Controller](https://kubernetes.io/docs/concepts/) by comparing the current
state of the system with the desired state and driving it towards the later one.
This logic however is implemented for a specific application or more specific a
Custom Resource rather than a normal cluster resource itself.

Nodes are managed by the Machine Config Operator (MCO), which is an Operator
with infrastructure perspective. It manages the operations system (OS) of each
node. This could include updates to systemd, the kernel or cri-o, etc.

An OKD cluster usually runs different workloads. Each of them has different
requirements to the underlying infrastructure. A application might need a
realtime operation system, others need tweeks for a high disk troughput.

In this setup different workloads should be seperated from each other so that
OKD infrastructure components such as the Software Defined Network (SDN) do not
compete for compute resources with application workload. Infrastructure workload
such as monitoring, logging and metering should run on nodes labeled with
`node-role.kubernetes.io/infra: ""`. Applications are deployed to nodes with the
label `node-role.kubernetes.io/compute: ""`. Nodes with label
`node-role.kubernetes.io/master: ""` should only execute the control plane.
There are are many more usecases not covered by this lab such as dedicated build
nodes or staging environments which require even more fine tuning but the
concepts show here apply to all of them.

Create seperate a MachineConfigPool (MCP) for each usecase:

```shell
[root@services ~]# oc apply -f okd-the-hard-way/src/okd/nodes/
```

All created MCPs inherit their properties from the MachineConfigPool worker.
Keep in mind, a node can only be part of a single MCP.

Then relabel all nodes to match the node selectors specified in the resource
definitions:

```shell
[root@services ~]# oc label node infra-{0,1,2} node-role.kubernetes.io/infra=
[root@services ~]# oc label node infra-{0,1,2} node-role.kubernetes.io/worker-
[root@services ~]# oc label node compute-{0,1,2} node-role.kubernetes.io/compute=
[root@services ~]# oc label node compute-{0,1,2} node-role.kubernetes.io/worker-
```

After a few minutes verfiy that the MCO did its job:

```shell
[root@services ~]# oc get mcp

NAME      CONFIG                                              UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
compute   rendered-compute-3b3e9ab51476d07941001d9ad9e1be01   True      False      False      3              3                   3                     0                      5m29s
infra     rendered-infra-3b3e9ab51476d07941001d9ad9e1be01     True      False      False      3              3                   3                     0                      5m29s
master    rendered-master-0dce34b0a29683cc0ac37b5fc19ac9af    True      False      False      3              3                   3                     0                      145m
worker    rendered-worker-3b3e9ab51476d07941001d9ad9e1be01    True      False      False      0              0                   0                     0                      145m
```

All nodes should have the correct roles assigned to them:

```shell
[root@services ~]# oc get nodes

NAME        STATUS   ROLES           AGE    VERSION
compute-0   Ready    compute         138m   v1.18.3
compute-1   Ready    compute         138m   v1.18.3
compute-2   Ready    compute         138m   v1.18.3
control-0   Ready    master          148m   v1.18.3
control-1   Ready    master          148m   v1.18.3
control-2   Ready    master          148m   v1.18.3
infra-0     Ready    infra           138m   v1.18.3
infra-1     Ready    infra           138m   v1.18.3
infra-2     Ready    infra           138m   v1.18.3
```

## Migrate workload to dedicated nodes

Once the MCO finished configuring the nodes it is time to relocate workloads
running to their destination. For now this applies only to the Ingress
Controller. Scaling the Ingress Controller to 3 replicas ensures a high
availability setup.

```shell
[root@services ~]# oc patch ingresscontrollers.operator.openshift.io default -n openshift-ingress-operator -p '{"spec":{"nodePlacement":{"nodeSelector":{"matchLabels":{"node-role.kubernetes.io/infra":""}}}}}' --type=merge
[root@services ~]# oc patch ingresscontrollers.operator.openshift.io default -n openshift-ingress-operator --patch '{"spec":{"replicas": 3}}' --type=merge
```

## Reconfigure HAProxy

The Ingress Controller is running on the infra nodes now. Therefore the HAProxy
needs to point the `https_router` and `http_router` to the infra nodes as well.

```shell
[root@services ~]# \cp okd-the-hard-way/src/services/haproxy-final.cfg /etc/haproxy/haproxy.cfg
[root@services ~]# systemctl restart haproxy
```

Next: [Operator Lifecycle Manager](13-olm.md)
