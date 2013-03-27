#!/usr/bin/env bash

set -x
set -e 
#set -u

START_TIME=$(date +%s)
INSTANCE_IMAGE=${INSTANCE_IMAGE:-jenkins-precise}

source $(dirname $0)/chef-jenkins.sh

#environment variables must be declared when using set -u
GIT_PATCH_URL=${GIT_PATCH_URL:-}
GIT_REPO=${GIT_REPO:-}

REPO=${GIT_REPO%.git}
REPO=${REPO#opencenter-}
echo "Starting happy-path gate for a path in $REPO"

init #set traps, read credentials etc

# Build a test cluster, on test infrastructure
declare -a cluster
cluster=(
  ocserver:jenkins-precise:roush
  node1:jenkins-precise:roush
  node2:jenkins-precise:roush
  node3:jenkins-precise:roush
  node4:jenkins-precise:roush
  node5:jenkins-precise:roush
)

boot_cluster ${cluster[@]}
wait_for_cluster_ssh ${cluster[@]}

# install opencenter-server
x_with_server "Installing OpenCenter-Server" ocserver <<EOF
curl -s "https://raw.github.com/rcbops/opencenter-install-scripts/sprint/install-dev.sh" | bash -s -- --role=server
EOF
background_task "fc_do"

# install opencenter-agent
x_with_cluster "Installing OpenCenter-Agent" node1 node2 node3 node4 node5 <<EOF
curl -s "https://raw.github.com/rcbops/opencenter-install-scripts/sprint/install-dev.sh" | bash -s -- --role=agent --ip=$(ip_for_host ocserver) --$REPO-patch-url=$GIT_PATCH_URL
EOF

# make sure opencenter-server looks right
x_with_server "Running Happy Path Tests" ocserver <<EOF
#make_roush_log_dev_null
#service roush restart

apt-get install -y git
cd /opt
git clone https://github.com/hughsaunders/opencenter-testerator.git
cd opencenter-testerator
export OPENCENTER_CONFIG_DIR="\$(pwd)/etc"
export OPENCENTER_CONFIG="opencenter-gate.conf"
export OPENCENTER_ENDPOINT="http://$(ip_for_host ocserver):8080" 
./run_tests.sh -V
EOF
fc_do
