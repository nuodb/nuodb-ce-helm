#!/bin/bash

# run as root
if [ "$(id -u)" -ne 0 ]; then
    sudo THEUSER=${USER} $0
    exit $?
fi

exec > >(tee /var/log/thp-tuned.log) 2>&1
set -x

#
# Setup tuned profile for NuoDB
#


mkdir /etc/tuned/nuodb
cat > /etc/tuned/nuodb/tuned.conf <<'EOF'
[main]
summary=Optimize for NuoDB Distributed RDBMS
include=openshift-node

[vm]
transparent_hugepages=never
EOF
chmod 0644 /etc/tuned/nuodb/tuned.conf
tuned-adm profile nuodb
systemctl restart tuned

cat /sys/kernel/mm/transparent_hugepage/enabled
