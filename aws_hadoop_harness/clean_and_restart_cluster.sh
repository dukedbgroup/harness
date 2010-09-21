#!/usr/bin/env bash

# NOTE: This script is run on the EC2 Hadoop Master node to stop Hadoop and HDFS, 
#     erase the entire current HDFS filesystem, and to restart Hadoop and HDFS
#
# NOTE: If you want a different configuration to be used in the Hadoop/HDFS Master
#  and Slaves when the cluster is restarted, then update the configuration blurbs
#  in the following two files (NOTE: update both files)
EC2_START_MASTER_SCRIPT="/root/ec2_hadoop_master_init.sh"
EC2_SLAVE_INIT_SCRIPT="/root/ec2_hadoop_slave_init.sh"

# The list of slave nodes
HOSTLIST="/root/SLAVE_NAMES.txt"
EC2_START_SLAVES_SCRIPT="/root/start_hadoop_on_slaves.sh"

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
# clean up the logs
rm -rf /mnt/hadoop/logs/*;

for slave_private_ip in `cat "$HOSTLIST"`; do
 {

  # each instance of the for loop is run in a subshell -- grouped using "(" and ")"
  (
# remove the current contents of the DataNode's data directory and clean up the logs
       ssh $SSH_OPTS "root@${slave_private_ip}" "rm -rf /mnt/hadoop/dfs/data/* /mnt/hadoop/logs/*"
  ) &
   
 } 
done

wait

# Format the NameNode
echo 'Y' | ${HADOOP_HOME}/bin/hadoop namenode -format

# Now: Restart the Hadoop cluster and HDFS

# Avoiding the use of start-all.sh because we may want to install a new 
#   set of configuration files in the cluster
#${HADOOP_HOME}/bin/start-all.sh

# restart the Hadoop and HDFS Master 
$EC2_START_MASTER_SCRIPT

# restart the Hadoop and HDFS Slaves
$EC2_START_SLAVES_SCRIPT

