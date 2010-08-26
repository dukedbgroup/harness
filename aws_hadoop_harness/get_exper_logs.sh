#!/usr/bin/env bash

# This script is given the experiment base directory containing 
#  the  subdirectories where experiments have been run. It extracts
#  the Hadoop Job ID for each experiment, and fetches logs from the 
#  Hadoop slave nodes where map/reduce tasks for this experiment ran
#
# Usage: Two parameters
# ./get_exper_logs.sh <base directory for experiments> <file listing Hadoop slaves>

##########################################################################

# The subdirectory name for each experiments is stored in the 
#  experiment base directory in the following file 
declare EXP_ORDER_FILE="RANDOMIZED_EXPERIMENT_LIST.txt"

# The name of the file (in each experiment subdirectory) where the output 
#   of the hadoop jar command for the experiment is written to
declare HADOOP_JAR_COMMAND_OUTPUT_FILE="output.txt"

# Pick up the definitions of HADOOP_LOG_DIR, HADOOP_SSH_OPTS, and HADOOP_SLAVE_SLEEP
declare HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-$HADOOP_HOME/conf}"
if [ -f "${HADOOP_CONF_DIR}/hadoop-env.sh" ]; then
  . "${HADOOP_CONF_DIR}/hadoop-env.sh"
fi

#  /mnt/hadoop/logs is the log dir on EC2 nodes
declare HADOOP_LOG_DIR="${HADOOP_LOG_DIR:-/mnt/hadoop/logs}"

# The MapReduce user log dir
declare MR_USERLOG_DIR="${HADOOP_LOG_DIR}/userlogs"

##########################################################################

# Check Usage
if [ $# -ne 2 ] && [ $# -ne 3 ]; then
    printf "Usage: $0 <base directory for experiments> <file listing Hadoop slaves> [compress]\n"
    printf "Specify 'compress' if you want the logs to be compressed in the userlogs directory\n";
    exit -1
fi

# the file listing all input directories (that will each be read later)
declare INPUT_DIR=$1
if test ! -d $INPUT_DIR; then
    printf "ERROR: Invalid experiment base directory $INPUT_DIR. Exiting\n"
    exit -1
fi

# The list of slaves in this Hadoop cluster. Same format as the slaves file 
#  in Hadoop -- one slave per line 
declare HOSTLIST=$2
if test ! -e $HOSTLIST; then
    printf "ERROR: Invalid file listing the Hadoop slave nodes. Exiting\n"
    exit -1
fi

declare COMPRESS=$3
if [ $# -eq 3 ] && [ "$COMPRESS" != "compress" ]; then
   printf "ERROR: The only valid value for the 3rd argument is 'compress'. Exiting\n"
   exit -1
fi

# go to the experiment base directory 
cd $INPUT_DIR

# check for the file that stores the order of running experiments
if test ! -e $EXP_ORDER_FILE; then
    printf "ERROR: File $EXP_ORDER_FILE that lists the experiments is missing in base experiment directory $INPUT_DIR. Exiting\n"
    exit -1
fi

# the loop that goes into each experiment directory follows 

declare CURR_DIR=`pwd`
declare direc
declare -a hadoop_job_ids_array
declare hadoop_job_ids_str
declare hadoop_job_id
declare userlog_dirs
declare tar_gzipped_file
declare attempt_dirname_pattern

exec 3< $EXP_ORDER_FILE
while read direc <&3 ; do
    
    # cd $CURR_DIR ensures that the program will work irrespective of whether 
    #   the paths specified in EXP_ORDER_FILE are absolute or relative paths 
    cd $CURR_DIR
    
    # printf "Entering experiment input directory %s\n" "$direc"
    cd $direc
    
    if test ! -e $HADOOP_JAR_COMMAND_OUTPUT_FILE; then
    printf "Output file %s does not exist in the experiment directory %s\n" "$HADOOP_JAR_COMMAND_OUTPUT_FILE" "$direc"
    printf "Skipping this experiment\n"
    continue
    fi
    
    # get the Hadoop Job ID
    # grep "Running" output.txt  ---> returns lines of the form
    # 10/01/26 08:11:26 INFO mapred.JobClient: Running job: job_201001231500_0039
    # In the case of multiple lines, the hadoop_job_ids_str will contain all
    # job id separated by \n
 
    hadoop_job_ids_str=`grep "Running" $HADOOP_JAR_COMMAND_OUTPUT_FILE | sed 's/.*\(job[0-9_]\+\)$/\1/'`
    
    # split hadoop_job_ids_str using tr
    hadoop_job_ids_array=(`echo $hadoop_job_ids_str | tr '\n' ' '`)

    #iterate over the hadoop job ids
    for hadoop_job_id in ${hadoop_job_ids_array[@]}; do

		# if this is a valid job id, then we can go to the slaves
		if [ "${hadoop_job_id:0:4}" != "job_" ]; then
		printf "Invalid Hadoop Job ID \"%s\" in the experiment directory %s\n" "$hadoop_job_id" "$direc"
		printf "Skipping this experiment\n"
		continue
		fi
		
		# The directories corresponding to the map task attempts have the format
		#    attempt_201001052153_0021_m_000004_0
		#    attempt_201001052153_0021_m_000004_1
		# The directories corresponding to the reduce task attempts have the format
		#    attempt_201001052153_0021_r_000004_0
		#    attempt_201001052153_0021_r_000004_1
		
		# Note: ${hadoop_job_id/job_/} replaces the first occurence of "job_" in
		#   ${hadoop_job_id} with ""
		attempt_dirname_pattern="attempt_${hadoop_job_id/job_/}"

		rm -rf userlogs
		mkdir -p userlogs
		
		#  For each slave host
		for slave in `cat "$HOSTLIST"`; do
		{
		    userlog_dirs="$( ssh $HADOOP_SSH_OPTS $slave "ls -1t ${MR_USERLOG_DIR} | grep \"${attempt_dirname_pattern}\"" )"
		    tar_gzipped_file="/tmp/tasklogs_${hadoop_job_id}_${slave}.tar.gz"
		    ssh $HADOOP_SSH_OPTS $slave "cd ${MR_USERLOG_DIR}; tar -zcf ${tar_gzipped_file} $( echo ${userlog_dirs} )"
		    scp $HADOOP_SSH_OPTS $slave:${tar_gzipped_file} "userlogs/"
		    ssh $HADOOP_SSH_OPTS $slave "rm -f $tar_gzipped_file"
		    
		    if [ "$COMPRESS" != "compress" ]; then
		        tar xvfz userlogs/tasklogs_${hadoop_job_id}_${slave}.tar.gz -C userlogs > /dev/null
		        rm -f userlogs/tasklogs_${hadoop_job_id}_${slave}.tar.gz
		    fi

		    if [ "$HADOOP_SLAVE_SLEEP" != "" ]; then
		        sleep $HADOOP_SLAVE_SLEEP
		    fi
		} &
		done
		wait
    done
    
    #printf "Exiting experiment input directory %s\n" "$direc"
    
done

cd $CURR_DIR

exit 0


