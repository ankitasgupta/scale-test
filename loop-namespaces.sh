#!/bin/bash

set -e 
set +x

# This script performs setup & execution of load test over a cluster with a 
# decreasing amount of namespaces.

# This documentation assumes an up and running openshift install:
# I have worked up to 200 namespaces on my quicklab instance/install which consists of:
# 3 masters - 4cores/28GB, 3workers - 4cores/30GB

# First, install hyperfoil through operatorhub.
# Then, create a namespace called "hyperfoil" and deploy hyperfoil to it
#   NOTE: last time I have had to replace "hyperfoil.apps.mycloud.example.com" with the 
#         real wildcard postfix hyperfoil.apps.scaletest5.lab.upshift.rdu2.redhat.com in the yaml view of "create hyperfoil"
# Now update hyperfoil_agent in the hosts.scalelab file to point the the node that runs this hyperfoil pod/instance
# (otherwise the ' Upload benchmark template' step in test.yaml will fail)
# e.g. I ended up with
# worker-0.scaletest5.lab.upshift.rdu2.redhat.com ansible_user=quicklab ansible_ssh_private_key_file=~/.ssh/quicklab.key
# The quicklab.key file can be obtained from the quicklab cluster details web page.
# 
# now assign roles for running the gateway (router) and workload (workload):

# oc label node/worker-1.scaletest5.lab.upshift.rdu2.redhat.com test.role=router
# oc label node/worker-2.scaletest5.lab.upshift.rdu2.redhat.com test.role=workload

# Ideally the load generator, workload and gateway are not competing for resources during test execution.
# This will make the gateway run on worker-1 and the app workload on worker-2.
# (if you don't do this, gateway deployment and app deployment may hang during test setup) 

# You may also need to set up ansible for hyperfoil, by running:
# $ ansible-galaxy collection install hyperfoil.hyperfoil_test
# $ ansible-galaxy install hyperfoil.hyperfoil_test
# $ ansible-galaxy install hyperfoil.hyperfoil_setup


# Install OSSM
VERSION=2.1 ./service-mesh-install.sh
# Set up the test prerequisites
ansible-playbook -v -i hosts.quicklab setup.yaml

# Iterate over a decreasing number of namespaces
for num_namespaces in 10 0 ; do
    ansible-playbook -e num_namespaces=$num_namespaces -v -i hosts.quicklab test.yaml
done

# Clean up the mesh.
./service-mesh-delete.sh

