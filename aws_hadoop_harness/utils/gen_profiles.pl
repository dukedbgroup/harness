#!/usr/bin/perl -w

###############################################################################
# This script can be used to generate the XML profiles of all the jobs
# for an experiment.
#
# Usage:
#  perl gen_profiles.pl profile_jar exper_dir out_dir
#  
#  where:
#    profile_jar = The profile jar
#    exper_dir = Base directory for the harness experiments
#    out_dir   = The output directory
#
# Assumptions/Requirements:
#  The exper_dir is a valid directory with experiments and contains:
#    (a) a file called 'HADOOP_JOB_IDS.txt'
#    (b) a directory called 'history' with the conf/history files
#    (c) a directory called 'profiles' with the profile files
#
# Example:
#  perl gen_profiles.pl /root/starfish-profiles.jar BASE OUT
#  Note: The OUT directory will be created and it will contain
#        files of the form profile_job_id.xml
#
# Author: Herodotos Herodotou
# Date: February 06, 2010
##############################################################################

# Simple method to print new lines
sub println {
    local $\ = "\n";
    print @_;
}

# Make sure we have all the arguments
if ($#ARGV != 2)
{
   println qq(UsageL perl $0 profile_jar exper_dir out_dir);
   println qq(  profile_jar = The profile jar);
   println qq(  exper_dir   = Base directory for the harness experiments);
   println qq(  out_dir     = The output directory);
   exit(-1);
}

# Get the input data
my $PROF_JAR = $ARGV[0];
my $EXPER_DIR = $ARGV[1];
my $OUT_DIR   = $ARGV[2];
my $JOB_LIST = $EXPER_DIR . "/HADOOP_JOB_IDS.txt";

# Error checking
if (!-e $EXPER_DIR)
{
   println qq(ERROR: The directory '$EXPER_DIR' does not exist);
   exit(-1);
}

# Get the job ids
open INFILE, "<", $JOB_LIST;
my @job_ids = ();
my $line = <INFILE>; # Skip header line
while ($line = <INFILE>)
{
   $line =~ s/(^\s+)|(\s+$)//g;
   @pieces = split(/\t/, $line);
   push(@job_ids, $pieces[1]);
}
close INFILE;

# Create the output directory
mkdir $OUT_DIR;

# Generate the profiles
for $job_id (@job_ids)
{
   system qq(\${HADOOP_HOME}/bin/hadoop jar $PROF_JAR -mode export -job $job_id -history $EXPER_DIR/history -profiles $EXPER_DIR/profiles -output $OUT_DIR/profile_$job_id.xml >& log.out);
   print ".";
}

# Done
$time = time - $^T;
println qq();
println qq(Profile generation is complete!);
println qq(Time taken (sec):\t$time);

