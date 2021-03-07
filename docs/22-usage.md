# Usage

> This section is currently under construction and might not be finished or
> contain unverified solutions.

## Debug nodes

### Container

Usually OKD offers the possibility to launch a command shell to debug a running
application. Since a pod that is failing may not be started and not accessible
to `rsh` or `exec`, the `debug` command makes it easy to create a carbon copy of
that setup. This can also be applied to nodes by running a debug pod.

The debug pod is deleted when the the remote command completes or the user
interrupts the shell.

To run a script in an automated fashion on all nodes in the cluster without
using SSH you could run:

```bash
[root@services ~]# nodes=$(oc get nodes -o name)
[root@services ~]# read -r -d '' commands <<- EOM || :
hostname
sudo nmcli con s
EOM
[root@services ~]# for node in $nodes; do oc debug --quiet=true $node -- chroot /host /bin/bash -c 'tmp=$(mktemp) && echo "$0" > $tmp && . $tmp' "$(echo "$commands")" done
```

### SSH

Using SSH is not recommended to access a node and should be used with precaution
and only if necessary. Usually this is done when nodes do not properly boot and
running `oc debug node/...` becomes impossible as the pod is unschedulable when
the node is not ready.

```bash
[root@services ~]# ssh core@$NODE -i ~/.ssh/fcos
```

## Onboard tenant
