#!/bin/bash

# Make sure we're starting clean
./service-mesh-delete.sh

# Fail on error
set -e

# when true, Kiali will be enabled in the basic SMCP
KIALI_ENABLED=${KIALI_ENABLED:-"false"}
# this is a default SMCP when creating SMCP via OCP UI console
USE_DEFAULT_SMCP=${USE_DEFAULT_SMCP:-"false"}

# Install subscriptions
oc apply -f service-mesh-subs.yaml
#oc apply -f service-mesh-subs-qe.yaml

RETRY=0
while :
do
  INCOMPLETE_OPERATORS=$(oc get subs -o json -n openshift-operators | jq -r '.items[] | select (.status.state!="AtLatestKnown") | .metadata.name')
  if [ -z "$INCOMPLETE_OPERATORS" ]; then
    break;
  fi
  echo -e "Retry $RETRY: Incomplete operators:\n$INCOMPLETE_OPERATORS"
  UNAPPROVED_INSTALLPLANS=$(oc get installplan -n openshift-operators -o json | jq -r '.items[] | select(.spec.approved==false) | .metadata.name')
  echo -e "Retry $RETRY: Unapproved installplans:\n$UNAPPROVED_INSTALLPLANS"
  if [ -n "$UNAPPROVED_INSTALLPLANS" ]; then
    for INSTALLPLAN in "$UNAPPROVED_INSTALLPLANS"
    do
      echo "Patch installplan '$INSTALLPLAN'"
      oc patch installplan -n openshift-operators $INSTALLPLAN -p '{"spec":{"approved":true}}' --type=merge
    done
  fi
  if [ $((RETRY%12)) -eq 11 ]; then
    oc delete csv kiali-operator.v1.36.6 -n openshift-operators
  fi
  sleep 5
  RETRY=$((RETRY + 1))
done

VERSION=${VERSION:-"2.0"}
if [ "$VERSION" == "2.0" ] || [ "$VERSION" == "2.1" ]; then
   SMCP=smcp_v2.yaml
else
   SMCP=smcp.yaml
fi

# when asked for default, using v2 version
if [ "$USE_DEFAULT_SMCP" == "true" ]; then
  SMCP=smcp_v2_default.yaml
fi

while :
do
  ADMISSION_CONTROLLERS=$(oc get ep -n openshift-operators maistra-admission-controller -o json | jq '.subsets[0].addresses | length')
  if [ $ADMISSION_CONTROLLERS -eq "1" ]; then
    echo "Admission controller is up."
    break;
  fi
  echo "Waiting for admission controller to boot, ready: $ADMISSION_CONTROLLERS"
  sleep 5
done;

# Install control-plane
oc new-project mesh-control-plane || true # don't fail if it exists
while ! cat $SMCP | KIALI_ENABLED=${KIALI_ENABLED} envsubst | oc apply -f - ; do
  echo "The operator pod is probably not accepting connections yet..."
  sleep 5;
done;

# Create mesh-scale namespace so we can register a member roll
oc new-project mesh-scale || true # don't fail if it exists
while ! oc apply -f smmr.yaml; do
  echo "Mutating webhook is probably not accepting connections yet..."
  sleep 5;
done;

# Wait until operator creates the deployment
while ! oc get deployment istio-ingressgateway -n mesh-control-plane 2> /dev/null; do
  echo "Ingress gateway is not defined yet"
  sleep 1;
done;

# Make sure there's only one gateway (otherwise the loop below gets stuck)
oc scale deployment istio-ingressgateway -n mesh-control-plane --replicas=1

# Wait until everyone boots up
while ! oc get po -n mesh-control-plane -l app=istiod --field-selector 'status.phase=Running'; do
  echo "Waiting for istiod to boot"
  sleep 1;
done;

while ! oc get po -n mesh-control-plane -l app=istio-ingressgateway --field-selector 'status.phase=Running'; do
  echo "Waiting for ingress gateway to boot"
  sleep 1;
done;

while ! oc get po -n mesh-control-plane -l app=prometheus --field-selector 'status.phase=Running'; do
  echo "Waiting for prometheus to boot"
  sleep 1;
done;

if [ "${KIALI_ENABLED}" == "true" ]
then
  while ! oc get po -n mesh-control-plane -l app=kiali --field-selector 'status.phase=Running'; do
    echo "Waiting for kiali to boot"
    sleep 1;
  done;
fi
