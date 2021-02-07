# Authentication

By default, only a kubeadmin user exists on your cluster. To specify an identity
provider, you must create a custom resource (CR) that describes that identity
provider and add it to the cluster. HTPasswd is an easy way to setup
authentication without relying external systems, it can serve as a fallback
solution in case that the connection to other identity providers is broken. To
use the HTPasswd identity provider, a secret that contains the HTPasswd user
file must be defined.

```shell
[root@services ~]# htpasswd -c -B -b users.htpasswd fallback-admin okd
[root@services ~]# oc create secret generic htpasswd-secret --from-file=htpasswd=/root/users.htpasswd -n openshift-config
[root@services ~]# oc apply -f okd-the-hard-way/src/okd/authentication/oauth-cluster.yaml
[root@services ~]# oc adm policy add-cluster-role-to-user cluster-admin fallback-admin
```

Login as `fallback-admin` user:

```shell
[root@services ~]# oc login -u fallback-admin -p okd https://api.okd.example.com:6443
```

Next: [Permissions](11-permissions.md)
