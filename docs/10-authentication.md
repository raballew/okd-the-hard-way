# Authentication

## PKI

Some platform components, such as the web console, use Routes for communication
and must trust other components' certificates to interact with them. If you are
using a custom public key infrastructure (PKI), you must configure it so its
privately signed CA certificates are recognized across the cluster.

```shell
[root@services ~]# openssl genrsa -out /okd/apps.okd.example.com.key 4096
[root@services ~]# openssl req -new -sha256 \
  -key /okd/apps.okd.example.com.key \
  -subj "/CN=*.apps.okd.example.com" \
  -addext "subjectAltName=DNS:*.apps.okd.example.com" \
  -out /okd/apps.okd.example.com.csr
[root@services ~]# openssl x509 -req \
  -in /okd/apps.okd.example.com.csr \
  -CA /okd/ca.crt \
  -CAkey /okd/ca.key \
  -CAcreateserial \
  -out /okd/apps.okd.example.com.crt \
  -days 730 \
  -extfile <(printf "subjectAltName=DNS:*.apps.okd.example.com") \
  -sha256
```

```shell
[root@services ~]# oc patch proxy cluster -p '{"spec":{"trustedCA":{"name":"user-ca-bundle"}}}' --type=merge
[root@services ~]# oc create secret tls user-ca \
  --cert=/okd/apps.okd.example.com.crt \
  --key=/okd/apps.okd.example.com.key \
  -n openshift-ingress
[root@services ~]# oc patch ingresscontroller.operator default \
  --type=merge -p \
  '{"spec":{"defaultCertificate": {"name": "user-ca"}}}' \
  -n openshift-ingress-operator
```

## Fallback admin

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
