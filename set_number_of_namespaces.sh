#!/bin/bash

NUM_NS=${1:-0}
MEASURE_PERIOD=${MEASURE_PERIOD:-120}

NS_PREFIX=foobar-ns-perftest
EXISTING_PROJECTS=( $(oc projects --short | grep $NS_PREFIX) )
EXPECTED_PROJECTS=()
CREATED_PROJECTS=()
DELETED_PROJECTS=()

set -e 
# set -x

function sample_stats() {
    echo "sample stats for $2 seconds"
    sleep $2
    echo "get and store statistics"
    mkdir -p sampled_stats/
    pushd sampled_stats > /dev/null
    START=$(date +%s)
    END=$(( $START+ $2*1000 ))
    STEP="60"
    # cpu
    oc exec -n openshift-monitoring prometheus-k8s-0 -c prometheus  -it -- curl "http://127.0.0.1:9090/api/v1/query_range?start=${START}&end=${END}&step=${STEP}&query=%0A++++++sum%28%0A++++++++kube_pod_resource_request%7Bresource%3D%22cpu%22%7D%0A++++++++*%0A++++++++on%28node%29+group_left%28role%29+%28%0A++++++++++max+by+%28node%29+%28kube_node_role%7Brole%3D%7E%22.%2B%22%7D%29%0A++++++++%29%0A++++++%29%0A++++" > $1_cpu.json
    # memory
    oc exec -n openshift-monitoring prometheus-k8s-0 -c prometheus  -it -- curl "http://127.0.0.1:9090/api/v1/query_range?start=${START}&end=${END}&step=${STEP}&query=%0A++++++sum%28%0A++++++++%28node_memory_MemTotal_bytes+-+node_memory_MemAvailable_bytes%29%0A++++++++*%0A++++++++on%28instance%29+group_left%28role%29+%28%0A++++++++++label_replace%28max+by+%28node%29+%28kube_node_role%7Brole%3D%7E%22.%2B%22%7D%29%2C+%22instance%22%2C+%22%241%22%2C+%22node%22%2C+%22%28.*%29%22%29%0A++++++++%29%0A++++++%29%0A++++" > $1_memory.json
    # network rx bandwidth rx
    oc exec -n openshift-monitoring prometheus-k8s-0 -c prometheus  -it -- curl "http://127.0.0.1:9090/api/v1/query_range?start=${START}&end=${END}&step=${STEP}&query=%0A++++++sum%28%0A++++++++instance%3Anode_network_receive_bytes_excluding_lo%3Arate1m%0A++++++++*%0A++++++++on%28instance%29+group_left%28role%29+%28%0A++++++++++label_replace%28max+by+%28node%29+%28kube_node_role%7Brole%3D%7E%22.%2B%22%7D%29%2C+%22instance%22%2C+%22%241%22%2C+%22node%22%2C+%22%28.*%29%22%29%0A++++++++%29%0A++++++%29%0A++++" > $1_bandwidth_rx.json
    # network tx bandwith
    oc exec -n openshift-monitoring prometheus-k8s-0 -c prometheus  -it -- curl "http://127.0.0.1:9090/api/v1/query_range?start=${START}&end=${END}&step=${STEP}&query=%0A++++++sum%28%0A++++++++instance%3Anode_network_transmit_bytes_excluding_lo%3Arate1m%0A++++++++*%0A++++++++on%28instance%29+group_left%28role%29+%28%0A++++++++++label_replace%28max+by+%28node%29+%28kube_node_role%7Brole%3D%7E%22.%2B%22%7D%29%2C+%22instance%22%2C+%22%241%22%2C+%22node%22%2C+%22%28.*%29%22%29%0A++++++++%29%0A++++++%29%0A++++" > $1_bandwidth_tx.json
    popd > /dev/null
}

oc whoami > /dev/null

echo "Ensuring that there will be ${NUM_NS} namespaces."

for ((i=0;i<$NUM_NS;i++))
do
    EXPECTED_PROJECTS+=($NS_PREFIX-${i})
done

for value in "${EXISTING_PROJECTS[@]}"
do
    if [[ ! " ${EXPECTED_PROJECTS[*]} " =~ " ${value} " ]]; then
        echo "delete namespace ${value}"
        DELETED_PROJECTS+=(${value})
        oc delete pod --all --namespace="${value}" && oc delete project "${value}" &
    else
        echo "namespace ${value} already exists, not deleting it"
    fi
done


for value in "${EXPECTED_PROJECTS[@]}"
do
    if [[ ! " ${EXISTING_PROJECTS[*]} " =~ " ${value} " ]]; then
        echo "didn't find expected project ${value}"
        CREATED_PROJECTS+=(${value})
        # we need to delay launches in order to avoid being rate limited, it seems.
        sleep 1
        oc new-project --skip-config-write=true "${value}" && oc create --namespace "${value}" -f smallsleepingpod.yaml &
    else
        echo "expected namespace ${value} already exists, not creating it"
    fi
done

echo "projects updated, wait for background processes (if any)"
wait < <(jobs -p)
echo "projects updated, wait for project deletion to complete"

for value in "${DELETED_PROJECTS[@]}"
    do
    echo "wait for deletion of namespace ${value} to complete"
    until [ $( oc projects --short | grep "${value}" | wc -l ) == 0 ]
    do
        echo -n .
    done
done

for value in "${CREATED_PROJECTS[@]}"
do
    echo "wait for newly created namespace ${value} to ready up"
    oc wait --for=condition=Ready pods --all --namespace="${value}"
done

if [ $MEASURE_PERIOD != "0" ]; then
    sample_stats "$NUM_NS" "$MEASURE_PERIOD"
fi

echo "done" 
exit 0
