#!/usr/bin/perl -w

###############################################################################
# This script can be used to copy files to all the slaves.
#
# Usage:
#  perl copy_files_to_slaves.pl slaves_file local_file slave_dir
#  
#  where:
#    slaves_file = File containing a list of slave machines
#    local_file  = File or directory to copy to the slave machines
#    slave_dir   = Directory to copy the files to in the host machines
#
# Assumptions/Requirements:
#  The slaves directory exists in the slave nodes
#
# Example:
#  perl copy_files_to_slaves.pl /root/SLAVE_NAMES.txt file.txt /root/target
#
# Author: Herodotos Herodotou
# Date: July 23, 2010
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
   println qq(  local_file  = File or directory to copy to the slave machines);
   println qq(  slave_dir   = Directory to copy the files to in the slave machines);
   exit(-1);
}

# Get the input data
my $SLAVES_FILE  = $ARGV[0];
my $LOCAL_FILES  = $ARGV[1];
my $SLAVE_DIR    = $ARGV[2];

# Start data generation
println qq(Starting the coping at: ) . `date`;
println qq(Input Parameters:);
println qq(  File with slaves: $SLAVES_FILE);
println qq(  Local files to copy: $LOCAL_FILES);
println qq(  Directory on slaves: $SLAVE_DIR);
println qq();

# Error checking
if (!-e $SLAVES_FILE)
{
   println qq(ERROR: The file '$SLAVES_FILE' does not exist);
   exit(-1);
}

# Error checking
if (!-e $LOCAL_FILES)
{
   println qq(ERROR: The file(s) '$LOCAL_FILES' does not exist);
   exit(-1);
}

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

# Connect to each host and copy the files
for ($host = 0; $host < $num_slaves; $host++)
{
   println qq(Sending files to host: $slaves[$host]);
   !system qq(scp -r $LOCAL_FILES $slaves[$host]:$SLAVE_DIR/.) or die $!;
}

# Done
$time = time - $^T;
println qq();
println qq(Copying is complete!);
println qq(Time taken (sec):\t$time);

