#!/usr/bin/perl -w

###############################################################################
# This script can be used to execute the same command to all the slaves.
#
# Usage:
#  perl run_cmd_on_slaves.pl slaves_file wait ('cmd'|"cmd")
#  
#  where:
#    slaves_file = File containing a list of slave machines
#    wait        = true or false, whether to wait for each cmd to finish or not
#    cmd         = The cmd to execute (surrounded by single or double quotes)
#
# Assumptions/Requirements:
#  The enviromental variable $HADOOP_HOME is defined in the master node
#
# Example:
#  perl run_cmd_on_slaves.pl /root/SLAVE_NAMES.txt "ls -l /root"
#
# Author: Herodotos Herodotou
# Date: July 23, 2010
#
##############################################################################

# Simple method to print new lines
sub println {
    local $\ = "\n";
    print @_;
}

# Make sure we have all the arguments
if ($#ARGV != 2)
{
   println qq(Usage: perl $0 slaves_file local_file slave_dir);
   println qq(  slaves_file = File containing a list of slave machines);
   println qq(  wait = true or false, whether to wait for each cmd to finish or not);
   println qq(  cmd  = The cmd to execute \(surrounded by single or double quotes\));
   exit(-1);
}

# Get the input data
my $SLAVES_FILE  = $ARGV[0];
my $WAIT  = $ARGV[1];
my $CMD    = $ARGV[2];

# Start data generation
println qq(Starting the coping at: ) . `date`;
println qq(Input Parameters:);
println qq(  File with slaves: $SLAVES_FILE);
println qq(  Wait for each cmd: $WAIT);
println qq(  Command to execute: $CMD);
println qq();

# Error checking
if (!-e $SLAVES_FILE)
{
   println qq(ERROR: The file '$SLAVES_FILE' does not exist);
   exit(-1);
}

if ($WAIT ne "true" && $WAIT ne "false")
{
   println qq(ERROR: Wait should either be true or false, not '$WAIT');
   exit(-1);
}

if (!$ENV{'HADOOP_HOME'})
{
   println qq(ERROR: \$HADOOP_HOME is not defined);
   exit(-1);
}

# Execute the hadoop-env.sh script for environmental variable definitions
!system qq(. \$HADOOP_HOME/conf/hadoop-env.sh) or die $!;
my $hadoop_home = $ENV{'HADOOP_HOME'};
my $ssh_opts = ($ENV{'HADOOP_SSH_OPTS'}) ? $ENV{'HADOOP_SSH_OPTS'} : "";

# Get the slaves
open INFILE, "<", $SLAVES_FILE;
my @slaves = ();
while ($line = <INFILE>)
{
   $line =~ s/(^\s+)|(\s+$)//g;
   push(@slaves, $line) if $line =~ /\S/
}
close INFILE;

# Make sure we have some hosts
my $num_slaves = scalar(@slaves);
if ($num_slaves <= 0)
{
   println qq(ERROR: No hosts were found in '$SLAVES_FILE');
   exit(-1);
}

# Connect to each host and executing the command
for ($host = 0; $host < $num_slaves; $host++)
{
   println qq(Executing cmd at host: $slaves[$host]\n);
   if ($WAIT eq "true")
   {
      # Execute the command and wait for it to finish
      system qq(ssh $ssh_opts $slaves[$host] \"$CMD\");
      println qq();
   }
   else {
      # Execute the command in a child process
      unless (fork)
      {
         system qq(ssh $ssh_opts $slaves[$host] \"$CMD\");
         println qq(Command completed at host $slaves[$host]);
         exit(0);
      }
   }
}

# Wait for the hosts to complete
if ($WAIT ne "true")
{
   println qq(Waiting for the commands to complete);
   for ($host = 0; $host < $num_slaves; $host++)
   {
      wait;
   }
}

# Done
$time = time - $^T;
println qq();
println qq(Command execution is complete!);
println qq(Time taken (sec):\t$time);

