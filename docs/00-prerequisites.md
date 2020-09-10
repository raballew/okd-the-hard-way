# Prerequisites

## Accounts

* [Red Hat Network Account](https://www.redhat.com/wapps/ugc/register.html)

## Bare Metal Server

This tutorials relies on the capabilities of a single bare metal server and
virtualization to run everything. This makes it easy to troubleshoot issues on
the one hand but increases the requirements for a suitable machine on the other
hand.

The following system specifications are recommended:

* 2 TB storage (use NVMe SSDs if possible) with more than 1.5 TB free at `/`
* 128 GB RAM
* 32 CPU cores
* 1 GBit/s network interface
* Internet access
* Virtualization capabilities
* Fedora 32 installed

You can easily find a machine with the requirements on one of your favorite
managed server or cloud providers.

If this setup does not fit into your budget or you are not able to find a
machine with this specifications you will still be able to perform some of the
labs. You could overcommit resources on the virtualization level, which might
cause instabilities. Kernel-based Virtual Machines (KVMs) are used in this lab.
KVM is an open source virtualization technology which converts your Linux
machine into a type-1 bare-metal hypervisor that allows you to run multiple
virtual machines (VMs) or guest VMs. The KVM hypervisor automatically
overcommits CPUs and memory. This means that more virtualized CPUs and memory
can be allocated to virtual machines than there are physical resources on the
system. This is possible because most processes do not access 100% of their
allocated resources all the time.

## Time

The total time needed will vary but without any previous knowledge you will
probably need a week or two to fully understand everything shown here.

Next: [Hypervisor](01-hypervisor.md)
