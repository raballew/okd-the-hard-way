# Troubleshooting

## Persistent volume claims for filesystem stuck at pending

In some cases, persistent volume claims for the storage class `filesystem` are
stuck at pending. This can be easily solved by forcing a restart of the Ceph
filesystem provisioner pods.

```bash
oc delete pod -l app=csi-cephfsplugin-provisioner --grace-period=0 --force
```
