# Set environment variables for running Hadoop on Amazon EC2 here. All are required.

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Your Amazon Account Number.
AWS_ACCOUNT_ID=${AWS_USER_ID}

# Your Amazon AWS access key. 
#  Should already be defined as a global environmental variable 
#     (e.g., in ${HOME}/.my-bash_profile) if you followed 
#     the instructions in the README. Hence commented out.
#AWS_ACCESS_KEY_ID=

# Your Amazon AWS secret access key. 
#  Should already be defined as a global environmental variable 
#     (e.g., in ${HOME}/.my-bash_profile) if you followed 
#     the instructions in the README. Hence commented out.
#AWS_SECRET_ACCESS_KEY=

# Location of EC2 keys.
#  $EC2_PRIVATE_KEY should be defined as a global environmental variable 
#     (e.g., in ${HOME}/.my-bash_profile) if you followed 
#     the instructions in the README
EC2_KEYDIR=`dirname "$EC2_PRIVATE_KEY"`

# The EC2 key name used to launch instances. Change it as needed. 
#  Should already be defined as a global environmental variable 
KEY_NAME="${EC2_KEYPAIR_NAME}"

# Where your EC2 private key is stored (created, for example, when following the 
#    Amazon Getting Started guide).
# Build from the two variables from above
PRIVATE_KEY_PATH=`echo "$EC2_KEYDIR"/"$KEY_NAME"`

# The version of Hadoop to use.
#  Note: HADOOP_VERSION has to be 0.19.0 or less, 0.20.2, or 0.20.203.0. AMIs can be accessed 
#    for these versions only. Intermediate versions are not supported. 
#    See launch-hadoop-master and launch-hadoop-slaves for how the AMI is 
#      selected based on HADOOP_VERSION
#HADOOP_VERSION=0.19.0
HADOOP_VERSION=0.20.2
#HADOOP_VERSION=0.20.203.0

# The EC2 instance type: m1.small, m1.large, m1.xlarge, c1.medium, c1.xlarge, cc1.4xlarge
#  NOTE: we do not support AMIs for all types of instances
INSTANCE_TYPE="m1.small"
#INSTANCE_TYPE="m1.large"
#INSTANCE_TYPE="m1.xlarge"
#INSTANCE_TYPE="c1.medium"
#INSTANCE_TYPE="c1.xlarge"
#INSTANCE_TYPE="cc1.4xlarge"

# The AMI image to use with HADOOP_VERSION 0.20.2 or 0.20.203.0
# If INSTANCE_TYPE is "m1.small" or "c1.medium", AMI_IMAGE_32 is used.
# Otherwise, AMI_IMAGE_64 is used.
#    AMI ami-5729c03e: Ned created with Hadoop 0.20.2 (32 bit)
#    AMI ami-58689831: Harold created with Hadoop 20 Warehouse (64 bit)
#    AMI ami-2817ff41: Shivnath created with Hadoop 0.20.2, Ganglia (32 bit)
#    AMI ami-a0ee12c9: Fei created with Hadoop 0.20.2, Ganglia (64 bit)
AMI_IMAGE_32="ami-2817ff41"
AMI_IMAGE_64="ami-a0ee12c9"

#The type of framework in the image (HADOOP OR SPARK)
FRAMEWORK_TYPE="HADOOP"

# Import local settings if they exists and OVEWRITE the defaults
bin=`dirname "$0"`
bin=`cd "$bin"; pwd`
if [[ -f "$bin"/local_ec2_settings.sh ]] 
then
  . "$bin"/local_ec2_settings.sh 
fi

###################################################################################
###################################################################################
###################################################################################
#
# Variables below usually need not be changed
#
###################################################################################
###################################################################################
###################################################################################

# If $FORCE_INSTANCE_TYPE is defined, OVERWRITE the above setting.
if [ ! -z $FORCE_INSTANCE_TYPE ]; then
   INSTANCE_TYPE=$FORCE_INSTANCE_TYPE
fi

# SSH options used when connecting to EC2 instances.
SSH_OPTS=`echo -i "$PRIVATE_KEY_PATH" -o StrictHostKeyChecking=no -o ServerAliveInterval=30`

# The script to run on instance boot.
if [ $HADOOP_VERSION == "0.20.2" -o $HADOOP_VERSION == "0.20.203.0" ]; then
   if [ "$INSTANCE_TYPE" == "m1.small" ]; then
      USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-m1.small.sh
   elif [ "$INSTANCE_TYPE" == "m1.large" ]; then
      if [ "$FRAMEWORK_TYPE" == "SPARK" ]; then
         USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-spark-m1.large.sh
      else
         USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-m1.large.sh
      fi   
   elif [ "$INSTANCE_TYPE" == "m1.xlarge" ]; then
      if [ "$FRAMEWORK_TYPE" == "SPARK" ]; then
         USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-spark-m1.xlarge.sh
      elif [ "$FRAMEWORK_TYPE" == "BIGFRAME" ]; then
        USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-bigframe-m1.xlarge.sh
      else
         USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-m1.xlarge.sh
      fi
   elif [ "$INSTANCE_TYPE" == "m3.xlarge" ]; then
      if [ "$FRAMEWORK_TYPE" == "SPARK" ]; then
        USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-bigframe-m3.xlarge.sh
      fi   
   elif [ "$INSTANCE_TYPE" == "c1.medium" ]; then
      USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-c1.medium.sh
   elif [ "$INSTANCE_TYPE" == "c1.xlarge" ]; then
      if [ "$FRAMEWORK_TYPE" == "SPARK" ]; then
        USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-spark-c1.xlarge.sh
      else
        USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-c1.xlarge.sh
      fi
   elif [ "$INSTANCE_TYPE" == "cc1.4xlarge" ]; then
      if [ "$FRAMEWORK_TYPE" == "SPARK" ]; then
        USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-spark-cc1.4xlarge.sh
      else
        USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-cc1.4xlarge.sh
      fi
   else
      if [ "$FRAMEWORK_TYPE" == "SPARK" ]; then
         USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-spark-other.type.sh
      else
         USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-other.type.sh
      fi
   fi
else 
   USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-remote-pre-0.20.0.sh
fi

if [ "$FRAMEWORK_TYPE" == "THOTH" ]; then
   USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-0.20.0-THOTH-m3.xlarge.sh
fi

if [ "$FRAMEWORK_TYPE" == "ROBUS" ]; then
   USER_DATA_FILE=hadoop-ec2-init/hadoop-ec2-init-1.2.1-ROBUS-m3.xlarge.sh
fi


# The Amazon S3 bucket where the Hadoop AMI is stored. Used only for HADOOP_VERSION <= 0.19.0 
# The default value is for public images, so can be left if you are using running a public image.
# Change this value only if you are creating your own (private) AMI
# so you can store it in a bucket you own.
S3_BUCKET=hadoop-images

# Enable public access to JobTracker and TaskTracker web interfaces
ENABLE_WEB_PORTS=true

# The EC2 group master name. CLUSTER is set by calling scripts
CLUSTER_MASTER=$CLUSTER-master

# Cached values for a given cluster
MASTER_PRIVATE_IP_PATH=~/.hadooop-private-$CLUSTER_MASTER
MASTER_IP_PATH=~/.hadooop-$CLUSTER_MASTER
MASTER_ZONE_PATH=~/.hadooop-zone-$CLUSTER_MASTER

######################################################################
#
# The following variables are primarily used when creating an AMI.
#

# The version number of the installed JDK.
JAVA_VERSION=1.6.0_20

# SUPPORTED_ARCHITECTURES = ['i386', 'x86_64']
# The download URL for the Sun JDK. Visit http://java.sun.com/javase/downloads/index.jsp and get the URL for the "Linux self-extracting file".
if [ "$INSTANCE_TYPE" == "m1.small" -o "$INSTANCE_TYPE" == "c1.medium" ]; then
  ARCH='i386'
  BASE_AMI_IMAGE="ami-2b5fba42"  # ec2-public-images/fedora-8-i386-base-v1.07.manifest.xml
  JAVA_BINARY_URL=''
else
  ARCH='x86_64'
  BASE_AMI_IMAGE="ami-2a5fba43"  # ec2-public-images/fedora-8-x86_64-base-v1.07.manifest.xml
  JAVA_BINARY_URL=''
fi

if [ "$INSTANCE_TYPE" == "c1.medium" ]; then
  AMI_KERNEL=aki-9b00e5f2 # ec2-public-images/vmlinuz-2.6.18-xenU-ec2-v1.0.i386.aki.manifest.xml
fi

# Specifying the kernel caused issues when launching a c1.xlarge instance
#if [ "$INSTANCE_TYPE" == "c1.xlarge" ]; then
#  AMI_KERNEL=aki-9800e5f1 # ec2-public-images/vmlinuz-2.6.18-xenU-ec2-v1.0.x86_64.aki.manifest.xml
#fi

if [ "$AMI_KERNEL" != "" ]; then
  KERNEL_ARG="--kernel ${AMI_KERNEL}"
fi

######################################################################

# Finding Hadoop image. See https://wiki.duke.edu/display/hadoop/List+of+Current+AMI+Images
if [ $HADOOP_VERSION == "0.20.2" -o $HADOOP_VERSION == "0.20.203.0" ]; then
   if [ "$INSTANCE_TYPE" == "m1.small" -o "$INSTANCE_TYPE" == "c1.medium" ]; then
      AMI_IMAGE=${AMI_IMAGE_32}
   else
      AMI_IMAGE=${AMI_IMAGE_64}
   fi
else
   # This part will only work for $HADOOP_VERSION being 0.19.0 or less 
   AMI_IMAGE=`ec2-describe-images -a | grep $S3_BUCKET | grep $HADOOP_VERSION | grep $ARCH | grep available | awk '{print $2}'`   
fi
######################################################################
