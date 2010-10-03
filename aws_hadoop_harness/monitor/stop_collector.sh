#!/usr/bin/env bash

#
# Stop iostat and vmstat on all slave hosts and gather the outputs
#
# Usage: stop_collector.sh slaves_file monitor_dir collect_dir"
#   slaves_file = file with slave nodes"
#   monitor_dir = directory on slaves with monitored data"
#   collect_dir = local directory to collect the monitoring files"
##

# if no args specified, show usage
if [ $# -le 0 ]; then
  echo "Usage: stop_collector.sh slaves_file monitor_dir collect_dir"
  echo "  slaves_file = file with slave nodes"
  echo "  monitor_dir = directory on slaves with monitored data"
  echo "  collect_dir = local directory to collect the monitoring files"
  exit 1
fi


# Get input args
HADOOP_SLAVES=$1
SAVE_PATH=$2
LOCAL_PATH=$3


# Stop collection and get logs
mkdir ${LOCAL_PATH}
for slave in `cat "$HADOOP_SLAVES"|sed  "s/#.*$//;/^$/d"`; 
do
  echo $slave
  ssh $slave 'killall iostat';
  ssh $slave 'killall vmstat';
  scp $slave:${SAVE_PATH}'/*' ${LOCAL_PATH}
done

