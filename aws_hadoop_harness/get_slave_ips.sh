#!/bin/bash

HOSTLIST="./SLAVE_INSTANCE_IDS.txt"

for slave_instance_id in `cat "$HOSTLIST"`; do
 {

# $4 represents the public IP address field
     ${EC2_HOME}/bin/ec2-describe-instances $slave_instance_id | awk '/^INSTANCE/ {print $4}'

 } &
done

wait
