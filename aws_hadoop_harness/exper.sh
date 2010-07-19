#!/usr/bin/env bash

# This script is given the experiment base directory under which preprocessing 
#   code has placed Hadoop configuration files for each experiment, 
#   and will run a customized bash script to run each experiment
#
# Usage: Only one parameter. 
# Parameter #1 is the base directory for experiments

##########################################################################

# The name of the file (in each experiment directory) specifying the 
#  name of the hadoop command script that will be used to run the experiment
declare HADOOP_JAR_COMMAND_SCRIPT="run_hadoop_jar.sh"

# The order as well as subdirectory names of experiments to run is 
#  stored in the experiment base directory under the following name
declare EXP_ORDER_FILE="RANDOMIZED_EXPERIMENT_LIST.txt"

# The name of the file (in each experiment directory) where the output of the 
#   hadoop jar command is written to
declare HADOOP_JAR_COMMAND_OUTPUT_FILE="output.txt"

# The name of the file in the experiment base directory where the Hadoop
#  Job ID for each experiment will be written
declare HADOOP_JOB_IDS_FILE="HADOOP_JOB_IDS.txt"

##########################################################################

#Check Usage
if [ $# -ne 1 ]; then
    printf "Usage: The one and only input parameter is the experiment base directory\n"
    exit -1
fi

# the file listing all input directories (that will each be read later)
declare INPUT_DIR=$1
if test ! -d $INPUT_DIR; then
    printf "ERROR: Invalid experiment base directory. Exiting\n"
    exit -1
fi

# go to the experiment base directory 
cd $INPUT_DIR

# check for the file that stores the order of running experiments
if test ! -e $EXP_ORDER_FILE; then
    printf "ERROR: File $EXP_ORDER_FILE that lists the order of experiments is missing in base experiment directory $INPUT_DIR. Exiting\n"
    exit -1
fi

# the loop that goes into each experiment directory and runs the experiment follows 

declare CURR_DIR=`pwd`
declare direc
declare hadoop_job_id

# You need to use -e to enable the use of special characters like \t
echo -e "EXPT_ID\tHADOOP_JOB_ID" >$CURR_DIR/$HADOOP_JOB_IDS_FILE

exec 3< $EXP_ORDER_FILE
while read direc <&3 ; do
    
    # cd $CURR_DIR ensures that the program will work irrespective of whether 
    #   the paths specified in EXP_ORDER_FILE are absolute or relative paths 
    cd $CURR_DIR
    
    #printf "Entering experiment input directory %s\n" "$direc"
    cd $direc
    
    if test ! -x $HADOOP_JAR_COMMAND_SCRIPT; then
	printf "Script %s does not exist or is not executable in the experiment directory %s\n" "$HADOOP_JAR_COMMAND_SCRIPT" "$direc"
	printf "Skipping this experiment\n"
	#printf "Exiting experiment input directory %s\n" "$direc"
	continue
    fi
    
    printf "Running %s\n" "$CURR_DIR/$direc/$HADOOP_JAR_COMMAND_SCRIPT"
    
    # run the script 
    . $HADOOP_JAR_COMMAND_SCRIPT
    
#grep "Running" output.txt ---> returns the line of the form
#10/01/26 08:11:26 INFO mapred.JobClient: Running job: job_201001231500_0039
    
    hadoop_job_id="Null"
    if test -e $HADOOP_JAR_COMMAND_OUTPUT_FILE; then
	hadoop_job_id=`grep "Running" $HADOOP_JAR_COMMAND_OUTPUT_FILE | sed 's/.*\(job[0-9_]\+\)$/\1/'`
	if [ "${hadoop_job_id:0:4}" != "job_" ]; then
	    hadoop_job_id="Null"
	fi
    fi
    echo -e "$direc\t$hadoop_job_id" >>$CURR_DIR/$HADOOP_JOB_IDS_FILE
    
    #printf "Exiting experiment input directory %s\n" "$direc"
   
done

cd $CURR_DIR

exit 0


