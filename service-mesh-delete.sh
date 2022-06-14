#!/bin/bash

# Not deleted SMMR may cause namespace deletion failure
oc delete smmr -n mesh-control-plane --all
oc delete smcp -n mesh-control-plane basic-install
oc delete smcp -n mesh-control-plane default-install
# we want to be sure that kiali CR is gone before removing the namespace to avoid being stuck in terminating stage
# if it happens, following should fix it: oc patch kiali kiali -n mesh-control-plane -p '{"metadata":{"finalizers": []}}' --type=merge
while oc get kiali kiali -n mesh-control-plane &> /dev/null
do
  echo "Waiting for Kiali CR to be deleted"
  sleep 10
done
oc delete namespace mesh-control-plane mesh-scale

oc delete subs -n openshift-operators servicemeshoperator kiali-ossm jaeger-product elasticsearch-operator
oc delete subs -n openshift-operators servicemeshoperator
oc delete csv -n openshift-operators -l operators.coreos.com/elasticsearch-operator.openshift-operators
oc delete csv -n openshift-operators -l operators.coreos.com/jaeger-product.openshift-operators
oc delete csv -n openshift-operators -l operators.coreos.com/kiali-ossm.openshift-operators
oc delete csv -n openshift-operators -l operators.coreos.com/servicemeshoperator.openshift-operators

# These two should be removed by the operator, so just in case...
oc delete mutatingwebhookconfiguration -l app.kubernetes.io/instance=mesh-control-plane
oc delete validatingwebhookconfiguration -l app.kubernetes.io/instance=mesh-control-plane

oc delete mutatingwebhookconfiguration openshift-operators.servicemesh-resources.maistra.io
oc delete validatingwebhookconfiguration openshift-operators.servicemesh-resources.maistra.io

# Operator itself seems to persist
oc delete deployment -n openshift-operators istio-operator
oc delete daemonset -n openshift-operators istio-node
oc delete sa -n openshift-operators istio-operator
oc delete sa -n openshift-operators istio-cni
oc delete service maistra-admission-controller

# Removing remaining resources (https://docs.openshift.com/container-platform/4.10/service_mesh/v2x/removing-ossm.html)
oc delete clusterrole/istio-admin clusterrole/istio-cni clusterrolebinding/istio-cni
oc delete clusterrole istio-view istio-edit
oc delete clusterrole jaegers.jaegertracing.io-v1-admin jaegers.jaegertracing.io-v1-crdview jaegers.jaegertracing.io-v1-edit jaegers.jaegertracing.io-v1-view
oc get crds -o name | grep '.*\.istio\.io' | xargs -r -n 1 oc delete
oc get crds -o name | grep '.*\.maistra\.io' | xargs -r -n 1 oc delete
oc get crds -o name | grep '.*\.kiali\.io' | xargs -r -n 1 oc delete
oc delete crds jaegers.jaegertracing.io
oc delete secret -n openshift-operators maistra-operator-serving-cert
oc delete cm -n openshift-operators maistra-operator-cabundle
