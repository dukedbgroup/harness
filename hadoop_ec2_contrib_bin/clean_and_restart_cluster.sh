#!/usr/bin/env bash

# NOTE: This script is run on the EC2 Hadoop Master node to stop Hadoop and HDFS, 
#     erase the entire current HDFS filesystem, and to restart Hadoop and HDFS

# The list of slave nodes
HOSTLIST="/root/SLAVE_NAMES.txt"

# SSH options used when connecting to EC2 Slave instances from the Master
SSH_OPTS=`echo -o StrictHostKeyChecking=no -o ServerAliveInterval=30`

HADOOP_HOME=`ls -d /usr/local/hadoop-*`

# Make sure that the /usr/local/hadoop-0.20.2/conf/slaves file in the master node 
# has the list of slaves. This way, we can easily shutdown/start the
# hadoop cluster using the stop-all.sh and start-all.sh commands
cat $HOSTLIST >$HADOOP_HOME/conf/slaves

# A small trick to get localhost to be added to the list of 
#   known hosts so that an annoying question will not get asked
ssh $SSH_OPTS "localhost" "echo Going to stop and restart Hadoop and HDFS"

# Stop the Hadoop cluster and HDFS
${HADOOP_HOME}/bin/stop-all.sh

# remove the current contents of the NameNode's name directory
rm -rf /mnt/hadoop/dfs/name/*;

for slave_private_ip in `cat "$HOSTLIST"`; do
 {

  # each instance of the for loop is run in a subshell -- grouped using "(" and ")"
  (
       ssh $SSH_OPTS "root@${slave_private_ip}" "rm -rf /mnt/hadoop/dfs/data/*"
  ) &
   
 } 
done

wait

# Format the NameNode
echo 'Y' | ${HADOOP_HOME}/bin/hadoop namenode -format

# Restart the Hadoop cluster and HDFS
${HADOOP_HOME}/bin/start-all.sh

  echo ""
  echo "*********************************************************************"
  echo "NOTE: On JobTracker web page, verify that all slave nodes have joined"
  echo "      the cluster (it may take a few seconds for all slaves to join)"
  echo "      JobTracker web page is at: http://<HADOOP_MASTER_NODE>:50030"
  echo "*********************************************************************"
  echo ""
