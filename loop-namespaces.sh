#!/bin/bash

set -e 
set +x

# Assumes an up and running openshift install:
# I have worked up to 200 namespaces on my quicklab instance/install which consists of:
# 3 masters - 4cores/28GB, 3workers - 4cores/30GB

# 
# First, install hyperfoil through operatorhub.
# Then, create hyperfoil namespace & deploy hyperfoil to it
#   NOTE: last time I have had to replace "hyperfoil.apps.mycloud.example.com" with the real wildcard postfix hyperfoil.apps.scaletest5.lab.upshift.rdu2.redhat.com in the yaml view of "create hyperfoil"
# Now update hyperfoil_agent in the hosts.scalelab file to point the the node that runs this instance (worker-0 usually, it seems)
# (otherwise the ' Upload benchmark template' step in test.yaml will fail)
# e.g. I ended up with
# worker-0.scaletest5.lab.upshift.rdu2.redhat.com ansible_user=quicklab ansible_ssh_private_key_file=~/.ssh/quicklab.key
# 
# now assign roles for running the gateway (router) and workload (workload):

# oc label node/worker-1.scaletest5.lab.upshift.rdu2.redhat.com test.role=router
# oc label node/worker-2.scaletest5.lab.upshift.rdu2.redhat.com test.role=workload

# You also need to set up ansible for hyperfoil, by running:
# $ ansible-galaxy collection install hyperfoil.hyperfoil_test
# $ ansible-galaxy install hyperfoil.hyperfoil_test
# $ ansible-galaxy install hyperfoil.hyperfoil_setup

# This will make the gateway run on worker-1 and the app workload on worker-2.
# (if you don't do this, gateway deployment and app deployment will hang) 


# TODO: Add 2.2
VERSION=2.1 ./service-mesh-install.sh
ansible-playbook -v -i hosts.quicklab setup.yaml

for num_namespaces in 200 100 0 ; do
    ansible-playbook -e num_namespaces=$num_namespaces -v -i hosts.quicklab test.yaml
done

./service-mesh-delete.sh

