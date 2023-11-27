#!/usr/bin/bash

# need to label the nodes 

for i in `oc get no | grep worker | awk '{print $1}'` 
do 
  oc label node $i test.role=workload
  oc label node $i workload=${i}
done

for i in `oc get no | grep worker | awk '{print $1}' | tail -1` 
do
  oc label node $i test.role=router --overwrite
done
