#!/usr/bin/env bash

# NOTE: This script is run on the EC2 Hadoop Master node to stop and restart Hadoop and HDFS.
#   No deletion of HDFS files is done, but all logs will be deleted
#
# NOTE: If you want a different configuration to be used in the Hadoop/HDFS Master
#  and Slaves when the cluster is restarted, then update the configuration blurbs
#  in the following two files (NOTE: update both files)
EC2_START_MASTER_SCRIPT="/home/ubuntu/ec2_hadoop_master_init.sh"
EC2_SLAVE_INIT_SCRIPT="/home/ubuntu/ec2_hadoop_slave_init.sh"
cp -R /home/ubuntu/.ssh/* /root/.ssh
# The list of slave nodes
HOSTLIST="/home/ubuntu/SLAVE_NAMES.txt"
EC2_START_SLAVES_SCRIPT="/home/ubuntu/start_hadoop_on_slaves.sh"

# SSH options used when connecting to EC2 Slave instances from the Master
SSH_OPTS=`echo -o StrictHostKeyChecking=no -o ServerAliveInterval=30`

HADOOP_HOME=`ls -d /usr/local/hadoop-*`


# A small trick to get localhost to be added to the list of 
#   known hosts so that an annoying question will not get asked
ssh $SSH_OPTS "localhost" "echo Going to stop and restart Hadoop and HDFS"

sudo $HADOOP_HOME/bin/hadoop-daemon.sh stop namenode
sudo $HADOOP_HOME/bin/hadoop-daemon.sh stop jobtracker
# clean up the logs
rm -rf /mnt/hadoop/logs/*;

for slave_private_ip in `cat "$HOSTLIST"`; do
 {

  # each instance of the for loop is run in a subshell -- grouped using "(" and ")"
  (
       ssh $SSH_OPTS "ubuntu@${slave_private_ip}" "sudo $HADOOP_HOME"/bin/hadoop-daemon.sh stop datanode
       ssh $SSH_OPTS "ubuntu@${slave_private_ip}" "sudo $HADOOP_HOME"/bin/hadoop-daemon.sh stop tasktracker
       # clean up the logs
       ssh $SSH_OPTS "ubuntu@${slave_private_ip}" "sudo rm -rf /mnt/hadoop/logs/*"
  ) &
   
 } 
done

wait

# Now: Restart the Hadoop cluster and HDFS

# Avoiding the use of start-all.sh because we may want to install a new 
#   set of configuration files in the cluster
#${HADOOP_HOME}/bin/start-all.sh

# restart the Hadoop and HDFS Master 
$EC2_START_MASTER_SCRIPT

# restart the Hadoop and HDFS Slaves
sudo -u ubuntu $EC2_START_SLAVES_SCRIPT

