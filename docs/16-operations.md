# Operations

## Multi-tenant workloads

The cluster is now set up in a way that it can be used to deploy multi-tenant
workloads. This is achieved by enforcing a strict separation of tenant
namespaces by defining the [project request
template](../src/11-permissions/project-request-template.yaml). Whenever a
project is created with `oc new project` a very limited amount of resources is
made available to the user and interaction with other namespaces is restricted
by default. Think of it as some kind of free tier that users can play around
with, similar to what you get on most hyperscalers. Once their requirements get
more serious, they will need to reach out to a cluster administrator and ask
them to increase the quota. This can be done through a ticket system, a GitOps
approach where users raise pull requests to change some of the restrictions
applied to their namespaces which then get review by an administrator or any
other workflow that fits your use case. Those approaches of onboarding new
tenants might sound counterintuitive as application developers want to reduce
dependencies to other parties as much as possible to improve their performance.
The challenge here is, that each project on a multi-tenant cluster is sharing
resources with other projects and you need an independent third party that is
responsible for managing the the cluster infrastructure including capacity
management, incident responses or updates. As this leads to a bottleneck at the
cluster operations team if there a many requests a proper way of handling the
majority of the requests automatically should be implemented.

## Smoke test

Since the cluster is now configured, lets make sure everything works as
expected.

### Project

First create a new project where to run the smoke test:

```bash
[okd@services ~]$ oc new-project smoke-test
```

Then verify that the default resources have been created.

```bash
[okd@services ~]$ oc get quota -o name -n smoke-test

resourcequota/default

[okd@services ~]$ oc get limitrange -o name -n smoke-test

limitrange/default

[okd@services ~]$ oc get networkpolicies -o name -n smoke-test

networkpolicy.networking.k8s.io/allow-from-openshift-ingress
networkpolicy.networking.k8s.io/allow-from-openshift-monitoring
networkpolicy.networking.k8s.io/allow-same-namespace
networkpolicy.networking.k8s.io/deny-all

[okd@services ~]$ oc get rolebinding -o name -n smoke-test

rolebinding.rbac.authorization.k8s.io/admin
rolebinding.rbac.authorization.k8s.io/system:deployers
rolebinding.rbac.authorization.k8s.io/system:image-builders
rolebinding.rbac.authorization.k8s.io/system:image-pullers
```

### Deployment

Create a deployment for the web server.

```bash
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/16-operations/smoke-test/deployment.yaml
```

Verify that the deployment is running.

```bash
[okd@services ~]$ oc get deployment -n smoke-test

NAME   READY   UP-TO-DATE   AVAILABLE   AGE
ubi8   1/1     1            1           105s
```

### Service

Create several services for the deployment from the previous step.

```bash
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/16-operations/smoke-test/service.yaml

Error from server (Forbidden): error when creating "~/okd-the-hard-way/src/16-operations/smoke-test/service.yaml": services "ubi8" is forbidden: exceeded quota: default, requested: services.loadbalancers=1,services.nodeports=1, used: services.loadbalancers=0,services.nodeports=0, limited: services.loadbalancers=0,services.nodeports=0
```

The error above occurred due to the fact, that the quota in the namespace limits
the number of services of type load balancer or node port to zero. Therefore
lets increase the quota and reapply the manifest.

```bash
[okd@services ~]$ oc patch quota default -n smoke-test -p '{"spec":{"hard":{"services.loadbalancers": 1, "services.nodeports": 1}}}' --type=merge
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/16-operations/smoke-test/service.yaml
```

Verify that the services have been created.

```bash
[okd@services ~]$ oc get service -n smoke-test

NAME   TYPE           CLUSTER-IP       EXTERNAL-IP       PORT(S)        AGE
ubi8   LoadBalancer   172.30.214.191   192.168.200.101   80:32426/TCP   3s
```

### Storage

Create several persistent volume claims and an object bucket claim.

```bash
[okd@services ~]$ oc apply -f ~/okd-the-hard-way/src/16-operations/smoke-test/storage.yaml
```

Then verify that all claims are in status `Bound`.

```bash
[okd@services ~]$ oc get persistentvolumeclaim -n smoke-test

NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
block        Bound    pvc-9ff08869-64cf-4715-b430-1ddc3acdf09e   1Gi        RWO            block          3m40s
filesystem   Bound    pvc-024652ad-3d71-4eb8-9994-10314ce124a6   1Gi        RWO            filesystem     4m2s

[okd@services ~]$ oc get objectbucketclaim -n smoke-test -o custom-columns=NAME:.metadata.name,STATUS:.status.phase

NAME     STATUS
object   Bound
```

### Clean up

Remove all resources used by the smoke test.

```bash
[okd@services ~]$ oc delete project smoke-test
```

## Service-Level Agreements

An service-level agreement (SLA) is an essential part that is needed before a
cluster should be used for production workloads. It clearly defines the level of
service that a tenant can expect from the operator of the platform by laying out
measurable metrics and consequences or penalties if a metric does not stay in
the defined boundaries of the SLA. While there are quite a lot of resources
available on how to define a metric properly, information on how to handle the
different scopes is rare.

Usually OKD is managed by an operations team that takes care of all
infrastructure and platform related activities including capacity planning,
rollout of updates or onboarding of new tenants. Whereas tenants just want to
run their workload and the true cost of the system might and should be not
visible for them. As a result operators must validate the feasibility of
requests of tenants with regard to potential conflicts with other tenants. This
is a huge task and requires some practice to perform well and usually leads to
dissatisfaction in the early stages.

While most metrics monitor technical requirements they forget about the
customer-centric approach with a strong separation of concerns, that is needed
to be successful. Therefore including scores of surveys send to the tenants or
something similar greatly increases the visibility of potential issues with the
overall quality of the service provided by operations. This could be simple
survey that gets sends to your tenants frequently:

```txt
Are you happy with the service provided?

- [] Yes
- [] No

What would you like to see improved?
```

If the project request template has been used to onboard new tenants, a list of
contact persons can be easily gathered by running:

```bash
[okd@services ~]$ oc get project -o=custom-columns=NAME:.metadata.name,CONTACT:.metadata.annotations.contact
```

Default namespaces managed by OKD and those that have been created by the
operations team during installation usually do not have contact set.

## Alerting

Alerting is an essential feature required to proactively handle errors and
comply with the SLAs. OKD already comes with a huge set of events that are
triggered when certain conditions are met. Those events are defined as
Prometheus rules. Prometheus is a software that records real-time metrics in a
time series database built using a HTTP pull model, with flexible queries and
real-time alerting.

A list of available Prometheus rules can be shown by running the following:

```bash
[okd@services ~]$ oc get prometheusrule -A
```

Even though OKD offers the possibility to configure events based on metrics that
are collected from user workload, you might want to add your own set of events
to OKD on a cluster level.

This can be done by simply adding your own Prometheus rule to an namespace that
contains `openshift` in its name. Whilst this method is not recommended, it is
the only way to configure it at the moment without rolling out your own
monitoring.

Configuring receivers for alerts must be done in the secret `alertmanager-main`
in the namespace `openshift-monitoring`. An example can be found at
[alertmanager-config.yaml](../src/16-operations/alerting/alertmanager-config.yaml).
The actual configuration will largely depend on the backend used.

Next: [Deploy](20-deploy.md)
