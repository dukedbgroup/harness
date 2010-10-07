#!/usr/bin/perl -w

###############################################################################
# This script can be used to copy/move a set of logs from the experiment
# directories (EXPT-xxxx) to a single unified directory. For example,
# this script can copy all the history files from each experiment to
# a single history directory
#
# Usage:
#  perl unify_exper_logs.pl target exper_dir out_dir [mv]
#  
#  where:
#    target    = is one of history, profiles, userlogs, or transfers
#    exper_dir = Base directory for the harness experiments
#    out_dir   = The output directory
#    mv        = Optional flag to move the files instead of copying
#
# Assumptions/Requirements:
#  The exper_dir is a valid directory with experiments and the file
#  RANDOMIZED_EXPERIMENT_LIST.txt exists.
#
# Example:
#  perl unify_exper_logs.pl history BASE OUT
#  Note: The OUT/history directory will be created and it will contain all
#        the files contained in the BASE/EXPT-****/history directories.
#
# Author: Herodotos Herodotou
# Date: August 27, 2010
##############################################################################

# Simple method to print new lines
sub println {
    local $\ = "\n";
    print @_;
}

# Make sure we have all the arguments
if ($#ARGV != 2 && $#ARGV != 3)
{
   println qq(UsageL perl $0 target exper_dir out_dir [mv]);
   println qq(  target    = is one of history, profiles, userlogs, or transfers);
   println qq(  exper_dir = Base directory for the harness experiments);
   println qq(  out_dir   = The output directory \(must exist\));
   println qq(  mv        = Optional flag to move the files instead of copying);
   exit(-1);
}

# Get the input data
my $TARGET    = $ARGV[0];
my $EXPER_DIR = $ARGV[1];
my $OUT_DIR   = $ARGV[2];
my $CMD       = ($#ARGV == 3) ? $ARGV[3] : "cp -r";
my $EXPER_LIST = $EXPER_DIR . "/RANDOMIZED_EXPERIMENT_LIST.txt";

# Error checking
if ($TARGET ne "history" && $TARGET ne "userlogs" && $TARGET ne "profiles" && $TARGET ne "transfers")
{
   println qq(ERROR: The only valid options for target are history, userlogs, profiles, or transfers);
   exit(-1);
} 

if (!-e $EXPER_DIR)
{
   println qq(ERROR: The directory '$EXPER_DIR' does not exist);
   exit(-1);
}

if (!-e $OUT_DIR)
{
   println qq(ERROR: The directory '$OUT_DIR' does not exist);
   exit(-1);
}

if ($CMD ne "cp -r" && $CMD ne "mv")
{
   println qq(ERROR: The only optional flag is 'mv');
   exit(-1);
}

# Get the experiments
open INFILE, "<", $EXPER_LIST;
my @expers = ();
while ($line = <INFILE>)
{
   $line =~ s/(^\s+)|(\s+$)//g;
   push(@expers, $line) if $line =~ /\S/
}
close INFILE;

# Create the output directory
my $output = "$OUT_DIR/$TARGET";
if (-e $output)
{
   println qq(ERROR: The directory '$output' already exists);
   exit(-1);
}
mkdir $output;

# Copy/Move the files
for $exper (@expers)
{
   print ".";
   system qq($CMD $EXPER_DIR/$exper/$TARGET/* $output/. > /dev/null 2>&1);
}

# Done
$time = time - $^T;
println qq();
println qq(Copying/Moving is complete!);
println qq(Time taken (sec):\t$time);

