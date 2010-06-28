#!/bin/bash

# Given a BTrace script, compile it and deploy the compiled .class file 
#     to all slave hosts. 


##########################################################################
##########################################################################

usage0="Purpose: Given a BTrace script, compile it & deploy compiled .class file on all slaves"
usage1="Usage: $0 btrace_java_script [full_path_to_output_class_file]"
usage2="Requirements:"
usage3="- btrace_java_script should have .java extension and NOT have a package definition"
usage4="-   that causes .class file to be written to directory other than current working dir"
usage5="- BTRACE_HOME should be defined as an environmental variable"
usage6="- By default, compiled file is deployed as <BTRACE_HOME>/scripts/Profile.class"


# if no args specified, show usage
if [ $# -le 0 -o $# -gt 2 ]; then
  echo
  echo $usage0
  echo $usage1
  echo $usage2
  echo $usage3
  echo $usage4
  echo $usage5
  echo $usage6
  echo
  exit 1
fi

##########################################################################
##########################################################################

if [ -z $BTRACE_HOME ]; then
  echo "Error: The environmental variable BTRACE_HOME is not set"
  printf "Exiting\n"
  exit -1
fi

if [ ! -x "$BTRACE_HOME/bin/btracec" ]; then
  echo "Error: BTrace compiler ${BTRACE_HOME}/bin/btracec does not exist or is not executable"
  printf "Exiting\n"
  exit -1
fi

if [ $# -eq 2 ]; then
#  User-specified file to deploy the compiled BTrace .class file to 
  PROFILE_CLASS_FILE="$2"
else 
# The compiled BTrace .class file is copied here by default on all EC2 slave nodes
  PROFILE_CLASS_FILE="${BTRACE_HOME}/scripts/Profile.class"
fi

# The list of slaves in this Hadoop cluster. Same format as the slaves file in Hadoop -- one slave per line 
HOSTLIST="/root/SLAVE_NAMES.txt"
	
# Definition of the HADOOP_SSH_OPTS and HADOOP_SLAVE_SLEEP variables
HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-$HADOOP_HOME/conf}"
if [ -f "${HADOOP_CONF_DIR}/hadoop-env.sh" ]; then
  . "${HADOOP_CONF_DIR}/hadoop-env.sh"
fi

##########################################################################
##########################################################################

if test ! -e $1; then
    printf "Specified BTrace Java Script does not exist\n"
    printf "Exiting\n"
    exit -1
fi

# get the file name from the (possible) full specified 
btrace_java_file=`basename "$1"`

# get extension; everything after last '.'
ext=${btrace_java_file##*.}

if [ $ext != "java" ]; then
    printf "Specified script does not have a .java extension\n"
    printf "Exiting\n"
    exit -1
fi

# ${string%substring} -- Deletes shortest match of $substring from back of $string
btrace_class_name=${btrace_java_file%.java}

echo "btrace_java_file = $btrace_java_file"
echo "btrace_class_name = $btrace_class_name"

# compile the file 
$BTRACE_HOME/bin/btracec "$1"

if [ ! -e "${btrace_class_name}.class" ]; then
  echo "Error: ${btrace_class_name}.class file not found. Compilation failed"
  echo "NOTE: $btrace_java_file should NOT have a package definition that causes"
  echo "   .class file to be written to a directory other than current working directory"
  printf "Exiting\n"
  exit -1
fi

exit 0

#  For each slave host
for slave in `cat "$HOSTLIST"|sed  "s/#.*$//;/^$/d"`; do
  
 {
     # copy the compiled file to each slave host
     scp ${btrace_class_name}.class $slave:${PROFILE_CLASS_FILE} 2>&1 | sed "s/^/$slave: /"

     ssh $HADOOP_SSH_OPTS $slave "ls -al ${PROFILE_CLASS_FILE}" 2>&1 | sed "s/^/$slave: /"

     if [ "$HADOOP_SLAVE_SLEEP" != "" ]; then
       sleep $HADOOP_SLAVE_SLEEP
     fi
 } &

done

wait
