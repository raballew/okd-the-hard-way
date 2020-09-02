# Authentication

By default, only a kubeadmin user exists on your cluster. To specify an identity
provider, you must create a custom resource (CR) that describes that identity
provider and add it to the cluster. HTPasswd is an easy way to setup
authentication without relying external systems. To use the HTPasswd identity
provider, a secret that contains the HTPasswd user file must be defined.

```shell
[root@services ~]# htpasswd -c -B -b users.htpasswd root okd
[root@services ~]# oc create secret generic htpasswd-secret --from-file=htpasswd=/root/users.htpasswd -n openshift-config
[root@services ~]# oc apply -f okd-the-hard-way/src/okd/authentication/oauth-cluster.yaml
[root@services ~]# oc adm policy add-cluster-role-to-user cluster-admin root
```

Login as `root` user:

```shell
[root@services ~]# oc login -u root -p okd https://api.okd.example.com:6443
```

> If the authentication cluster operator is not available this command will fail
> with `error: couldn't get
> https://api.okd.example.com:6443/.well-known/oauth-authorization-server:
> unexpected response status 404`

Next: [Permissions](05-permissions.md)
