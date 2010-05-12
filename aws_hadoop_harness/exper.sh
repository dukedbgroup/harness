#!/bin/bash

# This script will loop over a set of directories where preprocessing
#   code has placed Hadoop configuration files for each experiment, 
#   and run a customized command (from the bash command line) to run the experiment

# Usage: Only one parameter. 
# Parameter #1 is the file listing THE FULL PATH (not relative path) to all experiment directories

# NOTE: This script runs hadoop command like the following: 
# ${HADOOP_HOME}/bin/hadoop jar ${HADOOP_HOME}/hadoop-*-examples.jar terasort -conf configuration.xml /user/shivnath/tera/in /user/shivnath/tera/out
# NOTE that the "-conf" format is used to specify a Hadoop configuration file in the 
#  command line. This format will work only if the main Java class that is run implements
#  the Tool interface. 

##########################################################################

# Variables that will need to be adjusted to ensure that the appropriate 
#  command gets generated to run the experiment on Hadoop

# The full path to the hadoop binary in the hadoop bin directory
declare HADOOP_BIN="${HADOOP_HOME}/bin/hadoop"

# The specification of the jar to run as part of the hadoop command
declare JAR_SPECIFICATION="jar ${HADOOP_HOME}/hadoop-*-examples.jar terasort"

# The input directory or file for each experiment 
declare HDFS_INPUT_DIR="/user/shivnath/tera/in"

# The output directory for each experiment. This will be removed before each experiment
#   since hadoop needs a new (not created) directory per experiment
declare HDFS_OUTPUT_DIR="/user/shivnath/tera/out"

##########################################################################

# Variables below should not need to be changed

# The name of the file (in each experiment directory) specifying the parameter configuration.
#   The preprocessing code creates this file per experiment/directory, so be careful
#   if you want to change this variable (that means you will need to change the preprocessing
#   code as well)
declare XML_CONFIGURATION_FILE="configuration.xml"

# The output of the hadoop command is written to this file (in each experiment directory)
declare EXPERIMENT_OUTPUT_FILE="output.txt"

##########################################################################

#Check Usage
if [ $# -ne 1 ] ; then
    printf "Usage: Parameter #1 is the file listing THE FULL PATH (not relative path) to all directories\n"
    exit 0
fi

declare CURR_DIR=`pwd`

# Check whether parameters have been specified correctly

if test ! -e $HADOOP_BIN; then
    printf "Specified Hadoop binary (hadoop) does not exist\n"
    printf "Exiting\n"
    exit 0
fi

if test ! -x $HADOOP_BIN; then
    printf "Specified Hadoop binary (hadoop) is not executable\n"
    printf "Exiting\n"
    exit 0
fi

# the file listing all input directories (that will be read later)
declare INPUT_DIR_FILE=$1

if test ! -e $INPUT_DIR_FILE; then
    printf "Invalid file listing all input directories\n"
    printf "Exiting\n"
    exit 0
fi

##################################################################
##################################################################

# the loop that creates the environment and runs each experiment

declare direc
declare hadoop_command

exec 3< $INPUT_DIR_FILE

while read direc <&3 ; do

   printf "Entering experiment input directory %s\n" "$direc"

   cd $direc

   if test ! -e $XML_CONFIGURATION_FILE; then
      printf "Hadoop configuration file %s does not exist in the experiment directory %s\n" "$XML_CONFIGURATION_FILE" "$direc"
      printf "Skipping this experiment\n"
      continue
   fi

   # Remove the output directory if it exists
   # example: /vol/local/hadoop1/hadoop-0.20.1/bin/hadoop fs -rmr /user/shivnath/tera/out"
   hadoop_command="$HADOOP_BIN fs -rmr $HDFS_OUTPUT_DIR"

   printf "Going to run the command: %s\n" "$hadoop_command"

   $hadoop_command

   printf "Finished running the command: %s\n" "$hadoop_command"

   # Run the experiment
   # example: /vol/local/hadoop1/hadoop-0.20.1/bin/hadoop jar /vol/local/hadoop1/hadoop-0.20.1/hadoop-0.20.1-examples.jar terasort -conf configuration.xml /user/shivnath/tera/in /user/shivnath/tera/out

   hadoop_command="$HADOOP_BIN $JAR_SPECIFICATION -conf $XML_CONFIGURATION_FILE $HDFS_INPUT_DIR $HDFS_OUTPUT_DIR" 
   printf "Going to run the command: %s\n" "$hadoop_command"

   $hadoop_command >& $direc/$EXPERIMENT_OUTPUT_FILE &

   # we have to wait here until the above command terminates
   wait $!  #wait for the last background process to exit

   printf "Finished running the command: %s\n" "$hadoop_command"
   printf "Exiting experiment input directory %s\n" "$direc"
   cd $CURR_DIR

done


exit 0


