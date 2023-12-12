#!/bin/bash

DOMAIN=$1
NUM_APPS=$2

REPLICAS=$(oc get deployment -n istio-system istio-ingressgateway -o json | jq -r .spec.replicas)
echo "Waiting for all gateways to come up"
while true; do
    RUNNING=$(oc get po -n istio-system -l app=istio-ingressgateway --field-selector 'status.phase=Running' --no-headers | wc -l)
    if [ $RUNNING -eq $REPLICAS ]; then break; fi
    sleep 1;
done

STATUS="ok"
for i in $(seq 1 $NUM_APPS); do
    echo -n "Check app-${i}..."
    if curl -s -f -k -H 'x-variant: stable' https://app-${i}.${DOMAIN}/name 1>&2; then
       echo "OK"
    else
       echo "NOT OK"
       STATUS="fail"
       break;
    fi
done;
if [ $STATUS = "ok" ]; then
    echo "All good, exiting"
    exit 0;
fi

echo "Deleting ingress gateway"
exit 1;
