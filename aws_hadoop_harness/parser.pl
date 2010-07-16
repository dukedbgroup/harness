
# See http://articles.techrepublic.com.com/5100-22-5363190.html
#  for installation instruction and usage of XML::Simple;
# More References for XML:Simple:
#--------------------------------
# http://www.ibm.com/developerworks/xml/library/x-xmlperl1.html#N100BC
# http://www.tutorialized.com/view/tutorial/XML-Simple-Module/12239
use XML::Simple;
use Data::Dumper;

#####################################################################################

# the parameter types that can appear in the input XML configuration file 
my $MAPREDUCE_JOBCONF_TYPE = "MAPREDUCE_JOBCONF"; # for the configuration parameters
my $HADOOP_JAR_TYPE = "HADOOP_JAR"; # for generating the hadoop jar command 
my $TASKTRACKER_SETUP_TYPE = "TASKTRACKER_SETUP"; # tasktracker specific parameters

# The default delimitter that separates multiple values in the 
#    XML configuration file specified as input. This field can be overridden
#    for any parameter by specifying a value_delimitter field 
my $DEFAULT_VALUE_DELIMITTER = ",";

# Name of the XML configuration file produced for each experiment (in its own directory)
#  that specifies the parameter configuration for the MapReduce job that will 
# run the experiment.
my $XML_CONF_FILE_NAME = "configuration.xml";

# Name of the hadoop command script produced for each experiment (in its own directory)
my $HADOOP_JAR_COMMAND_SCRIPT = "run_hadoop_jar.sh";

# The output of the hadoop command is written to this file (in each experiment directory)
my $EXPERIMENT_OUTPUT_FILE = "output.txt";

#####################################################################################

# if #arguments is incorrect, print usage
my ($numargs) = $#ARGV + 1;

if ($numargs != 3) {
    #$^X is the name of this executable
    print "USAGE: " . $^X . " " . $0 . " <name of XML config file> <base directory for experiments> <output file containing list of experiment directories>\n";
    print "NOTE: For $0 to run, the base directory should not exist. It will be created by the program.\n";
    exit -1;
}

# create object
my $xml = new XML::Simple (KeyAttr=>[]);
# read XML file
my $data = $xml->XMLin($ARGV[0]);

my $EXP_BASE_DIR = $ARGV[1];

if (-d $EXP_BASE_DIR) {
    print "ERROR: $EXP_BASE_DIR already exists. Please specify a different base directory for experiments. Exiting.\n";
    print "NOTE: For $0 to run, the base directory should not exist. It will be created by the program.\n";
    print "USAGE: " . $^X . " " . $0 . " <name of XML config file> <base directory for experiments> <output file containing list of experiment directories>\n";
    exit -1;    
}

########################################################################

# Global variables -- begin 

# NUM_VALUES_ARR will contain the numvalues (i.e., <numvalues>2</numvalues>)
#   specified for each parameter 
my @NUM_VALUES_ARR = ();
# TYPES_ARR will contain the type (i.e., <type>HADOOP_JAR</type>)
#   specified for each parameter. Note that the default type is: $MAPREDUCE_JOBCONF_TYPE
my @TYPES_ARR = ();
# VALUES_DELIMITTER_ARR will contain the value delimitter 
#   (i.e., <value_delimitter>|</value_delimitter>) specified for each parameter. 
#   Note that $DEFAULT_VALUE_DELIMITTER = ",";
my @VALUES_DELIMITTER_ARR = ();

# number of parameters 
my $num_params = 0;
# total number of experiments
my $total_expts = 1;

# Global variables -- end

########################################################################

# temporary variables used in the code below 
my @values = ();
my $num_vals = -1;
my $curr_pnum = 0;
my $value_delimitter;

print "------------\n";

foreach $e (@{$data->{property}}) {
    
    $curr_pnum = $num_params + 1;
    print "Parameter $curr_pnum:\n";    
    print "parameter name = ", $e->{name}, "\n";
    
    # parameter type 
    if (defined($e->{type})) {
	$TYPES_ARR[$num_params] = $e->{type};
    }
    else {
	$TYPES_ARR[$num_params] = $MAPREDUCE_JOBCONF_TYPE;
	print "NOTE: parameter type was unspecified, so using the default type of $MAPREDUCE_JOBCONF_TYPE\n";
    }
    print "parameter type = $TYPES_ARR[$num_params]\n";	

    print "number of values = ", $e->{numvalues}, "\n";
    if ($e->{numvalues} <= 0) {
	print "ERROR: numvalues for property " . $e->{name} . " should be > 0. Exiting\n";
	exit -1;
    }

    # number of distinct settings for this parameter
    $NUM_VALUES_ARR[$num_params] = $e->{numvalues};

    # value delimitter 
    if (!defined($e->{value_delimitter}) || $e->{value_delimitter} eq "") {
	$VALUES_DELIMITTER_ARR[$num_params] = $DEFAULT_VALUE_DELIMITTER;
    }
    else {
	if ($e->{value_delimitter} eq "|") {
	    # We have to add an escape character to use "|" as a delimitter in split
	    $VALUES_DELIMITTER_ARR[$num_params] = "\\|";
	}
	else {
	    $VALUES_DELIMITTER_ARR[$num_params] = $e->{value_delimitter};
	}
    }
    
    print "value delimitter = $VALUES_DELIMITTER_ARR[$num_params]\n";
    
    $num_vals = 0;
    unless (!defined($e->{values}) || $e->{values} eq "") {
	print $e->{values}, "\n";
	@values = split (/$VALUES_DELIMITTER_ARR[$num_params]/, $e->{values});
	$num_vals = $#values + 1;
    }
    
    unless ($num_vals == $e->{numvalues}) {
	print "ERROR: numvalues for property " . $e->{name} . " does not match the values specified. Exiting\n";
	exit -1;
    }

    $num_params += 1;
    $total_expts *= $e->{numvalues};

    print "------------\n";
}

print "Number of parameters is $num_params\n";
print "Total number of experiments is $total_expts\n";

# This is the 2D array where we will store the parameter values for each 
# experiment on a row-by-row basis. The columns correspond 1-to-1 to the 
# parameters.
my @ARR = ();

my $i = 0;
my $j = 0;

for ($i = 0; $i < $total_expts; $i++) {
    for ($j = 0; $j < $num_params; $j++) {
	$ARR[$i][$j] = -1;
    }      
}     

# for each param
my $pnum = -1;
foreach $e (@{$data->{property}}) {
    $pnum ++;
    
    my $outer_prod = 1;    
    # note: pnum is actually a param index
    for ($j = 0; $j < $pnum; $j++) {    
	if ($NUM_VALUES_ARR[$j] > 0) {
	    $outer_prod *= $NUM_VALUES_ARR[$j];
	}
    }
    
    my $inner_prod = 1;    
    for ($j = $pnum+1; $j < $num_params; $j++) {    
	if ($NUM_VALUES_ARR[$j] > 0) {
	    $inner_prod *= $NUM_VALUES_ARR[$j];
	}
    }    
    
    @values = split (/$VALUES_DELIMITTER_ARR[$pnum]/, $e->{values});
    
    my $index = -1;
    my ($a, $b, $c);
    for ($a = 0; $a < $outer_prod; $a++) {    
	for ($b = 0; $b < $NUM_VALUES_ARR[$pnum]; $b++) {    
	    for ($c = 0; $c < $inner_prod; $c++) {    
		$index ++;
		$ARR[$index][$pnum] = $values[$b];
	    }
	}	
    }
    
} # for param pnum

print "\n***************************************************\n";
print "The List of Experiments\n";
for ($i = 0; $i < $total_expts; $i++) {
    print "$ARR[$i][0]";
    for ($j = 1; $j < $num_params; $j++) {
	print ", $ARR[$i][$j]";
    }      
    print "\n";
}     
print "***************************************************\n";


# At the point, the list of experiments is ready. We now have to 
#   create a directory for each experiment. The directory should contain: 
#   -- an XML configuration that will specify the corresponding parameter values
#         (this XML file is named $XML_CONF_FILE_NAME = "configuration.xml")
#   -- a script to run the corresponding Hadoop MapReduce job
#         (this script is named $HADOOP_JAR_COMMAND_SCRIPT = "run_hadoop_jar.sh")

my $CURR_DIR=`pwd`;
chomp($CURR_DIR);
print "Current directory is $CURR_DIR\n";

my $dir_name = "";

for ($i = 0; $i < $total_expts; $i++) {
    
    # create the directory for this experiment
    $dir_name = $EXP_BASE_DIR . "/EXPT$i";
    
    if (-d $dir_name) {
	print "ERROR: Expt directory \"$dir_name\" already exists\n";
	print "Exiting\n";
	exit -1;    
    }
    
    print "Making directory $dir_name\n";
    `mkdir -p $dir_name`;
    `chmod 755 $dir_name`;
    
    chdir $dir_name;
    
    # array where we will store the property_name, value combinations to be written
    #   out to the XML configuration file for each $MAPREDUCE_JOBCONF_TYPE parameter
    my @conf_array = ();
    $j = -1; # $j is used to access (only) conf_array 
    $pnum = -1;
    my $jar_path = "";
    my $jar_class_name = "";
    my $jar_input_params = "";
    my $hdfs_output_path = "";
    my $delete_hdfs_output_on_exit = 1;
    my $hadoop_run_jar_command = "";
    my $hadoop_delete_hdfs_output_command = "";
    
    foreach $e (@{$data->{property}}) {
	$pnum ++;
        if ($TYPES_ARR[$pnum] eq $MAPREDUCE_JOBCONF_TYPE) {
	    $j ++;
	    $conf_array[$j] = {'name' => $e->{name}, 'value' => $ARR[$i][$pnum]};
	}
        elsif ($TYPES_ARR[$pnum] eq $HADOOP_JAR_TYPE) {
	    if ($e->{name} eq "jar_path") {
		$jar_path = $ARR[$i][$pnum];
	    }
	    elsif ($e->{name} eq "jar_class_name") {
		$jar_class_name = $ARR[$i][$pnum];
	    }
	    elsif ($e->{name} eq "jar_input_params") {
		$jar_input_params = $ARR[$i][$pnum];
	    }
	    elsif ($e->{name} eq "jar_output_prefix") {
		# The output directory has the form ${jar_output_prefix}/${exptID},
		# where ${exptID} is an identifier for the experiment. For example, 
		# if we specified jar_output_prefix as /user/shivnath/tera/out,
		# then the output directory for the Experiment 1 will be
		# /user/shivnath/tera/out/EXPT1
		$hdfs_output_path = $ARR[$i][$pnum] . "/EXPT" . "$i";
		
		# should the hdfs output be deleted when the experiment completes
		if (defined($e->{delete_on_exit}) && ($e->{delete_on_exit} eq "false")) {
		    $delete_hdfs_output_on_exit = 0;
		}
	    }
	    else {
		print "ERROR: parameter " . $e->{name} . " of type $HADOOP_JAR_TYPE is not supported. Exiting\n";
		exit -1;		
	    }
	}
	elsif ($TYPES_ARR[$pnum] eq $TASKTRACKER_SETUP_TYPE) {
	    print "ERROR: parameter " . $e->{name} . " has type $TYPES_ARR[$pnum] which is not supported yet. Exiting\n";
	    exit -1;
	}
	else {
	    print "ERROR: parameter " . $e->{name} . " has unsupported type $TYPES_ARR[$pnum]. Exiting\n";
	    exit -1;
	}
    } # for pnum 
    
    # create the $HADOOP_JAR_COMMAND_SCRIPT
    
    # command to run the jar. Note: this command did not work when the -conf option
    #    was put after the input params and the output path 
    $hadoop_run_jar_command = '${HADOOP_HOME}' . "/bin/hadoop jar $jar_path $jar_class_name -conf $XML_CONF_FILE_NAME $jar_input_params $hdfs_output_path" . " >& $EXPERIMENT_OUTPUT_FILE &";
    $hadoop_delete_hdfs_output_command = '${HADOOP_HOME}' . "/bin/hadoop fs -rmr $hdfs_output_path";
    `echo '#!/usr/bin/env bash' >$HADOOP_JAR_COMMAND_SCRIPT`;
    `echo 'printf "Going to run the command: %s\\n" "$hadoop_delete_hdfs_output_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
    `echo '$hadoop_delete_hdfs_output_command' >>$HADOOP_JAR_COMMAND_SCRIPT`;
    `echo 'printf "Finished running the command: %s\\n" "$hadoop_delete_hdfs_output_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
    `echo 'printf "Going to run the command: %s\\n" "$hadoop_run_jar_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
    `echo '$hadoop_run_jar_command' >>$HADOOP_JAR_COMMAND_SCRIPT`;
    `echo 'wait \$!' >>$HADOOP_JAR_COMMAND_SCRIPT`; 
    `echo 'printf "Finished running the command: %s\\n" "$hadoop_run_jar_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
    if ($delete_hdfs_output_on_exit == 1) {
	`echo 'printf "Going to run the command: %s\\n" "$hadoop_delete_hdfs_output_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
	`echo '$hadoop_delete_hdfs_output_command' >>$HADOOP_JAR_COMMAND_SCRIPT`;
	`echo 'printf "Finished running the command: %s\\n" "$hadoop_delete_hdfs_output_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
    }
    `chmod 544 $HADOOP_JAR_COMMAND_SCRIPT`; 
    
    # create the $XML_CONF_FILE_NAME
    $xml = new XML::Simple (NoAttr => 1, 
			    RootName => 'configuration', 
			    OutputFile => $XML_CONF_FILE_NAME,
			    XMLDecl    => "<?xml version='1.0'?>");
    # convert Perl array ref into XML document 
    $xml->XMLout({'property' => \@conf_array});
    
    chdir $CURR_DIR;
    
} # for i

chdir $CURR_DIR;

# finally: write the file that contains the list of output directories

my @nums = gen_random_permutation($total_expts);

# the random permutation is in the 1..num_expts range -- adjust it to 0..(num_expts-1)
for ($i = 0; $i < $total_expts; $i++) {
    $nums[$i] = $nums[$i] - 1;
    unless ($nums[$i] >= 0 && $nums[$i] < $total_expts) {
        print "ERROR: Invalid experiment ID: $nums[$i]. BUG in the randomization of experiments. Exiting\n";
        exit -1;
    }
}
print "\nRandomized experiment list:\n";
print "@nums \n";

open (OUT, ">$ARGV[2]") || quit ("FATAL ERROR: Could not open \"$ARGV[2]\"");

my $full_path_to_expt_dir = "";

for ($i = 0; $i < $total_expts; $i++) {
    $dir_name = $EXP_BASE_DIR . "/EXPT$nums[$i]";

    chdir $dir_name;
    $full_path_to_expt_dir=`pwd`;
    chomp($full_path_to_expt_dir);
    print OUT "$full_path_to_expt_dir\n";

    chdir $CURR_DIR;
}

close OUT;

exit 0;

#    This program will generate a random permutation of the integers
#  { 1, ..., n } for a user specified integer n.  We assume that
#  user inputs a positive integer (if it's negative then we'll get
#  an error as the program executes).  
#
#    We use the Markov chain Monte Carlo method for generating the
#  random permuation.  
#
sub gen_random_permutation {
    my ($n) = @_;
    my (@nums, $iters, $i, $k);
    srand;  #  seed the random number generator
    @nums = 1 .. $n;  #  initialize with the identity permutation 
    
    $iters = 12 * $n**3 * log($n) + 1;
    for ($i = 1; $i <= $iters; $i++) {
	if (rand(1) <= .5)   #  Flip a coin, and if heads swap
	    # a random adjacent pair of elements.  
	{
	    $k = int( rand($n-1) );
            if ($k >= 0 && $k < ($n-1)) {
	      ( $nums [$k], $nums [$k + 1] ) = ($nums [$k + 1], $nums [$k] );
            }
	}
    }
    
    return @nums;
}




#end-of-file

