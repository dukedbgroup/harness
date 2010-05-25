#!/bin/bash

# Run a given perl script on all slave hosts. Follows same format
#  and initialization routines like the slaves.sh file

##########################################################################
##########################################################################

# The perl executable
PERL_BIN="/usr/bin/perl"

# The perl script will be copied to the ${HADOOP_LOG_DIR} of each slave node before execution (and then deleted)
#    /mnt/hadoop/logs is the log dir on EC2 nodes
HADOOP_LOG_DIR="${HADOOP_LOG_DIR:-/mnt/hadoop/logs}"

# The list of slaves in this Hadoop cluster. Same format as the slaves file in Hadoop -- one slave per line 
HOSTLIST="/root/aws_hadoop_harness/SLAVE_NAMES.txt"
	
# Definition of the HADOOP_SSH_OPTS and HADOOP_SLAVE_SLEEP variables
HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-$HADOOP_HOME/conf}"
if [ -f "${HADOOP_CONF_DIR}/hadoop-env.sh" ]; then
  . "${HADOOP_CONF_DIR}/hadoop-env.sh"
fi

##########################################################################
##########################################################################

usage0="Purpose: Run a given perl script on all slave hosts"
usage1="Usage: $0 perl_script [parameters to perl_script]"
usage2="Requirements:"
usage3="(i) The perl_script should have a .pl extension. Also set the PERL_BIN variable (assumed to be same on all hosts) in $0"
usage4="(ii) The perl script will be copied to the ${HADOOP_LOG_DIR} of each slave node before execution (and then deleted)"

# if no args specified, show usage
if [ $# -le 0 ]; then
  echo
  echo $usage0
  echo $usage1
  echo $usage2
  echo $usage3
  echo $usage4
  echo
  exit 1
fi

if test ! -e $1; then
    printf "Specified perl script does not exist\n"
    printf "Exiting\n"
    exit 0
fi

if test ! -e $PERL_BIN; then
    printf "%s does not exist\n" "$PERL_BIN"
    printf "Exiting\n"
    exit 0
fi

if test ! -e $HADOOP_LOG_DIR; then
    printf "%s does not exist\n" "$HADOOP_LOG_DIR"
    printf "Exiting\n"
    exit 0
fi

perl_script="$1"
# get extension; everything after last '.'
ext=${perl_script##*.}

if [ $ext != "pl" ]; then
    printf "Specified perl script does not have a .pl extension\n"
    printf "Exiting\n"
    exit 0
fi

# basename
perl_base_file_name=`basename "$perl_script"`
#printf "%s\n" "$perl_base_file_name"

# This will get rid of the name of the parameter script among the input parameters,
#   so that $"${@}" will give the parameters to the perl script
shift 

#  For each slave host
for slave in `cat "$HOSTLIST"|sed  "s/#.*$//;/^$/d"`; do
  
 {
     # copy the perl script to the log directory of the slave host
     scp $perl_script $slave:${HADOOP_LOG_DIR} 2>&1 | sed "s/^/$slave: /"

     ssh $HADOOP_SSH_OPTS $slave "ls -al ${HADOOP_LOG_DIR}/$perl_base_file_name" 2>&1 | sed "s/^/$slave: /"

     ssh $HADOOP_SSH_OPTS $slave "cd ${HADOOP_LOG_DIR}; $PERL_BIN $perl_base_file_name" $"${@}" 2>&1 | sed "s/^/$slave: /"

     # Finished processing -- delete remote script
     ssh $HADOOP_SSH_OPTS $slave "rm -rf ${HADOOP_LOG_DIR}/$perl_base_file_name" 2>&1 | sed "s/^/$slave: /"

     if [ "$HADOOP_SLAVE_SLEEP" != "" ]; then
       sleep $HADOOP_SLAVE_SLEEP
     fi
 } &

done

wait
