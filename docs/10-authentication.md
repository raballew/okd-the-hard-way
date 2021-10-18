# Authentication

## PKI

Some platform components, such as the web console, use Routes for communication
and must trust other components' certificates to interact with them. If you are
using a custom public key infrastructure (PKI), you must configure it so its
privately signed CA certificates are recognized across the cluster.

```bash
[okd@services ~]# mkdir -p ~/okd
[okd@services ~]# openssl genrsa -out ~/okd/apps.$SUB_DOMAIN.$BASE_DOMAIN.key 4096
[okd@services ~]# openssl req -new -sha256 \
    -key ~/okd/apps.$SUB_DOMAIN.$BASE_DOMAIN.key \
    -subj "/CN=*.apps.$SUB_DOMAIN.$BASE_DOMAIN" \
    -addext "subjectAltName=DNS:*.apps.$SUB_DOMAIN.$BASE_DOMAIN" \
    -out ~/okd/apps.$SUB_DOMAIN.$BASE_DOMAIN.csr
[okd@services ~]# openssl x509 -req \
    -in ~/okd/apps.$SUB_DOMAIN.$BASE_DOMAIN.csr \
    -CA ~/ca/ca.crt \
    -CAkey ~/ca/ca.key \
    -CAcreateserial \
    -out ~/okd/apps.$SUB_DOMAIN.$BASE_DOMAIN.crt \
    -days 730 \
    -extfile <(printf "subjectAltName=DNS:*.apps.$SUB_DOMAIN.$BASE_DOMAIN") \
    -sha256
[okd@services ~]# oc patch proxy cluster -p '{"spec":{"trustedCA":{"name":"user-ca-bundle"}}}' --type=merge
[okd@services ~]# oc create secret tls user-ca \
    --cert=$HOME/okd/apps.$SUB_DOMAIN.$BASE_DOMAIN.crt \
    --key=$HOME/okd/apps.$SUB_DOMAIN.$BASE_DOMAIN.key \
    -n openshift-ingress
[okd@services ~]# oc patch ingresscontroller.operator default \
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

```bash
[okd@services ~]# USER_PASSWORD=$(openssl rand -hex 64)
[okd@services ~]# echo $USER_PASSWORD > ~/okd/fallback-admin-password
[okd@services ~]# htpasswd -c -B -b ~/okd/users.htpasswd fallback-admin $USER_PASSWORD
[okd@services ~]# oc create secret generic htpasswd-secret --from-file=htpasswd=$HOME/okd/users.htpasswd -n openshift-config
[okd@services ~]# oc apply -f ~/okd-the-hard-way/src/10-authentication/oauth-cluster.yaml
[okd@services ~]# oc adm policy add-cluster-role-to-user cluster-admin fallback-admin
```

Login as `fallback-admin` user:

```bash
[okd@services ~]# oc login -u fallback-admin -p $(cat ~/okd/fallback-admin-password) https://api.$SUB_DOMAIN.$BASE_DOMAIN:6443
```

Next: [Permissions](11-permissions.md)
