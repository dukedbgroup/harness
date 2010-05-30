#!/usr/bin/env bash

# NOTE: This file will be copied to and run on the EC2 Hadoop Master node
#         to start the Hadoop slave nodes

# These two files will be scp'ed in launch-hadoop-slaves
#    as part of the starting the slaves
HOSTLIST="/root/SLAVE_NAMES.txt"
EC2_INIT_SCRIPT="/root/ec2_hadoop_slave_init.sh"

# SSH options used when connecting to EC2 Slave instances from the Master
SSH_OPTS=`echo -o StrictHostKeyChecking=no -o ServerAliveInterval=30`

# some slack to ensure that the ssh service starts working on the
#     slave nodes before the master attempts to ssh into them
declare -i NUM_SSH_ATTEMPTS=4
# wait interval between successive ssh attempts
declare -i SSH_WAIT_INTERVAL=5 

for slave_private_ip in `cat "$HOSTLIST"`; do
 {

  # each instance of the for loop is run in a subshell -- grouped using "(" and ")"
  (

   # if we fail to start the slave automatically, then a manual start will be required
   declare -i MANUAL_START_REQUIRED=1
   declare -i attempt_num=0
   declare REPLY

   # try ssh to see whether we can connect to the slave 
   for (( attempt_num=0; attempt_num < $NUM_SSH_ATTEMPTS; attempt_num++ )) ; do
     REPLY=`ssh $SSH_OPTS "root@${slave_private_ip}" 'echo "hello"'`
     if [ ! -z $REPLY ]; then
        # ssh worked 
        MANUAL_START_REQUIRED=0
        break;
     fi
     sleep $SSH_WAIT_INTERVAL
   done

   if [ $MANUAL_START_REQUIRED = 0 ]; then
        # scp and automatic start should work now for this slave
       scp $SSH_OPTS $EC2_INIT_SCRIPT "root@${slave_private_ip}:${EC2_INIT_SCRIPT}"
       ssh $SSH_OPTS "root@${slave_private_ip}" "${EC2_INIT_SCRIPT}"
   else 
       echo "ERROR: Automatic start of Hadoop on slave node ${slave_private_ip} failed. Manual start required."
   fi 
 
  ) &
   
 } 
done

wait

  echo "NOTE: On JobTracker web page, verify that all slave nodes are present (may take a few seconds for all slaves to join)"
  echo "NOTE: If automatic start failed for any slave, login to Hadoop master node and run /root/start_hadoop_on_slaves.sh"
