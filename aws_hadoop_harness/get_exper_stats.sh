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

exec 3< $INPUT_DIR_FILE

while read direc <&3 ; do

   printf "Entering experiment input directory %s\n" "$direc"

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
       hadoop_job_id=`grep "Running" $EXPERIMENT_OUTPUT_FILE | sed 's/.*\(job[0-9_]\+\)$/\1/'`

       $TASK_TIMES_BASH_SCRIPT $MAP_TIMES_PERL_FILE $hadoop_job_id &>$MAP_TIMES_OUTPUT_FILE

       $TASK_TIMES_BASH_SCRIPT $REDUCE_TIMES_PERL_FILE $hadoop_job_id &>$REDUCE_TIMES_OUTPUT_FILE
   } &

   # we have to wait here until the above command terminates
   wait $!  #wait for the last background process to exit

   printf "Exiting experiment input directory %s\n" "$direc"

done

exit 0


