#!/usr/bin/env bash

################################################################################
# Script that is run on each EC2 instance used as a Hadoop node
################################################################################

################################################################################
# Initialize variables
################################################################################

# Slaves are started after the master, and are told its address by sending a
# modified copy of this file which sets the MASTER_HOST variable. 
# A node  knows if it is the master or not by inspecting the security group
# name. If it is the master then it retrieves its address using instance data.
MASTER_HOST=%MASTER_HOST% # Interpolated before being sent to EC2 node
SECURITY_GROUPS=`wget -q -O - http://169.254.169.254/latest/meta-data/security-groups`
IS_MASTER=`echo $SECURITY_GROUPS | awk '{ a = match ($0, "-master$"); if (a) print "true"; else print "false"; }'`
if [ "$IS_MASTER" == "true" ]; then
 MASTER_HOST=`wget -q -O - http://169.254.169.254/latest/meta-data/local-hostname`
fi

HADOOP_HOME=`ls -d /usr/local/hadoop-*`

#set the SPARK MASTER INFO in the shark conf
#SHARK_HOME=`ls -d /usr/local/shark-*`
SPARK_HOME=`ls -d /usr/local/spark-*`

CLEANED_MASTER_HOST=`echo $MASTER_HOST | awk 'BEGIN { FS = "." } ; { print $1 }'`
#sed -i "s/MASTER_IP/${CLEANED_MASTER_HOST}/g" $SHARK_HOME/conf/shark-env.sh
echo "export SPARK_MASTER_IP=${CLEANED_MASTER_HOST}">> $SPARK_HOME/conf/spark-env.sh

################################################################################
# Hadoop configuration
# Modify this section to customize your Hadoop cluster.
################################################################################

cat > $HADOOP_HOME/conf/core-site.xml <<EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>

<property>
  <name>hadoop.tmp.dir</name>
  <value>/vertica/data/hadoop</value>
</property>

<property>
  <name>fs.default.name</name>
  <value>hdfs://$MASTER_HOST:50001</value>
</property>

</configuration>
EOF

cat > $HADOOP_HOME/conf/hdfs-site.xml <<EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>

<property>
  <name>dfs.client.block.write.retries</name>
  <value>3</value>
</property>

<property>
  <name>dfs.block.size</name>
<!--  <value>536870912</value>-->
<value>134217728</value>
</property>
<property>
  <name>dfs.replication</name>
  <value>2</value>
</property>
<property>
  <name>dfs.data.dir</name>
  <value>/vertica/data/hadoop/dfs/data</value><!--,/data/hadoop/dfs/data</value>-->
</property>

</configuration>
EOF

cat > $HADOOP_HOME/conf/mapred-site.xml <<EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>

<property>
  <name>mapred.job.tracker</name>
  <value>hdfs://$MASTER_HOST:50002</value>
</property>

<property>
  <name>mapred.local.dir</name>
  <value>/vertica/data/hadoop/mapred/local</value>
</property>

<property>
  <name>tasktracker.http.threads</name>
  <value>80</value>
</property>

<property>
  <name>mapred.tasktracker.map.tasks.maximum</name>
  <value>8</value>
</property>

<property>
  <name>mapred.tasktracker.reduce.tasks.maximum</name>
  <value>4</value>
</property>

<property>
  <name>mapred.child.java.opts</name>
<!--  <value>-Xmx1536m</value>-->
  <value>-Xmx1024m</value>
</property>

<property>
  <name>io.sort.mb</name>
  <value>300</value>
</property>

</configuration>
EOF

################################################################################
# Hive configuration
# Modify this section to customize your Hadoop cluster.
################################################################################
cat > $HIVE_HOME/conf/hive-site.xml  <<'EOF'

<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<!-- Put site-specific property overrides in this file. -->

<configuration>

  <property>
    <name>hive.exec.scratchdir</name>
    <value>/vertica/data/hive/tmp/hive-${user.name}</value>
  </property>

  <property>
    <name>hive.exec.local.scratchdir</name>
    <value>/vertica/data/hive/tmp/${user.name}</value>
  </property>

  <property>
    <name>hive.querylog.location</name>
    <value>/vertica/data/hive/log/${user.name}</value>
  </property>

</configuration>
EOF


################################################################################
# Bigframe configuration
# Modify this section to customize your Bigframe.
################################################################################

cat > /root/BigFrame/conf/config.sh <<'EOF'
#!/usr/bin/env bash

###################################################################
# The BigFrame configuration parameters
#
# Used to set the user-defined parameters in BigFrame.
#
# Author: Andy He
# Date:   June 16, 2013
###################################################################

###################################################################
# GLOBAL PARAMETERS USED BY DATA GENERATOR (REQUIRED)
###################################################################

# The Hadoop Home Directory
HADOOP_HOME=$HADOOP_HOME
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.hadoop.home=${HADOOP_HOME}"

# The Hadoop slave file
HADOOP_SLAVES=$HADOOP_HOME/conf/slaves
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.hadoop.slaves=${HADOOP_SLAVES}"

# Local Directory to store the temporary TPCDS generated files
TPCDS_LOCAL=/vertica/data/hadoop/tpcds_tmp
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.tpcds.local=${TPCDS_LOCAL}"

# Local Directory to store the itermediate data used for data refershing
REFRESH_LOCAL=~/bigframe_refresh_data
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.refresh.local=${REFRESH_LOCAL}"
EOF
cat >> /root/BigFrame/conf/config.sh <<EOF
# Global Output Path
export OUTPUT_PATH="hdfs://$MASTER_HOST:50001/test_output"
EOF

cat > /root/BigFrame/conf/hadoop-env.sh <<EOF
#!/usr/bin/env bash

######################### HADOOP RELATED ##########################
# The HDFS Root Directory to store the generated data
HDFS_ROOT_DIR="hdfs://$MASTER_HOST:50001/user/root"
EOF
cat >> /root/BigFrame/conf/hadoop-env.sh <<'EOF'
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.hdfs.root.dir=${HDFS_ROOT_DIR}"

# The Hive HOME Directory
HIVE_HOME=$HIVE_HOME
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.hive.home=${HIVE_HOME}"
EOF
cat >> /root/BigFrame/conf/hadoop-env.sh <<EOF

# The Hive JDBC Server Address
HIVE_JDBC_SERVER="jdbc:hive://$MASTER_HOST:10000/default"
EOF
cat >> /root/BigFrame/conf/hadoop-env.sh <<'EOF'
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.hive.jdbc.server=${HIVE_JDBC_SERVER}"                                                                                                                                                                        
EOF

cat > /root/BigFrame/conf/spark-env.sh <<'EOF'

#!/usr/bin/env bash

######################### SPARK RELATED ##########################

# Path of Spark installation home. 
export SPARK_HOME="/usr/local/spark-0.8.0"

# Path of Scala installation home.
export SCALA_HOME="/usr/local/scala-2.9.3"

# Spark memory parameters, defaults will be used if unspecified
export SPARK_MEM=13g
export SPARK_WORKER_CORES=8
# export SPARK_WORKER_MEMORY=6g
EOF

cat >> /root/BigFrame/conf/spark-env.sh <<EOF

# Spark connection string, available in Spark master's webUI
export SPARK_CONNECTION_STRING="spark://${CLEANED_MASTER_HOST}:7077"
EOF

cat >> /root/BigFrame/conf/spark-env.sh <<'EOF'

# The Spark Home Directory
SPARK_HOME=$SPARK_HOME

# The Shark Home
SHARK_HOME=$SHARK_HOME
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.shark.home=${SHARK_HOME}"

# The Spark Master Address
SPARK_MASTER=$SPARK_CONNECTION_STRING
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.spark.master=${SPARK_MASTER}"
EOF

cat >> /root/BigFrame/conf/spark-env.sh <<EOF
# Global Output Path
export OUTPUT_PATH="hdfs://$MASTER_HOST:50001/test_output"
EOF


# Configure Hadoop for Ganglia
# overwrite hadoop-metrics.properties
#cat > $HADOOP_HOME/conf/hadoop-metrics.properties <<EOF

# Ganglia
# we push to the master gmond so hostnames show up properly
#dfs.class=org.apache.hadoop.metrics.ganglia.GangliaContext
#dfs.period=10
#dfs.servers=$MASTER_HOST:8649

#mapred.class=org.apache.hadoop.metrics.ganglia.GangliaContext
#mapred.period=10
#mapred.servers=$MASTER_HOST:8649

#jvm.class=org.apache.hadoop.metrics.ganglia.GangliaContext
#jvm.period=10
#jvm.servers=$MASTER_HOST:8649
#EOF

################################################################################
# Start services
################################################################################

[ ! -f /etc/hosts ] &&  echo "127.0.0.1 localhost" > /etc/hosts

mkdir -p /vertica/data/hadoop/logs

# not set on boot
export USER="root"

if [ "$IS_MASTER" == "true" ]; then
  # MASTER
  # Create Pig log directory
  #[ ! -e /mnt/pig/logs ] && mkdir -p /mnt/pig/logs

  # Prep Ganglia
  #sed -i --follow-symlinks -e "s|\( *mcast_join *=.*\)|#\1|" \
  #       -e "s|\( *bind *=.*\)|#\1|" \
  #       -e "s|\( *mute *=.*\)|  mute = yes|" \
  #       -e "s|\( *location *=.*\)|  location = \"master-node\"|" \
  #       /etc/gmond.conf
  #mkdir -p /mnt/ganglia/rrds
  #chown -R ganglia:ganglia /mnt/ganglia/rrds
  #rm -rf /var/lib/ganglia; cd /var/lib; ln -s /mnt/ganglia ganglia; cd
  #service gmond start
  #service gmetad start
  #apachectl start

  #Start the MySql Daemon
  #service mysqld start

  # Hadoop
  # only format on first boot
  [ ! -e /vertica/data/hadoop/dfs ] && "$HADOOP_HOME"/bin/hadoop namenode -format

  "$HADOOP_HOME"/bin/hadoop-daemon.sh start namenode
  "$HADOOP_HOME"/bin/hadoop-daemon.sh start jobtracker
  "$SPARK_HOME"/bin/spark-config.sh
  "$SPARK_HOME"/bin/start-master.sh
else
  # SLAVE
  # Prep Ganglia
  #sed -i --follow-symlinks -e "s|\( *mcast_join *=.*\)|#\1|" \
  #       -e "s|\( *bind *=.*\)|#\1|" \
  #       -e "s|\(udp_send_channel {\)|\1\n  host=$MASTER_HOST|" \
  #       /etc/gmond.conf
  #service gmond start
  #Have to sleep a little bit before restarting because for some reason
  #this is the only way before the slave starts sending metric data
  #sleep 10
  #/etc/init.d/gmond restart

  # Hadoop
  "$HADOOP_HOME"/bin/hadoop-daemon.sh start datanode
  "$HADOOP_HOME"/bin/hadoop-daemon.sh start tasktracker
  "$SPARK_HOME"/bin/spark-config.sh
  "$SPARK_HOME"/spark-class org.apache.spark.deploy.worker.Worker spark://${CLEANED_MASTER_HOST}:7077 &
fi

# Run this script on next boot
rm -f /var/ec2/ec2-run-user-data.*
