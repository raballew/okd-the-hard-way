# Network

## Dynamic assignment of IP addresses for services

Kubernetes does not offer an implementation of network load balancers (services
of type load balancer) for bare metal clusters. The implementations of network
load balancer that Kubernetes does ship with are all glue code that calls out to
various public cloud platforms. If you’re not running on a supported platform,
load balancer services will remain in the pending state indefinitely when
created.

Bare metal cluster operators are left with two lesser tools to bring user
traffic into their clusters, node ports and external IP services. Both of these
options have significant downsides for production use, which makes bare metal
clusters second class citizens in the Kubernetes ecosystem.

According to the design of the service resource, you should not choose your own
port number if that choice might collide with someone else's choice. That is an
isolation failure. In order to allow you to choose a port number for your
services, we must ensure that no two services can collide. Kubernetes does that
by allocating each service its own IP address. So node port services are not
recommended and external IP services can only be created by cluster admins.

OKD also does not solve this issue out of the box. MetalLB, an operator, aims to
redress this imbalance by offering a network load balancer implementation that
integrates with standard network equipment, so that external services on bare
metal clusters also just work as much as possible.

## Network isolation for multitenant clusters



Next: [Operations](16-operations.md)
