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

HADOOP_HOME=`ls -d /home/ec2-user/hadoop-*`
SPARK_HOME=`ls -d /home/ec2-user/spark-*`
HIVE_HOME=`ls -d /home/ec2-user/hive-*`
BIGFRAME_HOME=`ls -d /thoth/BigFrame` 


CLEANED_MASTER_HOST=`echo $MASTER_HOST | awk 'BEGIN { FS = "." } ; { print $1 }'`
#sed -i "s/MASTER_IP/${CLEANED_MASTER_HOST}/g" $SHARK_HOME/conf/shark-env.sh
#echo "export SPARK_MASTER_IP=${CLEANED_MASTER_HOST}">> $SPARK_HOME/conf/spark-env.sh

cat > $SPARK_HOME/conf/spark-env.sh <<EOF
export SPARK_MASTER_IP=${CLEANED_MASTER_HOST}
export SPARK_WORKER_MEMORY=13g
export SPARK_WORKER_CORES=4
EOF



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
  <value>/thoth/data/hadoop</value>
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
         <name>dfs.replication</name>
         <value>2</value>
     </property>
     <property>
         <name>dfs.name.dir</name>
         <value>/thoth/dfs/name</value>
     </property>
     <property>
         <name>dfs.data.dir</name>
         <value>/thoth/dfs/data</value>
     </property>
     <property>
         <name>dfs.namenode.handler.count</name>
         <value>40</value>
     </property>
     <property>
         <name>dfs.namenode.secondary.http-address</name>
         <value>0.0.0.0:50090</value>
     </property>
     <property>
         <name>dfs.datanode.address</name>
         <value>0.0.0.0:51010</value>
     </property>
     <property>
         <name>dfs.datanode.http.address</name>
         <value>0.0.0.0:51075</value>
     </property>
     <property>
         <name>dfs.datanode.ipc.address</name>
         <value>0.0.0.0:51020</value>
     </property>
     <property>
         <name>dfs.datanode.https.address</name>
         <value>0.0.0.0:51475</value>
     </property>


</configuration>

EOF

cat > $HADOOP_HOME/conf/mapred-site.xml <<EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
     <property>
         <name>mapred.job.tracker</name>
         <value>$MASTER_HOST:50002</value>
     </property>

     <property>
         <name>mapred.local.dir</name>
         <value>/thoth/tmp/hadoop-tmp/mapredlocal</value>
     </property>

     <property>
         <name>mapred.output.dir</name>
         <value>/thoth/tmp/hadoop-tmp/output</value>
     </property>

     <property>
         <name>mapred.work.output.dir</name>
         <value>/thoth/tmp/hadoop-tmp/mapredworkoutput</value>
     </property>

     <property>
        <name>mapred.tasktracker.map.tasks.maximum</name>
        <value>16</value>
        <final>true</final>
     </property>

     <property>
        <name>mapred.tasktracker.reduce.tasks.maximum</name>
        <value>4</value>
        <final>true</final>
     </property>

    <property>
      <name>mapred.map.child.java.opts</name>
      <value>-server -Xmx1024M</value>
    </property>

    <property>
      <name>mapred.reduce.child.java.opts</name>
      <value>-server -Xmx1024M</value>
    </property>

    <property>
      <name>mapred.reduce.parallel.copies</name>
      <value>20</value>
      <description>The default number of parallel transfers run by reduce
      during the copy(shuffle) phase.</description>
    </property>

    <property>
      <name>mapred.job.tracker.handler.count</name>
      <value>60</value>
      <description>
      The number of server threads for the JobTracker. This should be roughly
      4% of the number of tasktracker nodes.
      </description>
    </property>

     <property>
         <name>mapred.task.tracker.http.address</name>
         <value>0.0.0.0:51060</value>
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

<configuration>

  <property>
    <name>hive.querylog.location</name>
    <value>/vertica/data/user/root/log/${user.name}</value>
  </property>

<property>
  <name>mapred.reduce.tasks</name>
  <value>-1</value>
    <description>The default number of reduce tasks per job.  Typically set
  to a prime close to the number of available hosts.  Ignored when
  mapred.job.tracker is "local". Hadoop set this to 1 by default, whereas hive uses -1 as its default value.
  By setting this property to -1, Hive will automatically figure out what should be the number of reducers.
  </description>
</property>

<property>
  <name>hive.exec.reducers.bytes.per.reducer</name>
  <value>1000000000</value>
  <description>size per reducer.The default is 1G, i.e if the input size is 10G, it will use 10 reducers.</description>
</property>

<property>
  <name>hive.exec.reducers.max</name>
  <value>999</value>
  <description>max number of reducers will be used. If the one
	specified in the configuration parameter mapred.reduce.tasks is
	negative, hive will use this one as the max number of reducers when
	automatically determine number of reducers.</description>
</property>

<property>
  <name>hive.cli.print.header</name>
  <value>false</value>
  <description>Whether to print the names of the columns in query output.</description>
</property>

<property>
  <name>hive.cli.print.current.db</name>
  <value>false</value>
  <description>Whether to include the current database in the hive prompt.</description>
</property>

<property>
  <name>hive.exec.scratchdir</name>
  <value>/thoth/tmp/hive-${user.name}</value>
  <description>Scratch space for Hive jobs</description>
</property>

<property>
  <name>hive.test.mode</name>
  <value>false</value>
  <description>whether hive is running in test mode. If yes, it turns on sampling and prefixes the output tablename</description>
</property>

<property>
  <name>hive.test.mode.prefix</name>
  <value>test_</value>
  <description>if hive is running in test mode, prefixes the output table by this string</description>
</property>

<!-- If the input table is not bucketed, the denominator of the tablesample is determinied by the parameter below   -->
<!-- For example, the following query:                                                                              -->
<!--   INSERT OVERWRITE TABLE dest                                                                                  -->
<!--   SELECT col1 from src                                                                                         -->
<!-- would be converted to                                                                                          -->
<!--   INSERT OVERWRITE TABLE test_dest                                                                             -->
<!--   SELECT col1 from src TABLESAMPLE (BUCKET 1 out of 32 on rand(1))                                             -->
<property>
  <name>hive.test.mode.samplefreq</name>
  <value>32</value>
  <description>if hive is running in test mode and table is not bucketed, sampling frequency</description>
</property>

<property>
  <name>hive.test.mode.nosamplelist</name>
  <value></value>
  <description>if hive is running in test mode, dont sample the above comma seperated list of tables</description>
</property>

<!--property>
  <name>hive.metastore.local</name>
  <value>true</value>
  <description>controls whether to connect to remove metastore server or open a new metastore server in Hive Client JVM</description>
</property-->

<property>
  <name>javax.jdo.option.ConnectionURL</name>
  <value>jdbc:derby:;databaseName=metastore_db;create=true</value>
  <description>JDBC connect string for a JDBC metastore</description>
</property>

<property>
  <name>javax.jdo.option.ConnectionDriverName</name>
  <value>org.apache.derby.jdbc.EmbeddedDriver</value>
  <description>Driver class name for a JDBC metastore</description>
</property>

<property>
  <name>javax.jdo.PersistenceManagerFactoryClass</name>
  <value>org.datanucleus.api.jdo.JDOPersistenceManagerFactory</value>
  <description>class implementing the jdo persistence</description>
</property>

<property>
  <name>javax.jdo.option.DetachAllOnCommit</name>
  <value>true</value>
  <description>detaches all objects from session so that they can be used after transaction is committed</description>
</property>

<property>
  <name>javax.jdo.option.NonTransactionalRead</name>
  <value>true</value>
  <description>reads outside of transactions</description>
</property>

<property>
  <name>javax.jdo.option.ConnectionUserName</name>
  <value>APP</value>
  <description>username to use against metastore database</description>
</property>

<property>
  <name>javax.jdo.option.ConnectionPassword</name>
  <value>mine</value>
  <description>password to use against metastore database</description>
</property>

<property>
  <name>javax.jdo.option.Multithreaded</name>
  <value>true</value>
  <description>Set this to true if multiple threads access metastore through JDO concurrently.</description>
</property>

<property>
  <name>datanucleus.connectionPoolingType</name>
  <value>DBCP</value>
  <description>Uses a DBCP connection pool for JDBC metastore</description>
</property>

<property>
  <name>datanucleus.validateTables</name>
  <value>false</value>
  <description>validates existing schema against code. turn this on if you want to verify existing schema </description>
</property>

<property>
  <name>datanucleus.validateColumns</name>
  <value>false</value>
  <description>validates existing schema against code. turn this on if you want to verify existing schema </description>
</property>

<property>
  <name>datanucleus.validateConstraints</name>
  <value>false</value>
  <description>validates existing schema against code. turn this on if you want to verify existing schema </description>
</property>

<property>
  <name>datanucleus.storeManagerType</name>
  <value>rdbms</value>
  <description>metadata store type</description>
</property>

<property>
  <name>datanucleus.autoCreateSchema</name>
  <value>true</value>
  <description>creates necessary schema on a startup if one doesn't exist. set this to false, after creating it once</description>
</property>

<property>
  <name>datanucleus.autoStartMechanismMode</name>
  <value>checked</value>
  <description>throw exception if metadata tables are incorrect</description>
</property>

<property>
  <name>datanucleus.transactionIsolation</name>
  <value>read-committed</value>
  <description>Default transaction isolation level for identity generation. </description>
</property>

<property>
  <name>datanucleus.cache.level2</name>
  <value>false</value>
  <description>Use a level 2 cache. Turn this off if metadata is changed independently of hive metastore server</description>
</property>

<property>
  <name>datanucleus.cache.level2.type</name>
  <value>SOFT</value>
  <description>SOFT=soft reference based cache, WEAK=weak reference based cache.</description>
</property>

<property>
  <name>datanucleus.identifierFactory</name>
  <value>datanucleus1</value>
  <description>Name of the identifier factory to use when generating table/column names etc. 'datanucleus' is used for backward compatibility</description>
</property>

<property>
  <name>datanucleus.plugin.pluginRegistryBundleCheck</name>
  <value>LOG</value>
  <description>Defines what happens when plugin bundles are found and are duplicated [EXCEPTION|LOG|NONE]</description>
</property>

<property>
  <name>hive.metastore.warehouse.dir</name>
  <value>hdfs://$MASTER_HOST:50001/user/hive/warehouse</value>
  <description>location of default database for the warehouse</description>
</property>

<property>
  <name>hive.metastore.execute.setugi</name>
  <value>false</value>
  <description>In unsecure mode, setting this property to true will cause the metastore to execute DFS operations using the client's reported user and group permissions. Note that this property must be set on both the client and server sides. Further note that its best effort. If client sets its to true and server sets it to false, client setting will be ignored.</description>
</property>

<property>
  <name>hive.metastore.event.listeners</name>
  <value></value>
  <description>list of comma seperated listeners for metastore events.</description>
</property>

<property>
  <name>hive.metastore.partition.inherit.table.properties</name>
  <value></value>
  <description>list of comma seperated keys occurring in table properties which will get inherited to newly created partitions. * implies all the keys will get inherited.</description>
</property>

<property>
  <name>hive.metastore.end.function.listeners</name>
  <value></value>
  <description>list of comma separated listeners for the end of metastore functions.</description>
</property>

<property>
  <name>hive.metastore.event.expiry.duration</name>
  <value>0</value>
  <description>Duration after which events expire from events table (in seconds)</description>
</property>

<property>
  <name>hive.metastore.event.clean.freq</name>
  <value>0</value>
  <description>Frequency at which timer task runs to purge expired events in metastore(in seconds).</description>
</property>

<property>
  <name>hive.metastore.connect.retries</name>
  <value>5</value>
  <description>Number of retries while opening a connection to metastore</description>
</property>

<property>
  <name>hive.metastore.client.connect.retry.delay</name>
  <value>1</value>
  <description>Number of seconds for the client to wait between consecutive connection attempts</description>
</property>

<property>
  <name>hive.metastore.client.socket.timeout</name>
  <value>20</value>
  <description>MetaStore Client socket timeout in seconds</description>
</property>

<property>
  <name>hive.metastore.rawstore.impl</name>
  <value>org.apache.hadoop.hive.metastore.ObjectStore</value>
  <description>Name of the class that implements org.apache.hadoop.hive.metastore.rawstore interface. This class is used to store and retrieval of raw metadata objects such as table, database</description>
</property>

<property>
  <name>hive.metastore.batch.retrieve.max</name>
  <value>300</value>
  <description>Maximum number of objects (tables/partitions) can be retrieved from metastore in one batch. The higher the number, the less the number of round trips is needed to the Hive metastore server, but it may also cause higher memory requirement at the client side.</description>
</property>

<property>
  <name>hive.default.fileformat</name>
  <value>TextFile</value>
  <description>Default file format for CREATE TABLE statement. Options are TextFile and SequenceFile. Users can explicitly say CREATE TABLE ... STORED AS &lt;TEXTFILE|SEQUENCEFILE&gt; to override</description>
</property>

<property>
  <name>hive.fileformat.check</name>
  <value>true</value>
  <description>Whether to check file format or not when loading data files</description>
</property>

<property>
  <name>hive.map.aggr</name>
  <value>true</value>
  <description>Whether to use map-side aggregation in Hive Group By queries</description>
</property>

<property>
  <name>hive.groupby.skewindata</name>
  <value>false</value>
  <description>Whether there is skew in data to optimize group by queries</description>
</property>

<property>
  <name>hive.groupby.mapaggr.checkinterval</name>
  <value>100000</value>
  <description>Number of rows after which size of the grouping keys/aggregation classes is performed</description>
</property>

<property>
  <name>hive.mapred.local.mem</name>
  <value>0</value>
  <description>For local mode, memory of the mappers/reducers</description>
</property>

<property>
  <name>hive.mapjoin.followby.map.aggr.hash.percentmemory</name>
  <value>0.3</value>
  <description>Portion of total memory to be used by map-side grup aggregation hash table, when this group by is followed by map join</description>
</property>

<property>
  <name>hive.map.aggr.hash.force.flush.memory.threshold</name>
  <value>0.9</value>
  <description>The max memory to be used by map-side grup aggregation hash table, if the memory usage is higher than this number, force to flush data</description>
</property>

<property>
  <name>hive.map.aggr.hash.percentmemory</name>
  <value>0.5</value>
  <description>Portion of total memory to be used by map-side grup aggregation hash table</description>
</property>

<property>
  <name>hive.map.aggr.hash.min.reduction</name>
  <value>0.5</value>
  <description>Hash aggregation will be turned off if the ratio between hash
  table size and input rows is bigger than this number. Set to 1 to make sure
  hash aggregation is never turned off.</description>
</property>

<property>
  <name>hive.optimize.cp</name>
  <value>true</value>
  <description>Whether to enable column pruner</description>
</property>

<property>
  <name>hive.optimize.index.filter</name>
  <value>false</value>
  <description>Whether to enable automatic use of indexes</description>
</property>

<property>
  <name>hive.optimize.index.groupby</name>
  <value>false</value>
  <description>Whether to enable optimization of group-by queries using Aggregate indexes.</description>
</property>

<property>
  <name>hive.optimize.ppd</name>
  <value>true</value>
  <description>Whether to enable predicate pushdown</description>
</property>

<property>
  <name>hive.optimize.ppd.storage</name>
  <value>true</value>
  <description>Whether to push predicates down into storage handlers.  Ignored when hive.optimize.ppd is false.</description>
</property>

<property>
  <name>hive.ppd.recognizetransivity</name>
  <value>true</value>
  <description>Whether to transitively replicate predicate filters over equijoin conditions.</description>
</property>

<property>
  <name>hive.optimize.groupby</name>
  <value>true</value>
  <description>Whether to enable the bucketed group by from bucketed partitions/tables.</description>
</property>

<property>
  <name>hive.multigroupby.singlemr</name>
  <value>false</value>
  <description>Whether to optimize multi group by query to generate single M/R
  job plan. If the multi group by query has common group by keys, it will be
  optimized to generate single M/R job.</description>
</property>
<property>
  <name>hive.join.emit.interval</name>
  <value>1000</value>
  <description>How many rows in the right-most join operand Hive should buffer before emitting the join result. </description>
</property>

<property>
  <name>hive.join.cache.size</name>
  <value>25000</value>
  <description>How many rows in the joining tables (except the streaming table) should be cached in memory. </description>
</property>

<property>
  <name>hive.mapjoin.bucket.cache.size</name>
  <value>100</value>
  <description>How many values in each keys in the map-joined table should be cached in memory. </description>
</property>

<property>
  <name>hive.mapjoin.cache.numrows</name>
  <value>25000</value>
  <description>How many rows should be cached by jdbm for map join. </description>
</property>

<property>
  <name>hive.optimize.skewjoin</name>
  <value>false</value>
  <description>Whether to enable skew join optimization. </description>
</property>

<property>
  <name>hive.skewjoin.key</name>
  <value>100000</value>
  <description>Determine if we get a skew key in join. If we see more
	than the specified number of rows with the same key in join operator,
	we think the key as a skew join key. </description>
</property>

<property>
  <name>hive.skewjoin.mapjoin.map.tasks</name>
  <value>10000</value>
  <description> Determine the number of map task used in the follow up map join job
	for a skew join. It should be used together with hive.skewjoin.mapjoin.min.split
	to perform a fine grained control.</description>
</property>

<property>
  <name>hive.skewjoin.mapjoin.min.split</name>
  <value>33554432</value>
  <description> Determine the number of map task at most used in the follow up map join job
	for a skew join by specifying the minimum split size. It should be used together with
	hive.skewjoin.mapjoin.map.tasks to perform a fine grained control.</description>
</property>

<property>
  <name>hive.mapred.mode</name>
  <value>nonstrict</value>
  <description>The mode in which the hive operations are being performed. In strict mode, some risky queries are not allowed to run</description>
</property>

<property>
  <name>hive.exec.script.maxerrsize</name>
  <value>100000</value>
  <description>Maximum number of bytes a script is allowed to emit to standard error (per map-reduce task). This prevents runaway scripts from filling logs partitions to capacity </description>
</property>

<property>
  <name>hive.exec.script.allow.partial.consumption</name>
  <value>false</value>
  <description> When enabled, this option allows a user script to exit successfully without consuming all the data from the standard input.
  </description>
</property>

<property>
  <name>hive.script.operator.id.env.var</name>
  <value>HIVE_SCRIPT_OPERATOR_ID</value>
  <description> Name of the environment variable that holds the unique script operator ID in the
users transform function (the custom mapper/reducer that the user has specified in the query)
  </description>
</property>

<property>
  <name>hive.exec.compress.output</name>
  <value>false</value>
  <description> This controls whether the final outputs of a query (to a local/hdfs file or a hive table) is compressed. The compression codec and other options are determined from hadoop config variables mapred.output.compress* </description>
</property>

<property>
  <name>hive.exec.compress.intermediate</name>
  <value>false</value>
  <description> This controls whether intermediate files produced by hive between multiple map-reduce jobs are compressed. The compression codec and other options are determined from hadoop config variables mapred.output.compress* </description>
</property>

<property>
  <name>hive.exec.parallel</name>
  <value>false</value>
  <description>Whether to execute jobs in parallel</description>
</property>

<property>
  <name>hive.exec.parallel.thread.number</name>
  <value>8</value>
  <description>How many jobs at most can be executed in parallel</description>
</property>

<property>
  <name>hive.exec.rowoffset</name>
  <value>false</value>
  <description>Whether to provide the row offset virtual column</description>
</property>

<property>
  <name>hive.task.progress</name>
  <value>false</value>
  <description>Whether Hive should periodically update task progress counters during execution.  Enabling this allows task progress to be monitored more closely in the job tracker, but may impose a performance penalty.  This flag is automatically set to true for jobs with hive.exec.dynamic.partition set to true.</description>
</property>

<property>
  <name>hive.hwi.war.file</name>
  <value>lib/hive-hwi-0.9.0.war</value>
  <description>This sets the path to the HWI war file, relative to ${HIVE_HOME}. </description>
</property>

<property>
  <name>hive.hwi.listen.host</name>
  <value>0.0.0.0</value>
  <description>This is the host address the Hive Web Interface will listen on</description>
</property>

<property>
  <name>hive.hwi.listen.port</name>
  <value>9999</value>
  <description>This is the port the Hive Web Interface will listen on</description>
</property>

<property>
  <name>hive.exec.pre.hooks</name>
  <value></value>
  <description>Comma-separated list of pre-execution hooks to be invoked for each statement.  A pre-execution hook is specified as the name of a Java class which implements the org.apache.hadoop.hive.ql.hooks.ExecuteWithHookContext interface.</description>
</property>

<property>
  <name>hive.exec.post.hooks</name>
  <value></value>
  <description>Comma-separated list of post-execution hooks to be invoked for each statement.  A post-execution hook is specified as the name of a Java class which implements the org.apache.hadoop.hive.ql.hooks.ExecuteWithHookContext interface.</description>
</property>

<property>
  <name>hive.exec.failure.hooks</name>
  <value></value>
  <description>Comma-separated list of on-failure hooks to be invoked for each statement.  An on-failure hook is specified as the name of Java class which implements the org.apache.hadoop.hive.ql.hooks.ExecuteWithHookContext interface.</description>
</property>

<property>
  <name>hive.client.stats.publishers</name>
  <value></value>
  <description>Comma-separated list of statistics publishers to be invoked on counters on each job.  A client stats publisher is specified as the name of a Java class which implements the org.apache.hadoop.hive.ql.stats.ClientStatsPublisher interface.</description>
</property>

<property>
  <name>hive.client.stats.counters</name>
  <value></value>
  <description>Subset of counters that should be of interest for hive.client.stats.publishers (when one wants to limit their publishing). Non-display names should be used</description>
</property>

<property>
  <name>hive.merge.mapfiles</name>
  <value>true</value>
  <description>Merge small files at the end of a map-only job</description>
</property>

<property>
  <name>hive.merge.mapredfiles</name>
  <value>false</value>
  <description>Merge small files at the end of a map-reduce job</description>
</property>

<property>
  <name>hive.mergejob.maponly</name>
  <value>true</value>
  <description>Try to generate a map-only job for merging files if CombineHiveInputFormat is supported.</description>
</property>

<property>
  <name>hive.heartbeat.interval</name>
  <value>1000</value>
  <description>Send a heartbeat after this interval - used by mapjoin and filter operators</description>
</property>

<property>
  <name>hive.merge.size.per.task</name>
  <value>256000000</value>
  <description>Size of merged files at the end of the job</description>
</property>

<property>
  <name>hive.merge.smallfiles.avgsize</name>
  <value>16000000</value>
  <description>When the average output file size of a job is less than this number, Hive will start an additional map-reduce job to merge the output files into bigger files.  This is only done for map-only jobs if hive.merge.mapfiles is true, and for map-reduce jobs if hive.merge.mapredfiles is true.</description>
</property>

<property>
  <name>hive.mapjoin.smalltable.filesize</name>
  <value>25000000</value>
  <description>The threshold for the input file size of the small tables; if the file size is smaller than this threshold, it will try to convert the common join into map join</description>
</property>

<property>
  <name>hive.mapjoin.localtask.max.memory.usage</name>
  <value>0.90</value>
  <description>This number means how much memory the local task can take to hold the key/value into in-memory hash table; If the local task's memory usage is more than this number, the local task will be abort by themself. It means the data of small table is too large to be hold in the memory.</description>
</property>

<property>
  <name>hive.mapjoin.followby.gby.localtask.max.memory.usage</name>
  <value>0.55</value>
  <description>This number means how much memory the local task can take to hold the key/value into in-memory hash table when this map join followed by a group by; If the local task's memory usage is more than this number, the local task will be abort by themself. It means the data of small table is too large to be hold in the memory.</description>
</property>

<property>
  <name>hive.mapjoin.check.memory.rows</name>
  <value>100000</value>
  <description>The number means after how many rows processed it needs to check the memory usage</description>
</property>

<property>
  <name>hive.auto.convert.join</name>
  <value>false</value>
  <description>Whether Hive enable the optimization about converting common join into mapjoin based on the input file size</description>
</property>


<property>
  <name>hive.script.auto.progress</name>
  <value>false</value>
  <description>Whether Hive Tranform/Map/Reduce Clause should automatically send progress information to TaskTracker to avoid the task getting killed because of inactivity.  Hive sends progress information when the script is outputting to stderr.  This option removes the need of periodically producing stderr messages, but users should be cautious because this may prevent infinite loops in the scripts to be killed by TaskTracker.  </description>
</property>

<property>
  <name>hive.script.serde</name>
  <value>org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe</value>
  <description>The default serde for trasmitting input data to and reading output data from the user scripts. </description>
</property>

<property>
  <name>hive.script.recordreader</name>
  <value>org.apache.hadoop.hive.ql.exec.TextRecordReader</value>
  <description>The default record reader for reading data from the user scripts. </description>
</property>

<property>
  <name>hive.script.recordwriter</name>
  <value>org.apache.hadoop.hive.ql.exec.TextRecordWriter</value>
  <description>The default record writer for writing data to the user scripts. </description>
</property>

<property>
  <name>hive.input.format</name>
  <value>org.apache.hadoop.hive.ql.io.CombineHiveInputFormat</value>
  <description>The default input format. Set this to HiveInputFormat if you encounter problems with CombineHiveInputFormat.</description>
</property>

<property>
  <name>hive.udtf.auto.progress</name>
  <value>false</value>
  <description>Whether Hive should automatically send progress information to TaskTracker when using UDTF's to prevent the task getting killed because of inactivity.  Users should be cautious because this may prevent TaskTracker from killing tasks with infinte loops.  </description>
</property>

<property>
  <name>hive.mapred.reduce.tasks.speculative.execution</name>
  <value>true</value>
  <description>Whether speculative execution for reducers should be turned on. </description>
</property>

<property>
  <name>hive.exec.counters.pull.interval</name>
  <value>1000</value>
  <description>The interval with which to poll the JobTracker for the counters the running job. The smaller it is the more load there will be on the jobtracker, the higher it is the less granular the caught will be.</description>
</property>

<property>
  <name>hive.enforce.bucketing</name>
  <value>false</value>
  <description>Whether bucketing is enforced. If true, while inserting into the table, bucketing is enforced. </description>
</property>

<property>
  <name>hive.enforce.sorting</name>
  <value>false</value>
  <description>Whether sorting is enforced. If true, while inserting into the table, sorting is enforced. </description>
</property>

<property>
  <name>hive.metastore.ds.connection.url.hook</name>
  <value></value>
  <description>Name of the hook to use for retriving the JDO connection URL. If empty, the value in javax.jdo.option.ConnectionURL is used </description>
</property>

<property>
  <name>hive.metastore.ds.retry.attempts</name>
  <value>1</value>
  <description>The number of times to retry a metastore call if there were a connection error</description>
</property>

<property>
   <name>hive.metastore.ds.retry.interval</name>
   <value>1000</value>
   <description>The number of miliseconds between metastore retry attempts</description>
</property>

<property>
  <name>hive.metastore.server.min.threads</name>
  <value>200</value>
  <description>Minimum number of worker threads in the Thrift server's pool.</description>
</property>

<property>
  <name>hive.metastore.server.max.threads</name>
  <value>100000</value>
  <description>Maximum number of worker threads in the Thrift server's pool.</description>
</property>

<property>
  <name>hive.metastore.server.tcp.keepalive</name>
  <value>true</value>
  <description>Whether to enable TCP keepalive for the metastore server. Keepalive will prevent accumulation of half-open connections.</description>
</property>

<property>
  <name>hive.metastore.sasl.enabled</name>
  <value>false</value>
  <description>If true, the metastore thrift interface will be secured with SASL. Clients must authenticate with Kerberos.</description>
</property>

<property>
  <name>hive.metastore.kerberos.keytab.file</name>
  <value></value>
  <description>The path to the Kerberos Keytab file containing the metastore thrift server's service principal.</description>
</property>

<property>
  <name>hive.metastore.kerberos.principal</name>
  <value>hive-metastore/_HOST@EXAMPLE.COM</value>
  <description>The service principal for the metastore thrift server. The special string _HOST will be replaced automatically with the correct host name.</description>
</property>

<property>
  <name>hive.cluster.delegation.token.store.class</name>
  <value>org.apache.hadoop.hive.thrift.MemoryTokenStore</value>
  <description>The delegation token store implementation. Set to org.apache.hadoop.hive.thrift.ZooKeeperTokenStore for load-balanced cluster.</description>
</property>

<property>
  <name>hive.cluster.delegation.token.store.zookeeper.connectString</name>
  <value>localhost:2181</value>
  <description>The ZooKeeper token store connect string.</description>
</property>

<property>
  <name>hive.cluster.delegation.token.store.zookeeper.znode</name>
  <value>/hive/cluster/delegation</value>
  <description>The root path for token store data.</description>
</property>

<property>
  <name>hive.cluster.delegation.token.store.zookeeper.acl</name>
  <value>sasl:hive/host1@EXAMPLE.COM:cdrwa,sasl:hive/host2@EXAMPLE.COM:cdrwa</value>
  <description>ACL for token store entries. List comma separated all server principals for the cluster.</description>
</property>

<property>
  <name>hive.metastore.cache.pinobjtypes</name>
  <value>Table,StorageDescriptor,SerDeInfo,Partition,Database,Type,FieldSchema,Order</value>
  <description>List of comma separated metastore object types that should be pinned in the cache</description>
</property>

<property>
  <name>hive.optimize.reducededuplication</name>
  <value>true</value>
  <description>Remove extra map-reduce jobs if the data is already clustered by the same key which needs to be used again. This should always be set to true. Since it is a new feature, it has been made configurable.</description>
</property>

<property>
  <name>hive.exec.dynamic.partition</name>
  <value>true</value>
  <description>Whether or not to allow dynamic partitions in DML/DDL.</description>
</property>

<property>
  <name>hive.exec.dynamic.partition.mode</name>
  <value>strict</value>
  <description>In strict mode, the user must specify at least one static partition in case the user accidentally overwrites all partitions.</description>
</property>

<property>
  <name>hive.exec.max.dynamic.partitions</name>
  <value>1000</value>
  <description>Maximum number of dynamic partitions allowed to be created in total.</description>
</property>

<property>
  <name>hive.exec.max.dynamic.partitions.pernode</name>
  <value>100</value>
  <description>Maximum number of dynamic partitions allowed to be created in each mapper/reducer node.</description>
</property>

<property>
  <name>hive.exec.max.created.files</name>
  <value>100000</value>
  <description>Maximum number of HDFS files created by all mappers/reducers in a MapReduce job.</description>
</property>

<property>
  <name>hive.exec.default.partition.name</name>
  <value>__HIVE_DEFAULT_PARTITION__</value>
  <description>The default partition name in case the dynamic partition column value is null/empty string or anyother values that cannot be escaped. This value must not contain any special character used in HDFS URI (e.g., ':', '%', '/' etc). The user has to be aware that the dynamic partition value should not contain this value to avoid confusions.</description>
</property>

<property>
  <name>hive.stats.dbclass</name>
  <value>jdbc:derby</value>
  <description>The default database that stores temporary hive statistics.</description>
</property>

<property>
  <name>hive.stats.autogather</name>
  <value>true</value>
  <description>A flag to gather statistics automatically during the INSERT OVERWRITE command.</description>
</property>

<property>
  <name>hive.stats.jdbcdriver</name>
  <value>org.apache.derby.jdbc.EmbeddedDriver</value>
  <description>The JDBC driver for the database that stores temporary hive statistics.</description>
</property>

<property>
  <name>hive.stats.dbconnectionstring</name>
  <value>jdbc:derby:;databaseName=TempStatsStore;create=true</value>
  <description>The default connection string for the database that stores temporary hive statistics.</description>
</property>

<property>
  <name>hive.stats.default.publisher</name>
  <value></value>
  <description>The Java class (implementing the StatsPublisher interface) that is used by default if hive.stats.dbclass is not JDBC or HBase.</description>
</property>

<property>
  <name>hive.stats.default.aggregator</name>
  <value></value>
  <description>The Java class (implementing the StatsAggregator interface) that is used by default if hive.stats.dbclass is not JDBC or HBase.</description>
</property>

<property>
  <name>hive.stats.jdbc.timeout</name>
  <value>30</value>
  <description>Timeout value (number of seconds) used by JDBC connection and statements.</description>
</property>

<property>
  <name>hive.stats.retries.max</name>
  <value>0</value>
  <description>Maximum number of retries when stats publisher/aggregator got an exception updating intermediate database. Default is no tries on failures.</description>
</property>

<property>
  <name>hive.stats.retries.wait</name>
  <value>3000</value>
  <description>The base waiting window (in milliseconds) before the next retry. The actual wait time is calculated by baseWindow * failues + baseWindow * (failure + 1) * (random number between [0.0,1.0]).</description>
</property>

<property>
  <name>hive.support.concurrency</name>
  <value>false</value>
  <description>Whether hive supports concurrency or not. A zookeeper instance must be up and running for the default hive lock manager to support read-write locks.</description>
</property>

<property>
  <name>hive.lock.numretries</name>
  <value>100</value>
  <description>The number of times you want to try to get all the locks</description>
</property>

<property>
  <name>hive.unlock.numretries</name>
  <value>10</value>
  <description>The number of times you want to retry to do one unlock</description>
</property>

<property>
  <name>hive.lock.sleep.between.retries</name>
  <value>60</value>
  <description>The sleep time (in seconds) between various retries</description>
</property>

<property>
  <name>hive.zookeeper.quorum</name>
  <value></value>
  <description>The list of zookeeper servers to talk to. This is only needed for read/write locks.</description>
</property>

<property>
  <name>hive.zookeeper.client.port</name>
  <value>2181</value>
  <description>The port of zookeeper servers to talk to. This is only needed for read/write locks.</description>
</property>

<property>
  <name>hive.zookeeper.session.timeout</name>
  <value>600000</value>
  <description>Zookeeper client's session timeout. The client is disconnected, and as a result, all locks released, if a heartbeat is not sent in the timeout.</description>
</property>

<property>
  <name>hive.zookeeper.namespace</name>
  <value>hive_zookeeper_namespace</value>
  <description>The parent node under which all zookeeper nodes are created.</description>
</property>

<property>
  <name>hive.zookeeper.clean.extra.nodes</name>
  <value>false</value>
  <description>Clean extra nodes at the end of the session.</description>
</property>

<property>
  <name>fs.har.impl</name>
  <value>org.apache.hadoop.hive.shims.HiveHarFileSystem</value>
  <description>The implementation for accessing Hadoop Archives. Note that this won't be applicable to Hadoop vers less than 0.20</description>
</property>

<property>
  <name>hive.archive.enabled</name>
  <value>false</value>
  <description>Whether archiving operations are permitted</description>
</property>

<property>
  <name>hive.archive.har.parentdir.settable</name>
  <value>false</value>
  <description>In new Hadoop versions, the parent directory must be set while
  creating a HAR. Because this functionality is hard to detect with just version
  numbers, this conf var needs to be set manually.</description>
</property>

<property>
  <name>hive.fetch.output.serde</name>
  <value>org.apache.hadoop.hive.serde2.DelimitedJSONSerDe</value>
  <description>The serde used by FetchTask to serialize the fetch output.</description>
</property>

<property>
  <name>hive.exec.mode.local.auto</name>
  <value>false</value>
  <description> Let hive determine whether to run in local mode automatically </description>
</property>

<property>
  <name>hive.exec.drop.ignorenonexistent</name>
  <value>true</value>
  <description>
    Do not report an error if DROP TABLE/VIEW specifies a non-existent table/view
  </description>
</property>

<property>
  <name>hive.exec.show.job.failure.debug.info</name>
  <value>true</value>
  <description>
  	If a job fails, whether to provide a link in the CLI to the task with the
  	most failures, along with debugging hints if applicable.
  </description>
</property>

<property>
  <name>hive.auto.progress.timeout</name>
  <value>0</value>
  <description>
    How long to run autoprogressor for the script/UDTF operators (in seconds).
    Set to 0 for forever.
  </description>
</property>

<!-- HBase Storage Handler Parameters -->

<property>
  <name>hive.hbase.wal.enabled</name>
  <value>true</value>
  <description>Whether writes to HBase should be forced to the write-ahead log.  Disabling this improves HBase write performance at the risk of lost writes in case of a crash.</description>
</property>

<property>
  <name>hive.table.parameters.default</name>
  <value></value>
  <description>Default property values for newly created tables</description>
</property>

<property>
  <name>hive.variable.substitute</name>
  <value>true</value>
  <description>This enables substitution using syntax like ${var} ${system:var} and ${env:var}.</description>
</property>


<property>
  <name>hive.security.authorization.enabled</name>
  <value>false</value>
  <description>enable or disable the hive client authorization</description>
</property>

<property>
  <name>hive.security.authorization.manager</name>
  <value>org.apache.hadoop.hive.ql.security.authorization.DefaultHiveAuthorizationProvider</value>
  <description>the hive client authorization manager class name.
  The user defined authorization class should implement interface org.apache.hadoop.hive.ql.security.authorization.HiveAuthorizationProvider. 
  </description>
</property>

<property>
  <name>hive.security.authenticator.manager</name>
  <value>org.apache.hadoop.hive.ql.security.HadoopDefaultAuthenticator</value>
  <description>hive client authenticator manager class name. 
  The user defined authenticator should implement interface org.apache.hadoop.hive.ql.security.HiveAuthenticationProvider.</description>
</property>

<property>
  <name>hive.security.authorization.createtable.user.grants</name>
  <value></value>
  <description>the privileges automatically granted to some users whenever a table gets created. 
   An example like "userX,userY:select;userZ:create" will grant select privilege to userX and userY, 
   and grant create privilege to userZ whenever a new table created.</description>
</property>

<property>
  <name>hive.security.authorization.createtable.group.grants</name>
  <value></value>
  <description>the privileges automatically granted to some groups whenever a table gets created. 
   An example like "groupX,groupY:select;groupZ:create" will grant select privilege to groupX and groupY, 
   and grant create privilege to groupZ whenever a new table created.</description>
</property>

<property>
  <name>hive.security.authorization.createtable.role.grants</name>
  <value></value>
  <description>the privileges automatically granted to some roles whenever a table gets created. 
   An example like "roleX,roleY:select;roleZ:create" will grant select privilege to roleX and roleY, 
   and grant create privilege to roleZ whenever a new table created.</description>
</property>

<property>
  <name>hive.security.authorization.createtable.owner.grants</name>
  <value></value>
  <description>the privileges automatically granted to the owner whenever a table gets created. 
   An example like "select,drop" will grant select and drop privilege to the owner of the table</description>
</property>

<property>
  <name>hive.metastore.authorization.storage.checks</name>
  <value>false</value>
  <description>Should the metastore do authorization checks against the underlying storage
  for operations like drop-partition (disallow the drop-partition if the user in 
  question doesn't have permissions to delete the corresponding directory
  on the storage).</description>
</property>

<property>
  <name>hive.error.on.empty.partition</name>
  <value>false</value>
  <description>Whether to throw an excpetion if dynamic partition insert generates empty results.</description>
</property>

<property>
  <name>hive.index.compact.file.ignore.hdfs</name>
  <value>false</value>
  <description>True the hdfs location stored in the index file will be igbored at runtime. 
  If the data got moved or the name of the cluster got changed, the index data should still be usable.</description>
</property>

<property>
  <name>hive.optimize.index.filter.compact.minsize</name>
  <value>5368709120</value>
  <description>Minimum size (in bytes) of the inputs on which a compact index is automatically used.</description>
</property>

<property>
  <name>hive.optimize.index.filter.compact.maxsize</name>
  <value>-1</value>
  <description>Maximum size (in bytes) of the inputs on which a compact index is automatically used.
  A negative number is equivalent to infinity.</description>
</property>

<property>
  <name>hive.index.compact.query.max.size</name>
  <value>10737418240</value>
  <description>The maximum number of bytes that a query using the compact index can read. Negative value is equivalent to infinity.</description>
</property>

<property>
  <name>hive.index.compact.query.max.entries</name>
  <value>10000000</value>
  <description>The maximum number of index entries to read during a query that uses the compact index. Negative value is equivalent to infinity.</description>
</property>

<property>
  <name>hive.index.compact.binary.search</name>
  <value>true</value>
  <description>Whether or not to use a binary search to find the entries in an index table that match the filter, where possible</description>
</property>

<property>
  <name>hive.exim.uri.scheme.whitelist</name>
  <value>hdfs,pfile</value>
  <description>A comma separated list of acceptable URI schemes for import and export.</description>
</property>

<property>
  <name>hive.lock.mapred.only.operation</name>
  <value>false</value>
  <description>This param is to control whether or not only do lock on queries 
  that need to execute at least one mapred job.</description>
</property>

<property>
  <name>hive.limit.row.max.size</name>
  <value>100000</value>
  <description>When trying a smaller subset of data for simple LIMIT, how much size we need to guarantee
   each row to have at least.</description>
</property>

<property>
  <name>hive.limit.optimize.limit.file</name>
  <value>10</value>
  <description>When trying a smaller subset of data for simple LIMIT, maximum number of files we can
   sample.</description>
</property>

<property>
  <name>hive.limit.optimize.enable</name>
  <value>false</value>
  <description>Whether to enable to optimization to trying a smaller subset of data for simple LIMIT first.</description>
</property>

<property>
  <name>hive.limit.optimize.fetch.max</name>
  <value>50000</value>
  <description>Maximum number of rows allowed for a smaller subset of data for simple LIMIT, if it is a fetch query.
   Insert queries are not restricted by this limit.</description>
</property>

<property>
  <name>hive.rework.mapredwork</name>
  <value>false</value>
  <description>should rework the mapred work or not. 
  This is first introduced by SymlinkTextInputFormat to replace symlink files with real paths at compile time.</description>
</property>

<property>
  <name>hive.exec.concatenate.check.index</name>
  <value>true</value>
  <description>If this sets to true, hive will throw error when doing
   'alter table tbl_name [partSpec] concatenate' on a table/partition 
    that has indexes on it. The reason the user want to set this to true 
    is because it can help user to avoid handling all index drop, recreation, 
    rebuild work. This is very helpful for tables with thousands of partitions.</description>
</property>

<property>
  <name>hive.sample.seednumber</name>
  <value>0</value>
  <description>A number used to percentage sampling. By changing this number, user will change the subsets
   of data sampled.</description>
</property>

<property>
	<name>hive.io.exception.handlers</name>
	<value></value>
	<description>A list of io exception handler class names. This is used
		to construct a list exception handlers to handle exceptions thrown 
		by record readers</description>
</property>

<property>
  <name>hive.autogen.columnalias.prefix.label</name>
  <value>_c</value>
  <description>String used as a prefix when auto generating column alias. 
  By default the prefix label will be appended with a column position number to form the column alias. Auto generation would happen if an aggregate function is used in a select clause without an explicit alias.</description>
</property>

<property>
  <name>hive.autogen.columnalias.prefix.includefuncname</name>
  <value>false</value>
  <description>Whether to include function name in the column alias auto generated by hive.</description>
</property>

<property>
  <name>hive.exec.perf.logger</name>
  <value>org.apache.hadoop.hive.ql.log.PerfLogger</value>
  <description>The class responsible logging client side performance metrics.  Must be a subclass of org.apache.hadoop.hive.ql.log.PerfLogger</description>
</property>

<property>
  <name>hive.start.cleanup.scratchdir</name>
  <value>false</value>
  <description>To cleanup the hive scratchdir while starting the hive server</description>
</property>

<property>
  <name>hive.output.file.extension</name>
  <value></value>
  <description>String used as a file extension for output files. If not set, defaults to the codec extension for text files (e.g. ".gz"), or no extension otherwise.</description>
</property>

<property>
  <name>hive.insert.into.multilevel.dirs</name>
  <value>false</value>
  <description>Where to insert into multilevel directories like 
  "insert directory '/HIVEFT25686/chinna/' from table"</description>
</property>

<property>
  <name>hive.warehouse.subdir.inherit.perms</name>
  <value>false</value>
  <description>Set this to true if the the table directories should inherit the 
    permission of the warehouse or database directory instead of being created 
    with the permissions derived from dfs umask</description>
</property>

<property>
  <name>hive.exec.job.debug.capture.stacktraces</name>
  <value>true</value>
  <description>Whether or not stack traces parsed from the task logs of a sampled failed task for
  			   each failed job should be stored in the SessionState
  </description>
</property>

<property>
  <name>hive.exec.driver.run.hooks</name>
  <value></value>
  <description>A comma separated list of hooks which implement HiveDriverRunHook and will be run at the
  			   beginning and end of Driver.run, these will be run in the order specified
  </description>
</property>

<property>
  <name>hive.ddl.output.format</name>
  <value>text</value>
  <description>
    The data format to use for DDL output.  One of "text" (for human
    readable text) or "json" (for a json object).
  </description>
</property>

</configuration>

EOF


################################################################################
# Bigframe configuration
# Modify this section to customize your Bigframe.
################################################################################

cat > $BIGFRAME_HOME/conf/config.sh <<'EOF'
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
TPCDS_LOCAL=/thoth/data/hadoop/tpcds_tmp
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.tpcds.local=${TPCDS_LOCAL}"

# Local Directory to store the itermediate data used for data refershing
REFRESH_LOCAL=~/bigframe_refresh_data
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.refresh.local=${REFRESH_LOCAL}"

# Global Output Path
export OUTPUT_PATH="hdfs://$MASTER_HOST:50001/test_output"
EOF

cat > $BIGFRAME_HOME/conf/hadoop-env.sh <<EOF
#!/usr/bin/env bash

######################### HADOOP RELATED ##########################
# The HDFS Root Directory to store the generated data
HDFS_ROOT_DIR="hdfs://$MASTER_HOST:50001/bigframedata"
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.hdfs.root.dir=${HDFS_ROOT_DIR}"

# The WebHDFS Root Directory to store the generated data
WEBHDFS_ROOT_DIR="http://localhost:50070/webhdfs/v1/user/cszahe/"
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.webhdfs.root.dir=${WEBHDFS_ROOT_DIR}"

# The username can access the HDFS_ROOT_DIR
HADOOP_USERNAME="ec2-user"
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.hadoop.username=${HADOOP_USERNAME}"

# The Hive HOME Directory
HIVE_HOME=$HIVE_HOME
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.hive.home=${HIVE_HOME}"

ORC_SETTING="false"
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.hive.orc=${ORC_SETTING}"

# The Hive JDBC Server Address
HIVE_JDBC_SERVER="jdbc:hive://$MASTER_HOST:10000/default"
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.hive.jdbc.server=${HIVE_JDBC_SERVER}"                                                                                                                                                                        
EOF

cat > $BIGFRAME_HOME/conf/spark-env.sh <<'EOF'

#!/usr/bin/env bash

######################### SPARK RELATED ##########################

# Path of Spark installation home. 
export SPARK_HOME="/usr/local/spark-1.0.1"
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.spark.home=${SPARK_HOME}"

# Path of Scala installation home.
export SCALA_HOME="/usr/local/scala-2.10.3"

# Spark memory parameters, defaults will be used if unspecified
export SPARK_MEM=13g

# Spark connection string, available in Spark master's webUI
export SPARK_CONNECTION_STRING="spark://${CLEANED_MASTER_HOST}:7077"

# The Spark Home Directory
SPARK_HOME=$SPARK_HOME
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.spark.home=${SPARK_HOME}"

# The Shark Home
#SHARK_HOME=$SHARK_HOME
#BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.shark.home=${SHARK_HOME}"

# Local directory for Spark scratch space
SPARK_LOCAL_DIR="/thoth/tmp/spark_local_dir"
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.spark.local.dir=${SPARK_LOCAL_DIR}"

# Use bagel for Spark
SPARK_USE_BAGEL=false
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.spark.usebagel=${SPARK_USE_BAGEL}"

# Spark degree of parallelism
SPARK_DOP=8
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.spark.dop=${SPARK_DOP}"

# Spark compress memory
SPARK_COMPRESS_MEMORY=false
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.spark.compress=${SPARK_COMPRESS_MEMORY}"

# Spark memory fraction
SPARK_MEMORY_FRACTION=0.5
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.spark.memoryFraction=${SPARK_MEMORY_FRACTION}"

# Spark optimize memory
SPARK_OPTIMIZE_MEMORY=true
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.spark.optimizeMemory=${SPARK_OPTIMIZE_MEMORY}"

# The Spark Master Address
SPARK_MASTER=$SPARK_CONNECTION_STRING
BIGFRAME_OPTS="${BIGFRAME_OPTS} -Dbigframe.spark.master=${SPARK_MASTER}"

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

mkdir -p /thoth/data/hadoop/logs

# not set on boot
export USER="ec2-user"

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
 # [ ! -e /vertica/data/hadoop/dfs ] && 
  "$HADOOP_HOME"/bin/hadoop namenode -format
  "$HADOOP_HOME"/bin/hadoop-daemon.sh start namenode
  "$HADOOP_HOME"/bin/hadoop-daemon.sh start jobtracker
  "$SPARK_HOME"/sbin/spark-config.sh
  "$SPARK_HOME"/sbin/start-master.sh
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
  "$SPARK_HOME"/sbin/spark-config.sh
  "$SPARK_HOME"/bin/spark-class org.apache.spark.deploy.worker.Worker spark://${CLEANED_MASTER_HOST}:7077 &
fi

# Run this script on next boot
rm -f /var/ec2/ec2-run-user-data.*
