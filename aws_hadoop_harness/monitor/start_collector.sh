#!/usr/bin/env bash

#
# Start iostat and vmstat on all slave hosts.
#
# Usage: start_collector.sh slaves_file monitor_dir
#   slaves_file = file with slave nodes
#   monitor_dir = directory on slaves to store the monitored data
#                 Specify full path! Created if it doesn't exist.
#   time        = optional flag for appending output with epoch timestamp
#                 NOTE: It is NOT supported by IOParser.java
#                       You must use the Starfish Profiler instead
##

# if no args specified, show usage
if [ $# -le 1 ]; then
  echo "Usage: start_collector.sh slaves_file monitor_dir [time]"
  echo "  slaves_file = File with slave nodes"
  echo "  monitor_dir = Directory on slaves to store the monitored data"
  echo "                Specify full path! Created if it doesn't exist."
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
  ssh $slave mkdir ${SAVE_PATH} >& /dev/null
  
  if [ -z $USE_TIME ] || [ $USE_TIME != "time" ]
  then
     # No timestamp
     ssh $slave "nohup iostat -m 3 > ${SAVE_PATH}/iostat_output-${slave} &" &
     ssh $slave "nohup vmstat 3 > ${SAVE_PATH}/vmstat_output-${slave} &" &
  else
     # With timestamp
     ssh $slave "nohup iostat -m 3 | awk '{line = \$0; \"date +%s\"|getline time; print time \" \" line;}' > ${SAVE_PATH}/iostat_output-${slave} &" 
     ssh $slave "nohup vmstat 3 | awk '{line = \$0; \"date +%s\"|getline time; print time \" \" line;}' > ${SAVE_PATH}/vmstat_output-${slave} &" 
  fi
  

done
