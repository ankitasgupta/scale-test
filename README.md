# Istio/Maistra scalability tests

##  Prerequisites

### 1. OCP 
### 2. Ansible
### 3. Hyperfoil

https://github.ibm.com/Openshift-Addons-Performance/Openshift-performance-Docs-IBM-Z

### Firewall

## Setup

1. Install prerequisites
2. Run `prep_nodes.sh` to label the nodes.
3. Login to OCP: `oc login -u system:admin`

## Test with OSSM
    1. Install OSSM
        - In `controlplane/basic-install` set `gateways.ior_enabled: true` and `mixer.telemetry.enabled: false`
        - I suggest locating `istio-system` pods on the infra node (the same where the `default/router` resides):
          `oc patch namespace istio-system -p '{"metadata":{"annotations":{"openshift.io/node-selector":"node-role.kubernetes.io/infra=true"}}}'`
    2. Create hosts.* according to your system
    3. Run the setup (now everything should be automatized):
        `ansible-playbook -i hosts.withossm setup.yaml`
    4. Start the test:
        `ansible-playbook -i hosts.withossm test.yaml`
        
## Test without OSSM
    1. Create hosts.* according to your system
    2. Run the setup (now everything should be automatized):
        `ansible-playbook -i hosts.withoutossm setup.yaml`
    3. Start the test:
        `ansible-playbook -i hosts.withoutossm test.yaml`
        

## Hints:

* Add `LOG_LEVEL=TRACE` do deploymentconfig env vars if you want mannequin to be logging on trace level
* Add `global.proxy.accessLogFile: /dev/stdout` to `controlplane/basic-install` or modify directly `configmap/istio` to have access logs in `istio-proxy` containers.
* Add `--proxyLogLevel trace` to sidecar args to get the most verbose logging from Envoy
* Openshift router uses source balancing strategy by default. This won't work well if you're trying to scale ingress gateways - you have to edit the route and add annotation `haproxy.router.openshift.io/balance: roundrobin`

## Deprecated info

* There seems to be a bug in IOR (MAISTRA-356) that is not resolved in the image I use. Therefore you have to manually fix the generated route: `oc get route -n istio-system -l maistra.io/generated-by=ior` `oc patch route -n istio-system app-gateway-xxxxx -p '{ "spec": { "port" : { "targetPort": 443 }}}'`

TODO
oc get deployment istio-ingressgateway -o json | jq '.spec.template.spec.containers[].resources.requests={},.spec.template.spec.containers[].args += ["--proxy-concurrency", "4"]'
