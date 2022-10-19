# OKD The Hard Way

This tutorial is an homage to Kelsey Hightowers approach of setting up
[Kubernetes](https://github.com/kelseyhightower/kubernetes-the-hard-way).

OKD The Hard Way also tries to take the very long way to ensure you understand
each task required to bootstrap an OKD cluster. For this purpose this tutorial
is not going to use a cloud provider to kick the tires on OKD. Therefore
Installer Provisioned Infrastructure (IPI) is not suitable for the purpose of
this workshop, so that the installation will be performed on User Provisioned
Infrastructure (UPI). In the end you should be able to explain why things were
setup the way they are and troubleshoot more advanced issues.

## Cluster Details

OKD The Hard Way guides you trough bootstrapping a highly available OKD cluster
on UPI in a disconnected environment following practices and settings used in
real world scenarios.

### Nodes

| # | OS               | RAM   | CPU  |  Disk           | Usage         |
| - | ---------------- | ----- | ---- | --------------- | ------------- |
| 1 | Fedora           | 8 GB  | 2    | 256 GB          | services      |
| 1 | Fedora Core OS   | 16 GB | 4    | 128 GB          | bootstrap     |
| 3 | Fedora Core OS   | 16 GB | 4    | 128 GB          | master        |
| 3 | Fedora Core OS   | 16 GB | 4    | 128 GB          | compute       |
| 3 | Fedora Core OS   | 16 GB | 4    | 128 GB          | infra         |
| 3 | Fedora Core OS   | 32 GB | 8    | 128 GB + 256 GB | storage       |

### Components

* [Fedora 36](https://getfedora.org/en/server/)
* [4.11.0-0.okd-2022-10-15-073651](https://github.com/openshift/okd/releases)
* [Rook Ceph 1.10.3](https://github.com/rook/rook)
* [MetalLB 0.13.7](https://github.com/metallb/metallb)

## Labs

This lab can be split into three parts. The first part will guide you through
all steps required to setup a new cluster.

* [Prerequisites](docs/00-prerequisites.md)
* [Hypervisor](docs/01-hypervisor.md)
* [Services](docs/02-services.md)
* [Installation](docs/03-installation.md)

Part two will then prepare the cluster for multi-tenant production workloads and
operations.

* [Authentication](docs/10-authentication.md)
* [Permissions](docs/11-permissions.md)
* [Nodes](docs/12-nodes.md)
* [Operator Lifecycle Manager](docs/13-olm.md)
* [Network](docs/14-network.md)
* [Storage](docs/15-storage.md)
* [Operations](docs/16-operations.md)

Everything mentioned in parts one and two is explained in detail but the
drawback is that all the steps need to be performed manually. In the event of a
disaster it will take quite some time to recover from the outage. Therefore the
third part leverages the previously gained knowledge to build a fully automated
process to spin up and maintain your cluster.

* [Deploy](docs/20-deploy.md)
* [Maintain](docs/21-maintain.md)
* [Usage](docs/22-usage.md)
* [Disaster Recovery](docs/23-disaster-recovery.md)

Whenever things break or an unexpected issue occurs, please refer to the
[troubleshooting](docs/99-troubleshooting.md) section. You can also create a new
[issue](https://github.com/raballew/okd-the-hard-way/issues/new/choose) if you
have the feeling that something is wrong or could be done better.

## Contributing

We encourage contributions back to the upstream project and are happy to accept
pull requests for anything from small documentation fixes to whole new
environments. Also check out our [contributing guide](.github/CONTRIBUTING.md).
To get started, please do not hesitate to submit a PR. We will happily guide you
through any needed changes.

## Code of Conduct

The Rust [code of conduct](https://www.rust-lang.org/conduct.html) is adhered by
the OKD The Hard Way project.

All contributors, community members, and visitors are expected to familiarize
themselves with the code of conduct and to follow these standards in all OKD The
Hard Way-affiliated environments, which includes but is not limited to
repositories, chats, and meetup events.

## License

Licensed under MIT license ([LICENSE.md](LICENSE.md)).
