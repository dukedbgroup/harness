#!/usr/bin/perl -w

###############################################################################
# This script can be used to test the What-if Engine for all the jobs
# in a harness experiment.
#
# Usage:
#  perl predict_time.pl whatif_jar exper_dir profiles
#  
#  where:
#    whatif_jar = The whatif jar
#    exper_dir  = Base directory for the harness experiments
#    profiles   = The directory with the job profiles or a single profile file
#
# Assumptions/Requirements:
#  The exper_dir is a valid directory with experiments and contains:
#    (a) a file called 'HADOOP_JOB_IDS.txt'
#    (b) a directory called 'results/history'
#
#  The profiles_dir is a valid directory with the job profiles
#  named either 'profile_job_EXPTID.xml' or 'profile_JOBID.xml',
#  or a single job profile file.
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
if ($#ARGV != 2)
{
	println qq(Usage:);
	println qq( perl $0 whatif_jar exper_dir profiles);
	println qq(); 
	println qq( where:);
	println qq(   whatif_jar = The whatif jar);
	println qq(   exper_dir  = Base directory for the harness experiments);
	println qq(   profiles   = The directory with the job profiles or a single profile file);
	exit(-1);
}

# Get the input data
my $WHAT_IF_JAR = $ARGV[0];
my $EXPER_DIR = $ARGV[1];
my $PROFILES = $ARGV[2];
my $JOB_LIST = $EXPER_DIR . "/HADOOP_JOB_IDS.txt";

# Error checking
if (!-e $EXPER_DIR)
{
   println qq(ERROR: The directory '$EXPER_DIR' does not exist);
   exit(-1);
}
if (!-e $PROFILES)
{
   println qq(ERROR: '$PROFILES' does not exist);
   exit(-1);
}

# Get the experiment and job ids
open INFILE, "<", $JOB_LIST;
my @expt_ids = ();
my @job_ids = ();
my $line = <INFILE>; # Skip header line
while ($line = <INFILE>)
{
   $line =~ s/(^\s+)|(\s+$)//g;
   @pieces = split(/\t/, $line);
   push(@expt_ids, $pieces[0]);
   push(@job_ids, $pieces[1]);
}
close INFILE;


# Answer the what if questions
$num_jobs = $#job_ids + 1;
println qq(JobId\tTime);
for ($i = 0; $i < $num_jobs; $i++)
{
   if (!-d $PROFILES)
   {
      $prof_file = $PROFILES;
   }
   elsif (-e qq($PROFILES/profile_job_$expt_ids[$i].xml))
   {
      $prof_file = qq($PROFILES/profile_job_$expt_ids[$i].xml);
   }
   else
   {
      $prof_file = qq($PROFILES/profile_$job_ids[$i].xml);
   }
   system qq(\${HADOOP_HOME}/bin/hadoop jar $WHAT_IF_JAR -mode job_time -profile $prof_file -conf $EXPER_DIR/results/history/*_$job_ids[$i]\_conf.xml 2>&1 | grep Execution | sed s/'Execution Time (ms):\t'/'$job_ids[$i]\t'/);
}

