# Operations

## Service-Level Agreements

An service-level agreement (SLA) is an essential part that is needed before a
cluster should be used for production workloads. It clearly defines the level of
service that a tenant can expect from the operator of the platform by laying out
measurable metrics and concequences or penalties if a metric does not stay in
the defined boundaries of the SLA. While there are quite a lot of resources
available on how to define a metric properly, information on how to handle the
different scopes is rare.

Usually OKD is managed by an operations team that takes care of all
infrastructure and platform related activities including capacity planning,
rollout of updates or onboarding of new tenants. Whereas tenants just want to
run their workload and the true cost of the system might and should be not
visible for them. As a result operators must validate the feasibility of
requests of tenants with regard to potential conflicts with other tenants. This
is a huge task and requires some practice to perform well and usally leads to
disatisfaction in the early stages.

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
[root@services ~]# oc get project -o=custom-columns=NAME:.metadata.name,CONTACT:.metadata.annotations.contact
```

Default namespaces managed by OKD and those that have been created by the
operations team during intallation usually do not have contact set.

## Alerting

Alerting is an essential feature required to proactively handle errors and
comply with the SLAs. OKD already comes with a huge set of events that are
triggered when certain conditions are met. Those events are defined as
Prometheus rules. Prometheus is a software that records real-time metrics in a
time series database built using a HTTP pull model, with flexible queries and
real-time alerting.

A list of available Prometheus rules can be shown by running the following:

```bash
[root@services ~]# oc get prometheusrule -A
```

Even though OKD offers the possibity to configure events based on metrics that
are collected from user workload, you might want to add your own set of events
to OKD on a cluster level.

This can be done by simply adding your own Prometheus rule to an namespace that
contains `openshift` in its name. Whilst this method is not recommended, it is
the only way to confiure it at the moment without rolling out your own
monitoring.

Configuring receivers for alerts must be done in the secret `alertmanager-main`
in the namespace `openshift-monitoring`. An example can be found at
[alertmanager-config.yaml](../src/16-operations/alerting/alertmanager-config.yaml).
The actual configuration will largely depend on the backend used.

Next: [Deploy](20-deploy.md)
