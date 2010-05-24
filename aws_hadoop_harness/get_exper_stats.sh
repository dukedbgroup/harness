#!/bin/bash

# This script will loop over a set of directories where the results from running
#     experiments with Hadoop have been placed. It will extract the Hadoop job id
#     corresponding to each experiment, and get the running times and other 
#     information for all the tasks for that job. These stats will be written 
#     in specifically named files in the same directory (for the experiment)

# Usage: Only one parameter. 
# Parameter #1 is the file listing THE FULL PATH (not relative path) to all experiment directories

##########################################################################

# Variables that will need to be adjusted to ensure that the appropriate 
#  command gets generated to run the experiment on Hadoop

###  NOTE: THESE NEED TO BE FULL PATHS AND NOT RELATIVE PATHS ###
declare TASK_TIMES_BASH_SCRIPT="/root/AWS_HADOOP_HARNESS/my_task_times.sh"
declare MAP_TIMES_PERL_FILE="/root/AWS_HADOOP_HARNESS/my_job_map_times.pl"
declare REDUCE_TIMES_PERL_FILE="/root/AWS_HADOOP_HARNESS/my_job_reduce_times.pl"
#################################################################

# Variables below should not need to be changed

# The name of the file (in each experiment directory) specifying the parameter configuration.
#   The preprocessing code creates this file per experiment/directory, so be careful
#   if you want to change this variable (that means you will need to change the preprocessing
#   code as well)
declare XML_CONFIGURATION_FILE="configuration.xml"

# The output of the hadoop command is written to this file (in each experiment directory)
declare EXPERIMENT_OUTPUT_FILE="output.txt"

# The running times of the map tasks for each experiment get written to this file in
#    each directory
declare MAP_TIMES_OUTPUT_FILE="map_task_times.txt"

# The running times of the reduce tasks for each experiment get written to this file in
#    each directory
declare REDUCE_TIMES_OUTPUT_FILE="reduce_task_times.txt"

##########################################################################

#Check Usage
if [ $# -ne 1 ] ; then
    printf "Usage: Parameter #1 is the file listing THE FULL PATH (not relative path) to all directories\n"
    exit 0
fi

# Check whether parameters have been specified correctly

# the file listing all input directories (that will be read later)
declare INPUT_DIR_FILE=$1

if test ! -e $INPUT_DIR_FILE; then
    printf "Invalid file listing all input directories\n"
    printf "Exiting\n"
    exit 192
fi

if test ! -e $TASK_TIMES_BASH_SCRIPT; then
    printf "Invalid bash script: $TASK_TIMES_BASH_SCRIPT\n"
    printf "Exiting\n"
    exit 192
fi

if test ! -e $MAP_TIMES_PERL_FILE; then
    printf "Invalid perl file to find map task running times: $MAP_TIMES_PERL_FILE\n"
    printf "Exiting\n"
    exit 192
fi

if test ! -e $REDUCE_TIMES_PERL_FILE; then
    printf "Invalid perl file to find reduce task running times: $REDUCE_TIMES_PERL_FILE\n"
    printf "Exiting\n"
    exit 192
fi

##################################################################
##################################################################

# the loop that get the stats for each experiment 
declare CURR_DIR=`pwd`
declare direc
declare hadoop_job_id
declare job_started_at
declare job_ended_at
declare job_start_time
declare job_end_time
declare job_start_date
declare job_end_date
declare -i job_started_at_epoch
declare -i job_ended_at_epoch
declare -i job_run_time

exec 3< $INPUT_DIR_FILE

while read direc <&3 ; do

#   printf "Entering experiment input directory %s\n" "$direc"

   # just in case the directories are specified relative to CURR_DIR
   cd $CURR_DIR
   cd $direc

   if test ! -e $XML_CONFIGURATION_FILE; then
      printf "Hadoop configuration file %s does not exist in the experiment directory %s\n" "$XML_CONFIGURATION_FILE" "$direc"
      printf "Skipping this experiment\n"
      continue
   fi

   if test ! -e $EXPERIMENT_OUTPUT_FILE; then
      printf "Output file %s does not exist in the experiment directory %s\n" "$EXPERIMENT_OUTPUT_FILE" "$direc"
      printf "Skipping this experiment\n"
      continue
   fi
   
#grep "Running" /usr/research/home/shivnath/HADOOP/HARNESS/TEMP/EXPT1/output.txt  ---> returns the line of the form
#10/01/26 08:11:26 INFO mapred.JobClient: Running job: job_201001231500_0039

   {

# get the job id        
        hadoop_job_id=`grep "Running" $EXPERIMENT_OUTPUT_FILE | sed 's/.*\(job[0-9_]\+\)$/\1/'`

# We would like to extract the job running time by subtracting the start time from the end time
#    The start time is extracted from the following line in the job output (note that this is not the first line):
# 10/05/10 15:05:06 INFO mapred.JobClient: Running job: job_201005101219_0006
#    The end time is extracted from the line in the job output which has the form:
# 10/05/10 16:01:45 INFO mapred.JobClient: Job complete: job_201005101219_0006
#
# There is one catch that we have to deal with: Hadoop times in the job output are printed in a surprising 
# "YY/MM/DD hh:mm:ss" format, while date -d assumes a more conventional "MM/DD/YY hh:mm:ss" format. 
# That is: the dates in the above example lines---10/05/10---are for May 10, 2010 
#
        job_started_at=`grep "Running" $EXPERIMENT_OUTPUT_FILE | grep "$hadoop_job_id" | awk '{print $1 " " $2}'`
        job_start_date=`echo $job_started_at | awk '{print $1}' | awk -F/ '{print $2"/"$3"/"$1}'`
        job_start_time=`echo $job_started_at | awk '{print $2}'`
        job_started_at="$job_start_date $job_start_time"
        job_started_at_epoch=`eval "date --date='$job_started_at' '+%s'"`
	
        job_ended_at=`grep "complete" $EXPERIMENT_OUTPUT_FILE | grep "$hadoop_job_id" | grep "Job" | awk '{print $1 " " $2}'`
        job_end_date=`echo $job_ended_at | awk '{print $1}' | awk -F/ '{print $2"/"$3"/"$1}'`
        job_end_time=`echo $job_ended_at | awk '{print $2}'`
        job_ended_at="$job_end_date $job_end_time"
        job_ended_at_epoch=`eval "date --date='$job_ended_at' '+%s'"`

        job_run_time=$job_ended_at_epoch-$job_started_at_epoch

# print the configuration parameter settings
        cat $XML_CONFIGURATION_FILE | grep value | sed -e 's/<value>//;s/<\/value>//' | awk '{print $1}' | tr \\n ", "
        printf "%d\n" "$job_run_time"


#        printf "Job $hadoop_job_id: started at $job_started_at and ended at $job_ended_at\n"
#        printf "Job $hadoop_job_id: running time = %d seconds\n" "$job_run_time"

#       $TASK_TIMES_BASH_SCRIPT $MAP_TIMES_PERL_FILE $hadoop_job_id &>$MAP_TIMES_OUTPUT_FILE
#       $TASK_TIMES_BASH_SCRIPT $REDUCE_TIMES_PERL_FILE $hadoop_job_id &>$REDUCE_TIMES_OUTPUT_FILE

   } &

   # we have to wait here until the above command terminates
   wait $!  #wait for the last background process to exit

#   printf "Exiting experiment input directory %s\n" "$direc"

done

exit 0


