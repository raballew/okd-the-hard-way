# Troubleshooting

## Authentication cluster operator stuck at progressing

This version of OKD often fails to deploy the OAuth server with the
`authentication` cluster operator properly. This results in other cluster
operators to stay in progressing or degraded state. To check if your cluster is
affected by this, view the status of the authentication cluster operator
resource and look for a message and reason similar to the one shown below.

```bash
[root@services ~]# oc get clusteroperator authentication -o yaml

...
message: 'Progressing: got ''404 Not Found'' status while trying to GET the OAuth
  well-known https://192.168.200.31:6443/.well-known/oauth-authorization-server
  endpoint data'
reason: _WellKnownNotReady
...
```

As of now there is no solution to this issue other then reinstalling everything
from scratch and hoping for the best.
