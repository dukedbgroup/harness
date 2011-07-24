
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

# The output of the hadoop jar command is written to this file (in each experiment directory)
my $EXPERIMENT_OUTPUT_FILE = "output.txt";

# This is a file that is created in the base directory for experiments that lists the  
#  experiment number and parameter configuration 
my $EXPERIMENT_DESIGN_FILE = "DESIGN.txt";

# The job history files for each experiment stored in this subdirectory in the 
#    directory for that experiment 
my $EXPERIMENT_HISTORY_DIR = "history";

# For reference purposes, we copy the input configuration file and randomized experiment 
#  listing file to the experiment base directory under the following names respectively 
my $COPY_OF_INPUT_CONFIG_DIR = "CONFIG_INPUT";
my $COPY_OF_INPUT_XML_CONFIGURATION_FILE = "CONFIG_INPUT.xml";
my $RANDOMIZED_EXPERIMENT_LIST_FILE = "RANDOMIZED_EXPERIMENT_LIST.txt";

# if the following flag is set to false, the experiments will not be 
#   run in a random order. Instead, the 0,..,N-1 order will be used 
my $SHOULD_RANDOMIZE = "false";

# The starfish build directory
my $STARFISH_BUILD_DIR = "/root/build";

#####################################################################################

# if #arguments is incorrect, print usage
my ($numargs) = $#ARGV + 1;

if ($numargs < 2) {
    #$^X is the name of this executable
    print "USAGE: " . $^X . " " . $0 . " <dir or XML config file> <base directory for experiments> [profile]\n\n";
    print "NOTE: For $0 to run, the base directory should not exist; it will be created.\n";
    print "NOTE: If you use the flag 'profile', make sure to set STARFISH_BUILD_DIR in the script.\n\n";
    exit -1;
}

# Check if the input is a file or a directory
$input_is_dir = "false";
if (-d $ARGV[0]) {
	$input_is_dir = "true";
}
elsif (-e $ARGV[0]) {
	$input_is_dir = "false";
}
else {
    print "ERROR: $ARGV[0] does not exist and is not a directory.\n";
    print "USAGE: " . $^X . " " . $0 . " <dir or XML config file> <base directory for experiments> [profile]\n";
    exit -1;    
}

if (-d $ARGV[1]) {
    print "ERROR: $ARGV[1] already exists. Please specify a different base directory for experiments.\n";
    print "NOTE: For $0 to run, the base directory should not exist; it will be created.\n";
    print "USAGE: " . $^X . " " . $0 . " <dir or XML config file> <base directory for experiments> [profile]\n";
    exit -1;    
}

$profile_flag = "false";
if ($numargs == 3) {
   unless ($ARGV[2] eq "profile") {
		print "ERROR: The only valid 3rd argument is 'profile'.\n";
		print "USAGE: " . $^X . " " . $0 . " <dir or XML config file> <base directory for experiments> [profile]\n";
		exit -1;    
   }
   $profile_flag = "true";
}

# create the base directory for experiments -- Note this mkdir command is called 
#  from $CURR_DIR. Irrespective of whether $EXP_BASE_DIR is specified as a 
#  relative or absolute path, chdir to $EXP_BASE_DIR will work as long as it is 
#  from $CURR_DIR 
my $CURR_DIR=`pwd`;
chomp($CURR_DIR);
my $EXP_BASE_DIR = $ARGV[1];
`mkdir -p $EXP_BASE_DIR`;
`chmod 755 $EXP_BASE_DIR`;

unless (-d $EXP_BASE_DIR) {
    error_exit_with_cleanup("Unable to create the base directory for experiments: $EXP_BASE_DIR");
}

# Change the base directory into a fully specified path
chdir $EXP_BASE_DIR;
$EXP_BASE_DIR = `pwd`;
chomp($EXP_BASE_DIR);
chdir $CURR_DIR;

# Get the input files
my @files = ();
if ($input_is_dir eq "true") {
	chdir $ARGV[0];
	$input_dir = `pwd`;
	chomp($input_dir);
	chdir $CURR_DIR;

	@files = <$input_dir/*>;
}
else {
    @files = ($ARGV[0]);
}

my $expt_index = 0;
foreach $file (@files) {
    print "Processing: " . $file . "\n";

	########################################################################

	# Global variables -- begin 

	# read XML file -- see links at beginning of this program for how to use XML::Simple 
	my $xml = new XML::Simple (KeyAttr=>[]);
	my $data = $xml->XMLin($file);

	# PARAM_NAMES_ARR will contain the name (i.e., <name>jar_path</name>)
	#   specified for each parameter 
	my @PARAM_NAMES_ARR = ();
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

	# This is the 2D array where we will store the parameter values for each 
	# experiment on a row-by-row basis. The columns correspond 1-to-1 to the 
	# parameters.
	my @ARR = ();

	# number of parameters 
	my $num_params = 0;
	# total number of experiments
	my $total_expts = 1;

	# Global variables -- end

	########################################################################

	# temporary variables used in the code
	my @values = ();
	my $num_vals = -1;
	my $pnum = -1;
	my $value_delimitter;
	my $dir_name = "";
	my $i = 0;
	my $j = 0;

	########################################################################

	# read the properties specified in the input XML configuration file 
	foreach $e (@{$data->{property}}) {
		
		$PARAM_NAMES_ARR[$num_params] = $e->{name};
		#print "parameter name = ", $e->{name}, "\n";
		
		# parameter type 
		if (defined($e->{type})) {
		$TYPES_ARR[$num_params] = $e->{type};
		}
		else {
		$TYPES_ARR[$num_params] = $MAPREDUCE_JOBCONF_TYPE;
	#	print "NOTE: parameter type was unspecified, so using the default type of $MAPREDUCE_JOBCONF_TYPE\n";
		}
	#    print "parameter type = $TYPES_ARR[$num_params]\n";	
		
	#    print "number of values = ", $e->{numvalues}, "\n";
		if ($e->{numvalues} <= 0) {
		error_exit_with_cleanup("numvalues for property " . $e->{name} . " should be > 0");
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
		
	#    print "value delimitter = $VALUES_DELIMITTER_ARR[$num_params]\n";
		
		$num_vals = 0;
		unless (!defined($e->{values}) || $e->{values} eq "") {
		#print $e->{values}, "\n";
		@values = split (/$VALUES_DELIMITTER_ARR[$num_params]/, $e->{values});
		$num_vals = $#values + 1;
		}
		
		unless ($num_vals == $e->{numvalues}) {
		error_exit_with_cleanup("numvalues for property " . $e->{name} . " does not match the values specified");

		}

		$num_params += 1;
		$total_expts *= $e->{numvalues};

	}

	print "Number of parameters: $num_params, Total number of experiments: $total_expts\n";


	# The following for and foreach loops will initialize $ARR[$i][$j] based on the 
	#  crossproduct of the specified parameter value lists
	for ($i = 0; $i < $total_expts; $i++) {
		for ($j = 0; $j < $num_params; $j++) {
		$ARR[$i][$j] = -1;
		}      
	}     

	$pnum = -1;
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

	# At the point, the list of experiments is ready. We now have to 
	#   create a directory for each experiment. The directory should contain: 
	#   -- an XML configuration that will specify the corresponding parameter values
	#         (this XML file is named $XML_CONF_FILE_NAME = "configuration.xml")
	#   -- a script to run the corresponding Hadoop MapReduce job
	#         (this script is named $HADOOP_JAR_COMMAND_SCRIPT = "run_hadoop_jar.sh")

	for ($i = 0; $i < $total_expts; $i++) {
		
		chdir $EXP_BASE_DIR;
		
		# create the directory for this experiment
		$dir_name = sprintf("EXPT-%04d", $i + $expt_index);
		
		if (-d $dir_name) {
		# this shouldn't happen
		error_exit_with_cleanup("Directory $dir_name already exists in the base directory for experiments");
		}
		
		#print "Making directory $dir_name\n";
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
			# /user/shivnath/tera/out/EXPT0001
			$hdfs_output_path = $ARR[$i][$pnum] . "/$dir_name";
		
			# should the hdfs output be deleted when the experiment completes
			if (defined($e->{delete_on_exit}) && ($e->{delete_on_exit} eq "false")) {
				$delete_hdfs_output_on_exit = 0;
			}
			}
			else {
			error_exit_with_cleanup("Parameter " . $e->{name} . " of type $HADOOP_JAR_TYPE is not supported");
			}
		}
		else {
			error_exit_with_cleanup("Parameter " . $e->{name} . " has an unsupported type $TYPES_ARR[$pnum]");
		}
		} # foreach $e (@{$data->{property}}) {
		
		# Create the $HADOOP_JAR_COMMAND_SCRIPT
		
		# command to run the jar. Note: this command did not work when the -conf option
		#    was put after the input params and the output path
		if ($profile_flag eq "false") {
		    $hadoop_run_jar_command = '${HADOOP_HOME}' . "/bin/hadoop jar $jar_path $jar_class_name -conf $XML_CONF_FILE_NAME $jar_input_params $hdfs_output_path" . " >& $EXPERIMENT_OUTPUT_FILE &";
		}else {
			$hadoop_run_jar_command = "$STARFISH_BUILD_DIR/bin/profile hadoop jar $jar_path $jar_class_name -conf $XML_CONF_FILE_NAME -Dstarfish.profiler.output.dir=$EXP_BASE_DIR/results $jar_input_params $hdfs_output_path" . " >& $EXPERIMENT_OUTPUT_FILE &";
		}
		# command to delete the HDFS output dir created for the experiment
		$hadoop_delete_hdfs_output_command = '${HADOOP_HOME}' . "/bin/hadoop fs -rmr $hdfs_output_path";
	    # command to get the job history files for the experiment
		$hadoop_get_job_history_command = '${HADOOP_HOME}' . "/bin/hadoop fs -copyToLocal $hdfs_output_path/_logs/history $EXPERIMENT_HISTORY_DIR";
		# command to get the job history summary for the experiment
		$hadoop_job_history_summary_command = '${HADOOP_HOME}' . "/bin/hadoop job -history all $hdfs_output_path >$EXPERIMENT_HISTORY_DIR/READABLE_SUMMARY.txt";

		`echo '#!/usr/bin/env bash' >$HADOOP_JAR_COMMAND_SCRIPT`;
		`echo >>$HADOOP_JAR_COMMAND_SCRIPT`;
		
		#`echo 'printf "Going to run the command: %s\\n" "$hadoop_delete_hdfs_output_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
		`echo '$hadoop_delete_hdfs_output_command >&/dev/null' >>$HADOOP_JAR_COMMAND_SCRIPT`;
		#`echo 'printf "Finished running the command: %s\\n" "$hadoop_delete_hdfs_output_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
		`echo >>$HADOOP_JAR_COMMAND_SCRIPT`;
		
		#`echo 'printf "Going to run the command: %s\\n" "$hadoop_run_jar_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
		`echo '$hadoop_run_jar_command' >>$HADOOP_JAR_COMMAND_SCRIPT`;
		`echo 'wait \$!' >>$HADOOP_JAR_COMMAND_SCRIPT`; 
		#`echo 'printf "Finished running the command: %s\\n" "$hadoop_run_jar_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
		`echo >>$HADOOP_JAR_COMMAND_SCRIPT`;

		if ($profile_flag eq "false") {		
			#`echo 'printf "Going to run the command: %s\\n" "$hadoop_get_job_history_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
			`echo '$hadoop_get_job_history_command' >>$HADOOP_JAR_COMMAND_SCRIPT`;
			#`echo 'printf "Finished running the command: %s\\n" "$hadoop_get_job_history_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
			`echo >>$HADOOP_JAR_COMMAND_SCRIPT`;
		
			#`echo 'printf "Going to run the command: %s\\n" "$hadoop_job_history_summary_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
			`echo '$hadoop_job_history_summary_command' >>$HADOOP_JAR_COMMAND_SCRIPT`;
			#`echo 'printf "Finished running the command: %s\\n" "$hadoop_job_history_summary_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
			`echo >>$HADOOP_JAR_COMMAND_SCRIPT`;
			
			#
			# NOTE: files created by JVM profiling have the format: attempt_201007182349_0008_m_000000_0.profile
			#
			`echo 'mkdir -p profiles' >>$HADOOP_JAR_COMMAND_SCRIPT`;
			`echo 'mv attempt_*.profile profiles >&/dev/null' >>$HADOOP_JAR_COMMAND_SCRIPT`;
			`echo '[ "\$(ls -A profiles)" ] || rmdir profiles' >>$HADOOP_JAR_COMMAND_SCRIPT`;
			`echo >>$HADOOP_JAR_COMMAND_SCRIPT`;
		}
		
		if ($delete_hdfs_output_on_exit == 1) {
		#`echo 'printf "Going to run the command: %s\\n" "$hadoop_delete_hdfs_output_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
		`echo '$hadoop_delete_hdfs_output_command >&/dev/null' >>$HADOOP_JAR_COMMAND_SCRIPT`;
		#`echo 'printf "Finished running the command: %s\\n" "$hadoop_delete_hdfs_output_command"' >>$HADOOP_JAR_COMMAND_SCRIPT`;
		    `echo >>$HADOOP_JAR_COMMAND_SCRIPT`;
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

	my @nums = ();
	if ($SHOULD_RANDOMIZE eq "true") {
		@nums = gen_random_permutation($total_expts);
	# the random permutation is in the 1..num_expts range -- adjust it to 0..(num_expts-1)
		for ($i = 0; $i < $total_expts; $i++) {
			$nums[$i] = $nums[$i] - 1;
			unless ($nums[$i] >= 0 && $nums[$i] < $total_expts) {
				error_exit_with_cleanup("Invalid experiment ID: $nums[$i]. BUG in the randomization of experiments");
			}
		}
	}
	else {
		# use the order 0,..,$total_expts-1
		for ($i = 0; $i < $total_expts; $i++) {
			$nums[$i] = $i;
		}
	}

	# Create the table of contents file that lists the experiments that will be done
	chdir $EXP_BASE_DIR;
	open (OUT, ">>$EXPERIMENT_DESIGN_FILE") || error_exit_with_cleanup ("Could not open $EXPERIMENT_DESIGN_FILE");
	# print the schema: EXPT_ID followed by one column per parameter 
	print OUT "EXPT_ID"; 
	for ($i = 0; $i < $num_params; $i++) {
		print OUT "\t$PARAM_NAMES_ARR[$i]";
	}
	print OUT "\n";
	# print the list of experiments 
	for ($i = 0; $i < $total_expts; $i++) {
		print OUT sprintf("EXPT-%04d", $i + $expt_index);
		for ($j = 0; $j < $num_params; $j++) {
		print OUT "\t$ARR[$i][$j]";
		}      
		print OUT "\n";
	}
	print OUT "\n";
	close OUT;

	# Create the file that lists the randomized list of experiment directories 
	open (OUT, ">>$RANDOMIZED_EXPERIMENT_LIST_FILE") || error_exit_with_cleanup ("Could not open $RANDOMIZED_EXPERIMENT_LIST_FILE");

	for ($i = 0; $i < $total_expts; $i++) {
		print OUT sprintf("EXPT-%04d\n", $nums[$i] + $expt_index);
	}

	close OUT;

	$expt_index = $expt_index + $total_expts;
}

print "\n***************Experiment Design***************\n";
print `cat $EXPERIMENT_DESIGN_FILE`;

# come back to the current working directory 
chdir $CURR_DIR;

# for reference purposes, copy the input configuration file to the experiment base directory
if ($input_is_dir eq "true"){
	`cp -r $ARGV[0] $EXP_BASE_DIR/$COPY_OF_INPUT_CONFIG_DIR`;
}
else {
	`cp $ARGV[0] $EXP_BASE_DIR/$COPY_OF_INPUT_XML_CONFIGURATION_FILE`;
}

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

#####################################################################################

# function invoked if the program exits with an error after creating the 
#  base directory for experiments 
sub error_exit_with_cleanup {
    my ($msg) = @_;
    print "ERROR: $msg\n";
    print "Program failed because of a fatal error\n";
    chdir $CURR_DIR; 
    `rm -rf $EXP_BASE_DIR`;
    exit -1;
}

#####################################################################################

#end-of-file

