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

Login as `fallback-admin` user once the `authentication` cluster operator
stopped progressing:

```bash
[okd@services ~]# oc login -u fallback-admin -p $(cat ~/okd/fallback-admin-password) https://api.$SUB_DOMAIN.$BASE_DOMAIN:6443
```

> Use this command in further sections to login in case the token expired and
> you are asked to relogin.

## Remove kubeadmin user

> If you follow this procedure before another user is a cluster-admin, then OKD
> must be reinstalled. It is not possible to undo this command.

The kubeadmin is the user we’re getting upon finishing installing the cluster
initially. This user is cluster-admin (and statically configured on the
platform) by definition because it’s also the first (& single) user we have once
the cluster is installed properly. A new cluster admin account should be created
as defined in the [previous section](#fallback-admin) and the kubeadmin account
should be removed.

```bash
[okd@services ~]# oc delete secrets kubeadmin -n kube-system
```

Other than the kubeadmin user, during installation, we also get the kubeconfig
file. It contains an X.509 client certificate with no expiration date to our
cluster. This file is dedicated to emergencies, unlike the kubeadmin you can’t
delete it from the platform itself, and it could be useful for recovery
purposes. It is best practice to save it in a dedicated vault with very limited
access to cluster-admins only, auditing & detecting any access to it.

Next: [Permissions](11-permissions.md)
