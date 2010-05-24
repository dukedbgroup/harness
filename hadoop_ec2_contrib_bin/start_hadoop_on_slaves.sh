#!/usr/bin/env bash

# NOTE: This file will be copied to and run on the EC2 Hadoop Master node

# These two files will be scp'ed in launch-hadoop-slaces
#    as part of the starting the slaves
HOSTLIST="/root/SLAVE_NAMES.txt"
EC2_INIT_SCRIPT="/root/ec2_hadoop_slave_init.sh"

# SSH options used when connecting to EC2 Slave instances from the Master
SSH_OPTS=`echo -o StrictHostKeyChecking=no -o ServerAliveInterval=30`

for slave_private_ip in `cat "$HOSTLIST"`; do
 {

   scp $SSH_OPTS $EC2_INIT_SCRIPT "root@${slave_private_ip}:${EC2_INIT_SCRIPT}"
   ssh $SSH_OPTS "root@${slave_private_ip}" "${EC2_INIT_SCRIPT}"
   
 } &
done

wait
