# nuodb-ce-helm

A NuoDB CE Helm Chart for OpenShift with support for both ephemeral and
persistent storage.
(See DB-24621)


# https://blog.openshift.com/getting-started-helm-openshift/
# https://blog.openshift.com/from-templates-to-openshift-helm-charts/
# https://www.mirantis.com/blog/install-kubernetes-apps-helm/


Node Labeling

Before running the NuoDB Community Edition (CE) persistent storage template,
you must first label the nodes you want to run NuoDB pods.

The first label, "nuodb.com/zone", constrains on which nodes NuoDB pods are
permitted to run. For example:

  oc label node <node-name> nuodb.com/zone=east

Note: the label value, in this example "east", can be any value.

Next, label one of these nodes as your storage node, where you provide persistent
storage for your database. Ensure there is sufficient disk space. To create this label:

  oc label node <node-name> nuodb.com/node-type=storage

Storage Classes and Volumes

NuoDB uses persistent storage for the Admin Service pods and the storage managers. For each of these you need to define a storage class.

The storage class for the Admin Service pod is configurable by the template parameters.
We've tested with GlusterFS ("glusterfs-storage") and OpenEBS ("openebs-standard").
Enter the storage class name you wish to provision for the Admin Service pods.

The storage class for the storage manager is predefined within the `local-disk-class.yaml`  file, along with the volume used by the storage manager. To create these:

  oc create -f local-disk-class.yaml
	


#!/bin/bash

# Deploy NuoDB CE domain using K8s Helm Chart

# On host system:
vboxmanage controlvm gatestux42 poweroff
vboxmanage snapshot gatestux42 restore "Base 5"
vboxmanage startvm gatestux42 --type headless
sleep 20
sshpass -p rootP@ss ssh root@192.168.12.201

sleep 180

PROJECT=nuodb
NODE=localhost.localdomain
TESTDIR=$HOME/nuodb/nuodb_ocp_test_okd
CONTAINER=nuodb/nuodb-ce:3.3.0
#CONTAINER="registry.connect.redhat.com/nuodb/nuodb-ce:latest"
export DB_NAME=test
export DB_USER=dba
export DB_PASSWORD=secret
export TILLER_NAMESPACE=tiller
export HELM_VERSION=v2.12.0

mkdir -p $TESTDIR
cd $TESTDIR

# assume nuodb-ce-helm-persistent is on the VBox share.
# On host system:
#   cd $HOME/gatestux42_share
#   git clone git@git:user/tgates/nuodb-ce-helm-persistent
cp -r /media/sf_gatestux42_share/nuodb-ce-helm-persistent $TESTDIR/

chmod +x $TESTDIR/nuodb-ce-helm-persistent/nuodb-prereq/thp-tuned.sh
$TESTDIR/nuodb-ce-helm-persistent/nuodb-prereq/thp-tuned.sh

# Prefetch Docker image to make startup faster
docker pull ${CONTAINER}

#sleep 20

oc login -u system:admin
oc label node ${NODE} nuodb.com/node-type=storage
oc label node ${NODE} nuodb.com/zone=east --overwrite=true

OCPVERSION=$(oc version | gawk '$1 ~ /^openshift/ { print $NF; }')
echo $OCPVERSION

oc new-project tiller
# Assume helm is already downloaded and mounted on the VBox share
# Example on the host system:
#   export HELM_VERSION=v2.12.0
#   cd $HOME/gatestux42_share/
#   curl -s https://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar xz
cp -r /media/sf_gatestux42_share/linux-amd64 $TESTDIR/
cp ${TESTDIR}/linux-amd64/helm /usr/local/bin/helm
helm init --client-only

oc adm policy add-cluster-role-to-user cluster-admin -z default --namespace kube-system
sleep 10
oc process -f https://github.com/openshift/origin/raw/master/examples/helm/tiller-template.yaml -p TILLER_NAMESPACE="${TILLER_NAMESPACE}" -p HELM_VERSION=${HELM_VERSION} | oc create -f -
sleep 10
oc rollout status deployment tiller
helm version


oc new-project ${PROJECT}
# Was not able to get the mysql pod to work until I added the following line.
oc adm policy add-scc-to-user anyuid -n nuodb -z default
oc policy add-role-to-user edit "system:serviceaccount:${TILLER_NAMESPACE}:tiller"
helm repo update


helm install --debug ${TESTDIR}/nuodb-ce-helm-persistent

sleep 60

# Do manually, one at a time.
#oc exec -it nuodb-insights -c insights -- nuoca check insights
#
#oc exec -it nuodb-insights -c insights -- nuoca enable insights
#
#oc exec -it nuodb-insights -c insights -- nuoca check insights




