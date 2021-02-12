# Permissions

## Disable self-provisioning

Per default any authenticated user is enabled to create projects and provision
resources on their own. In a multi-tenant usecase this could lead to problems
related to cluster capacity planning as an user might request a large amount of
resources so that other projects can not use this cluster anymore. A first step
to more control for administrators is by disabling self-provisioning of
projects.

```bash
[root@services ~]# oc apply -f okd-the-hard-way/src/okd/permissions/self-provisioning.yaml
```

## Project request template

```bash
[root@services ~]# oc apply -f okd-the-hard-way/src/okd/permissions/project-request-template.yaml
[root@services ~]# oc apply -f okd-the-hard-way/src/okd/permissions/project-cluster.yaml
```

Next: [Nodes](12-nodes.md)
