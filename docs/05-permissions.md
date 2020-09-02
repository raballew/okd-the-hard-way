# Permissions

## Disable self-provisioning

Per default any authenticated user is enabled to create projects and provision
resources on their own. A first step to more control for administrators is by
disabling self-provisioning of projects.

```shell
[root@services ~]# oc adm policy remove-cluster-role-from-group self-provisioner system:authenticated:oauth
```

Next: [Nodes](06-nodes.md)
