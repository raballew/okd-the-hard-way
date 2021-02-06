# Permissions

## Disable self-provisioning

Per default any authenticated user is enabled to create projects and provision
resources on their own. In a multi-tenant usecase this could lead to problems
related to cluster capacity planning as an user might request a large amount of
resources so that other projects can not use this cluster anymore. A first step
to more control for administrators is by disabling self-provisioning of
projects.

```shell
[root@services ~]# oc adm policy remove-cluster-role-from-group self-provisioner system:authenticated:oauth
```

## Project request template

## Default node selector

Next: [Nodes](12-nodes.md)
