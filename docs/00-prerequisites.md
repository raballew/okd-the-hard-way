# Prerequisites

## Accounts

* [Red Hat Network Account](https://www.redhat.com/wapps/ugc/register.html)
* [Docker Hub Account](https://hub.docker.com/signup) with no rate limit

## Bare Metal Server

This tutorials relies on the capabilities of a single bare metal server and
virtualization. This makes it easy to troubleshoot issues on the one hand but
increases the requirements for a suitable machine on the other hand.

The following system specifications are recommended for the hypervisor node:

* 3 TB storage (use NVMe or SSD) in `/home/`
* 256 GB RAM
* 64 CPU cores
* 1 GBit/s network interface
* Internet access
* Virtualization capabilities
* Fedora 33 installed

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

## Time

The total time needed will vary but without any previous knowledge you will
probably need a week or two to complete and understand the lab.

Next: [Hypervisor](01-hypervisor.md)
