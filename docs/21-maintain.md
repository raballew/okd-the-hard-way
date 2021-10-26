# Maintain

> This section is currently under construction and might not be finished or
> contain unverified solutions.

## Delete Node

## Add Node

## New Cluster Version

For clusters with internet accessibility, over-the-air updates through an OKD
update service are provided as a hosted service located behind public APIs. An
update specifoes the intended state of the managed cluster components including
FCOS. To allow the update service to provide only compatible updates, a release
verification pipeline drives automation. Each release artifact is verified for
compatibility with supported cloud platforms and system architectures, as well
as other component packages. After the pipeline confirms the suitability of a
release, the update services notifies you that it is available. In disconnected
environments adminstrators can run this process manually by mirroring the
required images and trigger the update process.

The problem is, that even though updates are tested for a whole bunch of
different environments, it is not possible to ensure compatibility for each
variation. In the past this resulted in errornous updates and sometimes required
manual fixing as there is no supported way to rollback the change. The reason
for this is that the update process is not deterministic. Thus one can not be
sure that an update runs smoothly even if tested in advance on a cluster trying
to mirror the target as much as possible. While this might be suitable for
administrators managing only a handful clusters, this is not acceptable for
larger deployments or production environments. A classic blue/green deploy cycle
applied to clusters can mitigate this issue.

A typical setup includes the last three clusters running allsupported version by
the operations team. Kubernetes releases a new minor version about every three
months in which, in addition to security vulnerabilities, a large number of new
features become available. Older releases of Kubernetes only receive support for
about nine months and are then officially no longer supported. OKD follows the
Kubernetes release cycle with a delay of one minor version. This means that
migrations in a blue/green deploy cycle must occur within this timeframe or
users risk to run on unsupported and even vulnerable versions of OKD. This puts
additonal effort on application teams. Especially unexperienced teams struggle
with this approach as they tend to use the wrong tools or fail to elimiate toil.
Also operating expenditures (OPEX) and capital expenditures (CAPEX) are higher
using a blue/green approach due to the constant management overhead of having
multiple cluster as well as the additional hardware required to run the
clusters.

In the end, the decision if migrations or updates are suitable largely depends
on wheter a potential lasting downtime and manual troubleshooting is tolerable
or not.

Next: [Usage](22-usage.md)
