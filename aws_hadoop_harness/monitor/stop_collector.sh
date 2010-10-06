#!/usr/bin/env bash

#
# Stop iostat and vmstat on all slave hosts and gather the outputs
#
# Usage: stop_collector.sh slaves_file monitor_dir collect_dir
#   slaves_file = file with slave nodes
#   monitor_dir = directory on slaves with monitored data
#   collect_dir = local directory to collect the monitoring files
#   rm          = optional flag to remove the files from the slaves
##

# if no args specified, show usage
if [ $# -le 2 ]; then
  echo "Usage: stop_collector.sh slaves_file monitor_dir collect_dir [rm]"
  echo "  slaves_file = file with slave nodes"
  echo "  monitor_dir = directory on slaves with monitored data"
  echo "  collect_dir = local directory to collect the monitoring files"
  echo "  rm          = optional flag to remove the files from the slaves"
  exit 1
fi


# Get input args
HADOOP_SLAVES=$1
SAVE_PATH=$2
LOCAL_PATH=$3
REMOVE=$4

# Stop collection and get logs
mkdir ${LOCAL_PATH} >& /dev/null
for slave in `cat "$HADOOP_SLAVES"|sed  "s/#.*$//;/^$/d"`; 
do
  echo $slave
  ssh $slave 'killall iostat';
  ssh $slave 'killall vmstat';
  scp $slave:${SAVE_PATH}'/iostat_output-'${slave} ${LOCAL_PATH}
  scp $slave:${SAVE_PATH}'/vmstat_output-'${slave} ${LOCAL_PATH}
  
  if [ $REMOVE ] && [ $REMOVE == "rm" ]
  then
     ssh $slave "rm ${SAVE_PATH}/iostat_output-${slave}";
     ssh $slave "rm ${SAVE_PATH}/vmstat_output-${slave}";
  fi
done

