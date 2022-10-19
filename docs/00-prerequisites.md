# Prerequisites

## Accounts

* [Red Hat Network Account](https://www.redhat.com)

## Bare Metal Server

This tutorial relies on the capabilities of a single bare metal server and
virtualization. This makes it easy to troubleshoot issues on the one hand but
increases the requirements for a suitable machine on the other hand.

The following system specifications are recommended for the hypervisor node if
you plan to run some workload beyond the scope of this tutorial:

* 3 TB storage (use NVMe or SSD) in `/home/`
* 256 GB RAM
* 64 CPU cores
* 1 GBit/s network interface
* Internet access
* Virtualization capabilities
* Fedora 36 installed
* x86_64 system architecture

If this setup does not fit into your budget or if you are not able to find a
machine with this specifications Kernel-based Virtual Machines (KVMs) are used
in this lab and might solve this problem. KVM is an open source virtualization
technology which converts your Linux machine into a type-1 bare-metal hypervisor
that allows you to run multiple virtual machines (VMs) or guest VMs. The KVM
hypervisor automatically overcommits CPUs and memory. This means that more
virtualized CPUs and memory can be allocated to virtual machines than there are
physical resources on the system. This is possible because most processes do not
access all of their allocated resources all the time. Just make sure that your
system never really requests more resources than actually physically available.

## Skills

This lab focuses on the infrastructure related parts of provisioning a cluster.
Even though you can perform the steps mentioned here with little to no knowledge
about networking, Linux or Kubernetes this approach is not recommend. Before
starting, make yourself familiar with the following:

* [Kubernetes concepts](https://kubernetes.io/docs/concepts/)
* Linux
  * Networking
    * Routing
    * Switching
    * Network services
  * [Shell usage](99-troubleshooting.md#shell)
* Containers
* Virtual machines

Whenever you think it is unclear why or how a step in the lab is performed,
[create a new
issue](https://github.com/raballew/okd-the-hard-way/issues/new/choose)
explaining where you have trouble so that the content necessary to fill the gap
can be added.

## Time

The total time needed will vary but without any previous knowledge and if you
can resist to simply copy-paste the commands without thinking, you will probably
need a week to complete and understand the lab.

Next: [Hypervisor](01-hypervisor.md)
