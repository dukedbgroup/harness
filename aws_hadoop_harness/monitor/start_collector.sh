#!/usr/bin/env bash

#
# Start iostat and vmstat on all slave hosts.
#
# Usage: start_collector.sh slaves_file monitor_dir
#   slaves_file = file with slave nodes
#   monitor_dir = directory on slaves to store the monitored data
#                 Must not exist. Specify full path!
#   time        = optional flag for appending output with epoch timestamp
#                 NOTE: It is NOT supported by IOParser.java
##

# if no args specified, show usage
if [ $# -le 0 ]; then
  echo "Usage: start_collector.sh slaves_file monitor_dir [time]"
  echo "  slaves_file = File with slave nodes"
  echo "  monitor_dir = Directory on slaves to store the monitored data"
  echo "                Must not exist. Specify full path!"
  echo "  time = optional flag for appending output with epoch timestamp"
  exit 1
fi

# Get input args
HADOOP_SLAVES=$1
SAVE_PATH=$2
USE_TIME=$3

# Start the collection
for slave in `cat "$HADOOP_SLAVES"|sed  "s/#.*$//;/^$/d"`; 
do
  echo $slave
  ssh $slave mkdir ${SAVE_PATH}
  
  if [ -z $USE_TIME ] || [ $USE_TIME != "time" ]
  then
     # No timestamp
     ssh $slave 'nohup iostat -m 3 sda2 > '${SAVE_PATH}'/iostat_output-'${slave}' &' &
     ssh $slave 'nohup vmstat 3 > '${SAVE_PATH}'/vmstat_output-'${slave}' &' &
  else
     # With timestamp
     ssh $slave "nohup iostat -m 3 sda2 | awk '{now=strftime(\"%s \"); print now \$0}' > ${SAVE_PATH}/iostat_output-${slave} &" &
     ssh $slave "nohup vmstat 3 | awk '{now=strftime(\"%s \"); print now \$0}' > ${SAVE_PATH}/vmstat_output-${slave} &" &
  fi
  

done
