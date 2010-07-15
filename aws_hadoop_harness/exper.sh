#!/usr/bin/env bash

# This script will loop over a set of directories where preprocessing
#   code has placed Hadoop configuration files for each experiment, 
#   and run a customized bash script to run the experiment
#
# Usage: Only one parameter. 
# Parameter #1 is the file listing the path to all experiment directories

##########################################################################

# The name of the file (in each experiment directory) specifying the parameter configuration
#   for the MapReduce job that will run the experiment.
#   The preprocessing code creates this file per experiment/directory, so be careful
#   if you change this variable (the you need to change the preprocessing code as well)
declare XML_CONF_FILE_NAME="configuration.xml"

# The name of the file (in each experiment directory) specifying the 
#  name of the hadoop command script that will be used to run the experiment
declare HADOOP_JAR_COMMAND_SCRIPT="run_hadoop_jar.sh"

##########################################################################

#Check Usage
if [ $# -ne 1 ] ; then
    printf "Usage: Parameter #1 is the file listing the path to all experiment directories\n"
    exit -1
fi

# the file listing all input directories (that will each be read later)
declare INPUT_DIR_FILE=$1
if test ! -e $INPUT_DIR_FILE; then
    printf "ERROR: Invalid file listing all input experiment directories. exper.sh is exiting\n"
    exit -1
fi

# the loop that goes into each experiment directory and runs the experiment follows 

declare CURR_DIR=`pwd`
declare direc
exec 3< $INPUT_DIR_FILE

while read direc <&3 ; do
    
    # this step ensures that the program will work irrespective of whether 
    #   the paths specified in INPUT_DIR_FILE are absolute or relative paths 
    cd $CURR_DIR
    
    printf "Entering experiment input directory %s\n" "$direc"
    cd $direc
    
   if test ! -e $XML_CONF_FILE_NAME; then
       printf "Hadoop configuration file %s does not exist in the experiment directory %s\n" "$XML_CONF_FILE_NAME" "$direc"
       printf "Skipping this experiment\n"
       printf "Exiting experiment input directory %s\n" "$direc"
       continue
   fi
   
   if test ! -x $HADOOP_JAR_COMMAND_SCRIPT; then
       printf "Script %s does not exist or is not executable in the experiment directory %s\n" "$HADOOP_JAR_COMMAND_SCRIPT" "$direc"
       printf "Skipping this experiment\n"
       printf "Exiting experiment input directory %s\n" "$direc"
       continue
   fi
   
   # run the script 
   . $HADOOP_JAR_COMMAND_SCRIPT
   
   printf "Exiting experiment input directory %s\n" "$direc"
   
done

cd $CURR_DIR

exit 0


