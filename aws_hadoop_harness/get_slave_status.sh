#!/bin/bash

HOSTLIST="./SLAVE_INSTANCE_IDS.txt"

for slave_instance_id in `cat "$HOSTLIST"`; do
 {

# $2 is the instance ID field, and $6 is the status field
     ${EC2_HOME}/bin/ec2-describe-instances $slave_instance_id | awk '/^INSTANCE/ {print $2 "\t" $6}'

 } &
done

wait
