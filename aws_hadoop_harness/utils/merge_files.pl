#!/usr/bin/perl -w

###############################################################################
# This script can be used to merge files together horizontally, that is
# the rows from each input file are appended together (separated by a tab)
# to form the output file.
#
# Usage:
#  perl merge_files.pl output input_1 input_2 ... input_n
#  
#  where:
#    output  = The output file (must not exist)
#    input_i = The input files to merge (must have same number of rows)
#
# Assumptions/Requirements:
#  The output file must not exist.
#  The input files must exist and have the same number of rows.
#
# Example:
#  perl merge_files.pl output input_1 input_2
#
# Author: Herodotos Herodotou
# Date: September 23, 2010
##############################################################################

# Simple method to print new lines
sub println {
    local $\ = "\n";
    print @_;
}

# Make sure we have all the arguments
if ($#ARGV < 1)
{
   println qq(UsageL perl $0 output input_1 input_2 ... input_n);
   println qq(  output  = The output file \(must not exist\));
   println qq(  input_i = The input files to merge \(must have same number of rows\));
   exit(-1);
}

# Get the input data
my $OUTPUT = $ARGV[0];
my @INPUTS = @ARGV[1..$#ARGV];

# Error checking
if (-e $OUTPUT)
{
   println qq(ERROR: The output file '$OUTPUT' already exists);
   exit(-1);
}

for $input (@INPUTS)
{
   if (!-e $input)
   {
      println qq(ERROR: The input file '$input' does not exist);
      exit(-1);
   }
}

# Open all files
my @INFILES = ();
for ($i = 0; $i <= $#INPUTS; $i++)
{
   open $INFILES[$i], "<", $INPUTS[$i];
}
open OUTFILE, ">", $OUTPUT;

# Read and merge the lines from all files
my $eof = 0;
while ($eof != 1)
{
   for $INFILE (@INFILES)
   {
      $line = <$INFILE>;
      if (!$line)
      {
         $eof = 1;
         next;
      }
      
      $line =~ s/\n$//;
      print OUTFILE qq($line\t);
   }
   print OUTFILE qq(\n);
}

# Close all files
for $INFILE (@INFILES)
{
   close $INFILE;
}
close OUTFILE;

