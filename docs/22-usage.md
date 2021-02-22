# Usage

## Debug nodes

nodes=$(oc get nodes -o name)

read -r -d '' commands <<- EOM || :
hostname
sudo nmcli con s
EOM

for node in $nodes; do
    oc debug --quiet=true $node -- chroot /host /bin/bash -c 'tmp=$(mktemp) && echo "$0" > $tmp && . $tmp' "$(echo "$commands")"
done

## Onboard tenant
