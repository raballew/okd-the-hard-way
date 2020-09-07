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
on UPI in an disconnected environment following best practices.

### Nodes

| # | OS               | RAM  | CPU  |  Disk  | Usage        |
| - | ---------------- | ---- | ---- | ------ | ------------ |
| 1 | Fedora           | 8 GB | 2    | 50 GB  | services     |
| 1 | Fedora Core OS   | 8 GB | 2    | 50 GB  | bootstrap    |
| 3 | Fedora Core OS   | 8 GB | 2    | 50 GB  | control      |
| 3 | Fedora Core OS   | 8 GB | 2    | 50 GB  | compute      |
| 3 | Fedora Core OS   | 8 GB | 2    | 50 GB  | infra        |

### Components

* [OKD
  4.5.0-0.okd-2020-09-04-180756](https://github.com/openshift/okd/releases/tag/4.5.0-0.okd-2020-09-04-180756)
  * [Kubernetes 1.18.3](https://github.com/kubernetes/kubernetes/releases)
  * [Fedora CoreOS
    32.20200629.3.0](https://getfedora.org/en/coreos?stream=stable)

## Labs

* [Prerequisites](docs/00-prerequisites.md)
* [Hypervisor](docs/01-hypervisor.md)
* [Services](docs/02-services.md)
* [Installation](docs/03-installation.md)
* [Authentication](docs/04-authentication.md)
* [Permissions](docs/05-permissions.md)
* [Nodes](docs/06-nodes.md)

Whenever things break or an unexpected issue occurs, please refer to the
[troubleshooting](docs/99-troubleshooting.md) section.

## Contributing

We encourage contributions back to the upstream project and are happy to accept
pull requests for anything from small documentation fixes to whole new
environments. Also check out our [contributing guide](.github/CONTRIBUTING.md).
To get started, please do not hesitate to submit a PR. We will happily guide you
through any needed changes.

## License

Licensed under MIT license ([LICENSE](LICENSE)).
