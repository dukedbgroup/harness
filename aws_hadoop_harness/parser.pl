

# See http://articles.techrepublic.com.com/5100-22-5363190.html
#  for installation instruction and usage of XML::Simple;
# More References for XML:Simple:
#--------------------------------
# http://www.ibm.com/developerworks/xml/library/x-xmlperl1.html#N100BC
# http://www.tutorialized.com/view/tutorial/XML-Simple-Module/12239

# use module
use XML::Simple;
use Data::Dumper;

# Name of the XML configuration file produced for each experiment (in its own directory)
my $XML_CONF_FILE_NAME = "configuration.xml";

# The default delimitter that separates multiple values in the 
#    XML configuration file specified as input. This field can be overridden
#    for any parameter by specifying a value_delimitter field 
my $DEFAULT_VALUE_DELIMITTER = ",";

# if #arguments is incorrect, print usage
my ($numargs) = $#ARGV + 1;

if ($numargs != 3) {
    #$^X is the name of this executable
    print "USAGE: " . $^X . " <name of XML config file> <base directory for experiments> <output file containing list of experiment directories>\n";
    
    exit 0;
}

# create object
my $xml = new XML::Simple (KeyAttr=>[]);
# read XML file
my $data = $xml->XMLin($ARGV[0]);

my $EXP_BASE_DIR = $ARGV[1];

unless (-d $EXP_BASE_DIR) {
    print "ERROR: invalid base directory for experiments\n";
    print "Exiting\n";
    exit 0;    
}

# dereference hash ref
# access <property> array
my @values = ();
my $num_vals = -1;

# number of parameters 
my $num_params = 0;
my $curr_pnum = 0;
# total number of experiments
my $total_expts = 1;
my @NUM_VALUES_ARR = ();
my $value_delimitter;

print "------------\n";

foreach $e (@{$data->{property}}) {
    
    $curr_pnum = $num_params + 1;
    print "Parameter $curr_pnum:\n";    
    
    print "parameter name = ", $e->{name}, "\n";
    print "number of values = ", $e->{numvalues}, "\n";
    
    if ($e->{numvalues} <= 0) {
	print "ERROR: Incorrect specification of numvalues tag for property " . $e->{name} . "\n";
	print "Exiting\n";
	exit 0;
    }
    
    # number of distinct settings for this parameter
    $NUM_VALUES_ARR[$num_params] = $e->{numvalues};
    
    $num_params += 1;
    # note (later on) we can have scripts that do not set any parameter
    if ($e->{numvalues} > 0) {
	$total_expts *= $e->{numvalues};
    }

    if (!defined($e->{value_delimitter}) || $e->{value_delimitter} eq "") {
	$value_delimitter = $DEFAULT_VALUE_DELIMITTER;
    }
    else {
	if ($e->{value_delimitter} eq "|") {
	    # We have to add an escape character to use "|" as a delimitter in split
	    $value_delimitter = "\\|";
	}
	else {
	    $value_delimitter = $e->{value_delimitter};
	}
    }
    
    print "value delimitter = $value_delimitter\n";
    
    $num_vals = 0;
    
    unless (!defined($e->{values}) || $e->{values} eq "") {
	print $e->{values}, "\n";
	@values = split (/$value_delimitter/, $e->{values});
	$num_vals = $#values + 1;
    }

    
    unless ($num_vals == $e->{numvalues}) {
	print "ERROR: Incorrect specification of numvalues tag for property " . $e->{name} . "\n";
	print "Exiting\n";
	exit 0;
    }

    print "------------\n";
}

print "Number of parameters is $num_params\n";
print "Total number of experiments is $total_expts\n";

# this is the 2D array where we will store the parameter values for each 
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
    
    if ($e->{numvalues} == 0) {
	next;
    }
    
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
    
    if (!defined($e->{value_delimitter}) || $e->{value_delimitter} eq "") {
	$value_delimitter = $DEFAULT_VALUE_DELIMITTER;
    }
    else {
	if ($e->{value_delimitter} eq "|") {
	    # We have to add an escape character to use "|" as a delimitter in split
	    $value_delimitter = "\\|";
	}
	else {
	    $value_delimitter = $e->{value_delimitter};
	}
    }
    
    @values = split (/$value_delimitter/, $e->{values});
    
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
#   create a directory for each experiment. The directory should contain 
#   an XML configuration that will specify the corresponding parameter values
#

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
	exit 0;    
    }
    
    print "Making directory $dir_name\n";
    mkdir $dir_name, 0755;
    
    chdir $dir_name;
    
    # array where we will store the property_name, value combinations to be written
    #   out to the XML configuration file
    my @conf_array = ();
    
    # add the property_name, value combination from each experiment to the conf_array
    $pnum = -1;
    foreach $e (@{$data->{property}}) {
	$pnum ++;
	$conf_array[$pnum] = {'name' => $e->{name}, 'value' => $ARR[$i][$pnum]};
    } # for pnum 
    
    # create object
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
print "\n@nums \n";

open (OUT, ">$ARGV[2]")
    || quit ("FATAL ERROR: Could not open \"$ARGV[2]\"");

my $full_path_to_expt_dir = "";

for ($i = 0; $i < $total_expts; $i++) {
# the random permutation is in the 1..num_expts range
    $j = $nums[$i] - 1;

    $dir_name = $EXP_BASE_DIR . "/EXPT$j";

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

