
# 
# This script should be called from ${HADOOP_LOG_DIR} in a Hadoop worker node. It 
# is given a Hadoop job id as input, and it returns the running times of 
# all reduce tasks for that job which ran on this Hadoop worker node. 
#

use strict;
use warnings;

#####################################################

# The MapReduce user log dir
my $MR_USERLOG_DIR = "userlogs";

#####################################################

# if #arguments is incorrect, print usage
my ($numargs) = $#ARGV + 1;

if ($numargs != 1) {
    #$^X is the name of this executable
    print "USAGE: " . $^X . " hadoop_job_id\n";
    exit 1;
}

# We will strip out the "job_" part in the job id
my $job_id = $ARGV[0];

if ($job_id =~ /^job_([0-9_]+)/) {
    $job_id = $1;
}

#print "Hadoop Job ID: $job_id\n";

my $LOG_DIR=`pwd`;
chomp($LOG_DIR);
#print "Current directory is $LOG_DIR\n";

unless (-d $MR_USERLOG_DIR) {
        print "ERROR: Directory $MR_USERLOG_DIR does not exist\n";
        print "Current directory is $LOG_DIR\n";
        print "Exiting\n";
        exit 1;    
}

chdir $MR_USERLOG_DIR;

# The directories corresponding to the reduce task attempts have the format
#    attempt_201001052153_0021_r_000004_0
#    attempt_201001052153_0021_r_000004_1

# Get the directories for each of the reduce tasks run on this worker node
my $reduce_attempt_dirname_pattern = "attempt_" . $job_id . "_r_";
my $command = "ls -1t | grep \"$reduce_attempt_dirname_pattern\"";
my $reduce_attempt_dirs = `$command`;
chomp($reduce_attempt_dirs);
my @reduce_dirs = split(/\n/, $reduce_attempt_dirs);

# We are now in $CURR_DIR == ${HADOOP_LOG_DIR}/userlogs
my $CURR_DIR=`pwd`;
chomp($CURR_DIR);
#print "Current directory is $CURR_DIR\n";

my ($start_time_secs, $end_time_secs);

foreach my $dir (@reduce_dirs) {
  # print "$dir\n";

  # come back to the base dir in successive iterations of the loop. Note that the 
  #   directory paths in @reduce_dirs are relative to $CURR_DIR
  chdir $CURR_DIR;
  chdir $dir;

  my ($line, $prev_line);
  
  # read the syslog file
  open (SYSLOG, "syslog") || warn ("ERROR: Could not open syslog log file");
  
  # read the first line
  unless (defined($line = <SYSLOG>)) {
      warn ("ERROR: syslog log file is empty");
      close SYSLOG;
      next;
  }
 
# Format of the lines in the syslog
#2010-01-06 12:18:01,011 INFO org.apache.hadoop.metrics.jvm.JvmMetrics: Initializing JVM Metrics with processName=SHUFFLE, sessionId=
#2010-01-06 12:18:01,310 INFO org.apache.hadoop.mapred.ReduceTask: ShuffleRamManager: MemoryLimit=145699632, MaxSingleShuffleLimit=36424908
  
  chomp($line);
  
  unless ($line =~ /^(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)/) {
      warn ("ERROR: unexpected time format in \"$line\". Expected \"yyyy-mm-dd hh:mm:ss\"");
      close SYSLOG;
      next;
  }

  $start_time_secs = `date -d \'$1-$2-$3 $4:$5:$6\' \'+%s\'`;
  chomp($start_time_secs);
  
  #print "Start time of reduce task: "; 
  #print_time($1, $2, $3, $4, $5, $6);
  #print "\n";
  
  # read all other lines 

# We also need to find out whether the reduce task was SUCCESSFUL | FAILED | KILLED
  my $saw_file_commit = 0;
  my $saw_task_done = 0;
  my $saw_task_cleanup = 0;

# For a SUCCESSFUL task, we expect to see something like the following 
#2010-01-06 12:59:50,963 INFO org.apache.hadoop.mapred.TaskRunner: Task:attempt_201001052153_0021_r_000001_0 is done. And is in the process of commiting
#2010-01-06 12:59:52,997 INFO org.apache.hadoop.mapred.TaskRunner: Task attempt_201001052153_0021_r_000001_0 is allowed to commit now
#2010-01-06 12:59:53,038 INFO org.apache.hadoop.mapred.FileOutputCommitter: Saved output of task 'attempt_201001052153_0021_r_000001_0' to hdfs://hadoop21.cod.cs.duke.edu:9000/user/shivnath/tera/out
#2010-01-06 12:59:53,043 INFO org.apache.hadoop.mapred.TaskRunner: Task 'attempt_201001052153_0021_r_000001_0' done.

  $prev_line = $line; 
  while (defined($line = <SYSLOG>)) {
      chomp($line);
      
      # $dir is the attempt id of the task, e.g., attempt_201001052153_0021_r_000001_0
      if (($line =~ /$dir/) && ($line =~ /INFO/)) {
	  
	  if (($line =~ /FileOutputCommitter/) && 
	      ($line =~ /Saved output of task/)) {
	      $saw_file_commit = 1;	  
	  }
	  
	  if (($line =~ /TaskRunner/) && 
	      ($line =~ /done/)) {
	      $saw_task_done = 1;	  
	  }

      } # if saw the id of the task attempt 

# A line of this form indicates that the task was killed
#2010-01-26 09:40:31,413 INFO org.apache.hadoop.metrics.jvm.JvmMetrics: Initializing JVM Metrics with processName=CLEANUP, sessionId=

      if (($line =~ /INFO/) && ($line =~ /processName=CLEANUP/)) {
	   $saw_task_cleanup = 1;	  
      }

      $prev_line = $line;       
  }
  
  unless ($prev_line =~ /^(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)/) {
      warn ("ERROR: unexpected time format in \"$prev_line\". Expected \"yyyy-mm-dd hh:mm:ss\"");
      close SYSLOG;
      next;
  }

  $end_time_secs = `date -d \'$1-$2-$3 $4:$5:$6\' \'+%s\'`;
  chomp($end_time_secs);
  
  #print "End time of reduce task: "; 
  #print_time($1, $2, $3, $4, $5, $6);
  #print "\n";
  
  my $running_time = $end_time_secs - $start_time_secs;
  
  if ($saw_file_commit == 1 && $saw_task_done == 1) {  
      #print "Running time of SUCCESSFUL reduce task: " . $running_time . " seconds\n";   
      printf ("%s,%6d, SUCCESSFUL\n", $dir, $running_time);
      if ($saw_task_cleanup == 1) {
         printf ("BUG! Task with CLEANUP labeled as SUCCESSFUL\n");
      }
  }
  else {
      #print "Running time of FAILED|KILLED reduce task: " . $running_time . " seconds\n";   
      printf ("%s,%6d, FAILED|KILLED\n", $dir, $running_time);
  }
  
  close SYSLOG;
} #foreach

chdir $LOG_DIR;

exit 0;

# print the time passed as input 
sub print_time {
    my (%v1);
    ($v1{year}, $v1{month}, $v1{day}, $v1{hour}, $v1{min}, $v1{sec}) = @_;
    print "$v1{year}-$v1{month}-$v1{day} $v1{hour}:$v1{min}:$v1{sec}";
} 

