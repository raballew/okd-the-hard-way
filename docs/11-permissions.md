# Permissions

## Disable self-provisioning

Per default any authenticated user is enabled to create projects and provision
resources on their own. In a multi-tenant usecase this could lead to problems
related to cluster capacity planning as an user might request a large amount of
resources so that other projects can not use this cluster anymore. A first step
to more control for administrators is by disabling self-provisioning of
projects.

```bash
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/11-permissions/self-provisioning.yaml
```

## Project request template

As a cluster administrator, you can modify the default project template so that
new projects are created using your custom requirements. This includes default
values for quotas, rolebindings and limit ranges. Also multitenant network
isolation is configured, so that only pods from within the same namespace can
talk to each other. This is done by using network policies.

Keep in mind that network policy does not apply to the host network namespace.
pods with host networking enabled are unaffected by network policy rules, so
platform operators should carefully choose which pods are able to use host
networking as this is introduces a potential weak spot for attackers.

```bash
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/11-permissions/project-request-template.yaml
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/11-permissions/project-cluster.yaml
```

Next: [Nodes](12-nodes.md)
