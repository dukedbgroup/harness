
# 
# This script should be called from ${HADOOP_LOG_DIR} in a Hadoop worker node. It 
# is given a Hadoop job id as input, and it returns the running times of 
# all map tasks for that job which ran on this Hadoop worker node. 
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

# The directories corresponding to the map task attempts have the format
#    attempt_201001052153_0021_m_000004_0
#    attempt_201001052153_0021_m_000004_1

# Get the directories for each of the map tasks run on this worker node
my $map_attempt_dirname_pattern = "attempt_" . $job_id . "_m_";
my $command = "ls -1t | grep \"$map_attempt_dirname_pattern\"";
my $map_attempt_dirs = `$command`;
chomp($map_attempt_dirs);
my @map_dirs = split(/\n/, $map_attempt_dirs);

# We are now in $CURR_DIR == ${HADOOP_LOG_DIR}/userlogs
my $CURR_DIR=`pwd`;
chomp($CURR_DIR);
#print "Current directory is $CURR_DIR\n";

my ($start_time_secs, $end_time_secs);

foreach my $dir (@map_dirs) {
  # print "$dir\n";

  # come back to the base dir in successive iterations of the loop. Note that the 
  #   directory paths in @map_dirs are relative to $CURR_DIR
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
#2010-01-23 15:27:00,940 INFO org.apache.hadoop.metrics.jvm.JvmMetrics: Initializing JVM Metrics with processName=MAP, sessionId=
#2010-01-23 15:27:03,966 INFO org.apache.hadoop.mapred.MapTask: numReduceTasks: 30
  
  chomp($line);
  
  unless ($line =~ /^(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)/) {
      warn ("ERROR: unexpected time format in \"$line\". Expected \"yyyy-mm-dd hh:mm:ss\"");
      close SYSLOG;
      next;
  }

  $start_time_secs = `date -d \'$1-$2-$3 $4:$5:$6\' \'+%s\'`;
  chomp($start_time_secs);
  
  #print "Start time of map task: "; 
  #print_time($1, $2, $3, $4, $5, $6);
  #print "\n";
  
  # read all other lines 

# We also need to find out whether the map task was SUCCESSFUL | FAILED | KILLED
  my $saw_file_commit = 0;
  my $saw_task_done = 0;
  my $saw_task_cleanup = 0;
  my $saw_spill_number = -1;

# For a SUCCESSFUL task, we expect to see something like the following 
#2010-01-23 15:27:27,429 INFO org.apache.hadoop.mapred.TaskRunner: Task:attempt_201001231500_0003_m_000036_1 is done. And is in the process of commiting
#2010-01-23 15:27:27,459 INFO org.apache.hadoop.mapred.TaskRunner: Task 'attempt_201001231500_0003_m_000036_1' done.

  $prev_line = $line; 
  while (defined($line = <SYSLOG>)) {
      chomp($line);
      
      # $dir is the attempt id of the task, e.g., attempt_201001052153_0021_r_000001_0
      if (($line =~ /$dir/) && ($line =~ /INFO/)) {
	  
	  if (($line =~ /is done/) && 
	      ($line =~ /And is in the process of commiting/)) {
	      $saw_file_commit = 1;	  
	  }
       # Note: both the commit and the done lines have the words "TaskRunner" and "done"
	  elsif (($line =~ /TaskRunner/) && 
	      ($line =~ /done/)) {
	      $saw_task_done = 1;	  
	  }
	  
      } # if saw the id of the task attempt 

# A line of this form means that the task was killed
#2010-01-26 08:18:23,369 INFO org.apache.hadoop.metrics.jvm.JvmMetrics: Initializing JVM Metrics with processName=CLEANUP, sessionId=
      if (($line =~ /INFO/) && ($line =~ /processName=CLEANUP/)) {
           $saw_task_cleanup = 1;
      }

# Lines of the form: "Finished spill \d+" indicate that some work was done
#2010-01-26 08:11:49,710 INFO org.apache.hadoop.mapred.MapTask: Finished spill 0
#2010-01-26 08:12:02,907 INFO org.apache.hadoop.mapred.MapTask: Starting flush of map output
#2010-01-26 08:12:12,517 INFO org.apache.hadoop.mapred.MapTask: Finished spill 1
      if (($line =~ /INFO/) && ($line =~ /Finished spill (\d+)/)) {
           if (($saw_spill_number + 1) != $1) {
              printf ("BUG! Unexpected spill number in line \"%s\", Expected to see: %d\n", $line, ($saw_spill_number+1));
           }
           $saw_spill_number = $1;
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

  #print "End time of map task: "; 
  #print_time($1, $2, $3, $4, $5, $6);
  #print "\n";
  
  my $running_time = $end_time_secs - $start_time_secs;
  
  if ($saw_task_cleanup == 1) {
      #print "Running time of FAILED|KILLED map task: " . $running_time . " seconds\n";   
      printf ("%s,%6d, FAILED|KILLED\n", $dir, $running_time);
  }
  elsif ($saw_file_commit == 1 && $saw_task_done == 1 && $saw_spill_number >= 0) {  
      #print "Running time of SUCCESSFUL map task: " . $running_time . " seconds\n";   
      printf ("%s,%6d, SUCCESSFUL\n", $dir, $running_time);
  }
  else {
      #print "Running time of FAILED|KILLED map task: " . $running_time . " seconds\n";   
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

