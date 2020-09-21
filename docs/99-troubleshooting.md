# Troubleshooting

## MachineConfigPool stays in updating or degraded state

Whenever the MachineConfiguration changes, those adjustments need to be roled
out to the corresponding nodes. During this process the node is marked as
unschedulable and then gets drained. Sometimes a resource cannot be evicted from
a node because this might violate the resources disruption budget. In this case
the node is stuck in a unschedulable state. Resolving this issue involves
manually draining and rejoining the node to the cluster.

```shell
[root@services ~]# oc adm drain <node> --force --ignore-daemonsets
[root@services ~]# oc delete node <node>
[root@hypervisor ~]# virsh reboot <node>
```

After several minutes the node should appear again in the cluster:

```shell
[root@services ~]# watch oc get nodes
```

Also make sure that the cluster operator `machine-config` is up and running:

```shell
[root@services ~]# oc get clusteroperator machine-config -o yaml
```

Check for any error messages there.

## Authentication cluster operator stuck at progressing

This version of OKD often fails to deploy the OAuth server with the
`authentication` cluster operator properly. This results in other cluster
operators to stay in progressing or degraded state. To check if your cluster is
affected by this, view the status of the authentication cluster operator
resource and look for a message and reason similar to the one shown below.

```shell
[root@services ~]# oc get clusteroperator authentication -o yaml

...
message: 'Progressing: got ''404 Not Found'' status while trying to GET the OAuth
  well-known https://192.168.200.31:6443/.well-known/oauth-authorization-server
  endpoint data'
reason: _WellKnownNotReady
...
```

As of now there is no solution to this issue other then reinstalling everything
from scratch and hoping for the best.
