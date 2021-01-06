# Load Balancer

## HAProxy server

An external load balancer as a passthrough is the most lightweight integration
possible between OKD and an external load balancer. It is commonly used when
traffic hitting the cluster first goes through a public network. The load
balancer passes any request trough to OKD's routing layer. The OKD routers then
handle things like SSL termination and making routing decisions.

As shown in [haproxy.cfg](../src/services/haproxy.cfg) there are multiple load
balancers defined. Most notably load balancer for the machines that run the
ingress router pods that balances ports 443 and 80. Both the ports must be
accessible to both clients external to the cluster and nodes within the cluster.

As well as a load balancer for the control plane and bootstrap machines that
targets port 6443 and 22623. Port 6443 must be accessible to both clients
external to the cluster and nodes within the cluster, and port 22623 must be
accessible to nodes within the cluster.

```shell
[root@services ~]# \cp okd-the-hard-way/src/services/haproxy.cfg /etc/haproxy/haproxy.cfg
[root@services ~]# semanage port -a 6443 -t http_port_t -p tcp
[root@services ~]# semanage port -a 22623 -t http_port_t -p tcp
[root@services ~]# systemctl restart haproxy
```

Next: [Installation](04-installation.md)
