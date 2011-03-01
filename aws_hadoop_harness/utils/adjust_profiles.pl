#!/usr/bin/perl -w

###############################################################################
# This script can be used to generate the adjusted XML profiles of all the jobs
# for two experiments. The first experiment run without compression and the
# second run with compression.
#
# Usage:
#  perl adjust_profiles.pl profile_jar compr_no_dir compr_yes_dir out_dir
#  
#  where:
#    profile_jar   = The profile jar
#    compr_no_dir  = Base directory for experiments without compression
#    compr_yes_dir = Base directory for experiments with compression
#    out_dir       = The output directory
#
# Assumptions/Requirements:
#  The compr_*_dir are valid directories with experiments and:
#    (a) each contains a file called 'HADOOP_JOB_IDS.txt'
#    (b) each contains a directory called results/job_profiles
#    (c) have the same number of experiments with one-to-one correspondance
#
# Author: Herodotos Herodotou
# Date: February 15, 2010
##############################################################################

# Simple method to print new lines
sub println {
    local $\ = "\n";
    print @_;
}

# Make sure we have all the arguments
if ($#ARGV != 3)
{
   println qq(Usage:);
   println qq( perl $0 profile_jar compr_no_dir compr_yes_dir out_dir);
   println qq(); 
   println qq( where:);
   println qq(   profile_jar   = The profile jar);
   println qq(   compr_no_dir  = Base directory for experiments without compression);
   println qq(   compr_yes_dir = Base directory for experiments with compression);
   println qq(   out_dir       = The output directory);
   exit(-1);
}

# Get the input data
my $PROF_JAR    = $ARGV[0];
my $EXPER_DIR_1 = $ARGV[1];
my $EXPER_DIR_2 = $ARGV[2];
my $OUT_DIR     = $ARGV[3];
my $JOB_LIST_1  = $EXPER_DIR_1 . "/HADOOP_JOB_IDS.txt";
my $JOB_LIST_2  = $EXPER_DIR_2 . "/HADOOP_JOB_IDS.txt";

# Error checking
if (!-e $EXPER_DIR_1)
{
   println qq(ERROR: The directory '$EXPER_DIR_1' does not exist);
   exit(-1);
}
if (!-e $EXPER_DIR_2)
{
   println qq(ERROR: The directory '$EXPER_DIR_2' does not exist);
   exit(-1);
}

# Get the job ids from the first experiment
open INFILE, "<", $JOB_LIST_1;
my @expt_ids = ();
my @job_ids_1 = ();
my $line = <INFILE>; # Skip header line
while ($line = <INFILE>)
{
   $line =~ s/(^\s+)|(\s+$)//g;
   @pieces = split(/\t/, $line);
   push(@expt_ids, $pieces[0]);
   push(@job_ids_1, $pieces[1]);
}
close INFILE;

# Get the job ids from the second experiment
open INFILE, "<", $JOB_LIST_2;
my @job_ids_2 = ();
$line = <INFILE>; # Skip header line
while ($line = <INFILE>)
{
   $line =~ s/(^\s+)|(\s+$)//g;
   @pieces = split(/\t/, $line);
   push(@job_ids_2, $pieces[1]);
}
close INFILE;

if ($#job_ids_1 != $#job_ids_2)
{
   println qq(ERROR: The two experiments don't have the same number of jobs);
   exit(-1);
}

# Create the output directory
mkdir $OUT_DIR;


# Generate the adjusted profiles
$num_jobs = $#job_ids_1 + 1;
for ($i = 0; $i < $num_jobs; $i++)
{
   println qq(Adjusting $job_ids_1[$i] and $job_ids_2[$i] for $expt_ids[$i]);
   system qq(\${HADOOP_HOME}/bin/hadoop jar $PROF_JAR -mode adjust -profile1 $EXPER_DIR_1/results/job_profiles/profile_$job_ids_1[$i].xml -profile2 $EXPER_DIR_2/results/job_profiles/profile_$job_ids_2[$i].xml -output $OUT_DIR/profile_job_$expt_ids[$i].xml);
}

# Done
$time = time - $^T;
println qq();
println qq(Profile adjustment is complete!);
println qq(Time taken (sec):\t$time);

