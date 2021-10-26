# Troubleshooting

## Shell

A command line is a text-based interface which can be used to input instructions
to a computer system. The Linux command line is provided by a program called the
shell. When a shell is used interactively, it displays a string when it is
waiting for a command from the user. This is called the shell prompt. When a
regular user starts a shell, the default prompt ends with a `$` character, as
shown below.

```bash
[user@host ~]$
```

The `$` character is replaced by a `#` character if the shell is running as the
superuser, root. The superuser shell prompt is shown below.

```bash
[root@host ~]#
```

`host` is the short hostname of the machine the shell is running on. This
tutorial will require you to run commands on two machines. One of them is the
hypervisor machine which is the machine where all virtual machines (VM) will be
installed. Shell prompts for the hypervisor can look like this:

```bash
# regular user
[okd@okd ~]$

 # superuser
[root@okd ~]#
```

The other machine is the services VM. Shell prompts for the services VM can look
like this:

```bash
# regular user
[okd@services ~]$

 # superuser
[root@services ~]#
```

## Persistent volume claims for filesystem stuck at pending

In some cases, persistent volume claims for the storage class `filesystem` are
stuck at pending state. This can be easily solved by forcing a restart of the
Ceph filesystem provisioner pods.

```bash
oc delete pod -l app=csi-cephfsplugin-provisioner --grace-period=0 --force
```
