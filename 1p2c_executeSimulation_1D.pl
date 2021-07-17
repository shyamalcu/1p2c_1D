#!/usr/bin/perl
####################################################################
# lauf.prl 
# Author:  KPN, AlT
# Date: 21.02.2012 - 2013.08.11
# This script is supposed to change a value in the input file for \Dumux and let it run afterwards. 
# A new folder is created (if nonexistent before) and the executable specified and it's input file is copied there.
# The output is created there, too. 
# a input file with the syntax:
# key = value #comments
# is expected.
# Also: the grids are expected to be in the folder above the new execution folder. 
#
# You need to adapt the location where your executable is. 
####################################################################

#     $dir = cwd;
#     print ("++++++++++++++$dir \n"); 

use Cwd;
use POSIX;
use Parallel::Loops;
use Parallel::ForkManager;
use Sys::CPU;


$time_date = strftime "%Y%m%d", localtime;
$time_hour = strftime "%H%M%S", localtime;

$number_of_cpus = Sys::CPU::cpu_count();
print "N CPUS = $number_of_cpus\n";

 $executionLocation = getcwd();
 #$executionLocation = "/home/mozart/VB_SUSE/scripts"; # the path to the parameter file and executable
 $resultLocation = "/home/user1/RESULTS"; # the path to the parameter file and executable
 # $executionLocation ="./";

$modelName = "$time_date"."_1p2c_"."$time_hour";
print "$modelName \n";

$executable 	= "test_box1p2ctracer1D";
$inputfile	= "$executable".".input";

print "\n###########################################################################\n";
print "+++ Model: $modelName\n";
print "+++ Executable file is: $executable\n";
print "+++ Input file is: $inputfile \n" ;
print "\n###########################################################################\n";

$grid="";
$solver="";

$keyTEnd="TEnd"; 
$valueTEnd= 3600*24*250; #250 days

$keyRef="Refinement"; 
$valueRef="0";

$keyPerm="Permeability"; 
$value3="1e-12";

$keyDisp="Dispersivity";
$value4="1.0";

$keyEpisodeEnd = "EpisodeEnd";
$value5="86400";
    
    
    ### If the Result location does not exist create it
    if (-d "$resultLocation") {
      print "+++ The << $resultLocation >> directory exists. Don't have to create it again.\n";
    }
    else {
      system("mkdir $resultLocation ")==0 or die $!;
      print "+++ Create the << $resultLocation >> folder\n";
    }
    
    $vorwortA='K';
    $vorwortB='D';
    $keyA = $keyPerm;
    $keyB = $keyDisp;
    #$keyB = $keyDisp;
    #$keyA = 'CellsX';
    #$keyB = 'CellsY';

    @cycleValuesA 		= (1e-12); # intrinsic permeability [m^2]
#    @cycleValuesB		= (1e-7, 1e-8, 1e-9, 1e-10); # Kinetic Rate
#    @cycleValuesB		= (1, 1.5, 2);   #Dispersion
    @cycleValuesB		= (0 , 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 3, 5, 7, 10); # EpisodeEnd

    
    # @cycleValuesA		= (4, 8, 16, 32, 64) ;
    # @cycleValuesB		= (9, 19, 39, 79, 159, 319) ;
    # @cycleValuesB     = (23, 27, 31, 35, 39, 43, 47, 51, 55, 59, 63, 67);
    # @cycleValuesC     = (1, 2, 3, 4, 5) ;# just the number of entries counts

    $keyGrid 		= "File"; 				# the keyword for the grid that is to be replaced
    $keyOutputName	= "Name"; 			# the keyword for the  output name that is to be replaced
    $keyInjection 	= "massFluxInjectedPhase";	# the keyword for the injected mass that is to be replaced

    
## change this value for creating a new execution location     
$subFolderBuffer=$modelName."_Result"."_$keyA"."_$keyB";

#$subFolderBuffer="dummyKPM1e-11";

#     $subfolder 	=sprintf( "evaporation".$subFolderBuffer."percentOfEquil%1.e", $scaleTheInjection);
    $subfolder 		= sprintf( "/$subFolderBuffer/");
    $newDir 		= "$resultLocation"."$subfolder";
    
     ### Create the simulation folder inside the results 
     if (-d "$newDir") {
	print "+++ The << $newDir >> directory exists. Don't have to create it again. \n";
     }
     else {
	system ("mkdir $newDir ")==0 or die $!;
	print "+++ Created directory: \t\t$newDir \n";
     }
     
  
    $valA_idx = 0;     
#foreach $valueC (@cycleValuesC)
#{
foreach $valueA (@cycleValuesA)
{
    $valA_idx=$valA_idx+1;
    print "\nSimulation [[ $valA_idx ]] in Cycle A \n \n";
#    $valueA = $valueA * 1.8 ;
    print "Cycle A values are: @cycleValuesA \t valuesA = $valueA \n";
    $valueInjection = .75 ;		# the value for the  output name that is to be replaced
    
    $dirLocationValA = "$resultLocation"."$subfolder"."$keyA"."$valueA";
    print "\n dirLocationValA = $dirLocationValA \n";
    
    ### create the folder of cycleA simulations
    system ("mkdir $dirLocationValA ") == 0 or die $!;
    
        
    $outPutNameBaseBase="out_".$executable."_";
   
    
    #searchAndReplaceAfterEqual("$keyInjection", "$inputfile", $valueInjection) or die $! ;
    #print "+++-----------> set new value: $keyInjection to $valueInjection\n";
    
    ###########################################################################
    ### Search And Replace
    ###########################################################################
    searchAndReplaceAfterEqual("$keyA", "$inputfile", $valueA) or die $! ;
    print "+++-----------> set new value: $keyA to $valueA\n";
    
    print "+++-----------> looking for : $keyTEnd in $inputfile\n";
    searchAndReplaceAfterEqual("$keyTEnd", "$inputfile", $valueTEnd) or die $!;
    print "+++-----------> set new outputName: $valueTEnd in $inputfile\n";
        
    #searchAndReplaceAfterEqual("$keyRef", "$inputfile", $valueRef) or die $! ;
    #print "+++-----------> set new value: $keyRef to $valueRef\n";
    
    #searchAndReplaceAfterEqual("$key3", "$inputfile", $value3) or die $! ;
    #print "+++-----------> set new value: $key3 to $value3\n";
    
       
    $valueOutPutNameBase1=$outPutNameBaseBase.$valueB;

    foreach $valueB (@cycleValuesB)
    {
 #       $valueB = ceil($valueB * 1.6) ;
	print "Cycle B values are: @cycleValuesB \t valuesB = $valueB \n";
	
	$dirLocationValB = $dirLocationValA."/$keyB"."$valueB/";
	print "\n dirLocationValB = $dirLocationValB \n";
    
	### create the folder of cycleA simulations
	system ("mkdir $dirLocationValB ") == 0 or die $!;

	    
	###########################################################################
	### Copy the executables to the folder 
	###########################################################################
	system("cp $executable $dirLocationValB")==0 or die $!;
	print "+++copied $executable to: \t $dirLocationValB \n";
	
	system("cp $inputfile $dirLocationValB")==0 or die $!;
	print "+++copied $inputfile to: \t$dirLocationValB \n";
	
	system("mkdir $dirLocationValB/grids")==0 or die$!;
	print "+++created directory: \t\t$dirLocationValB/grids \n";
	searchAndReadAfterEqual($keyGrid, $inputfile, $varB); # modify the keyB
	system("cp $varB $dirLocationValB/grids/\n")==0 or die $!;
	print "+++copied the geometry file $varB to: \t$dirLocationValB/grids\n";
	
	push (@location_changes, $dirLocationValB);
	####### Change to the directory where to execute the simulation
	chdir($dirLocationValB) or die("not possible to change to $dirLocationValB");
	print "+++changed to directory: \t$dirLocationValB \n";
	$dir = cwd;
	print ("++++++++++++++$dir \n");
	###########################################################################
	
	### for replacing outputName
	$valueOutPutName="$valueOutPutNameBase1${vorwortA}${valueA}${vorwortB}${valueB}";
	print "+++-----------> looking for : $keyOutputName in $inputfile\n";
	searchAndReplaceAfterEqual("$keyOutputName", "$inputfile", $valueOutPutName) or die $!;
	print "+++-----------> set new outputName: $valueOutPutName in $inputfile\n";
	
	### for replacing the keyB
	print "+++-----------> looking for : $keyB in $inputfile\n";
	searchAndReplaceAfterEqual("$keyB", "$inputfile", $valueB) or die $!;
	print "+++-----------> set new outputName: $valueOutPutName in $inputfile\n";

	### for replacing the grid name
	#$newGrid		= "../grids/${executable}${valueA}x$valueB".'.dgf';    # when everything is done by grid name
	#$newGrid		= "../grids/interfacedomain.dgf";    # when everything is done by parameters and bernd's meshcreator
	#searchAndReplaceAfterEqual("$keyGrid", "$inputfile", $newGrid) or die $! ;
	#print "+++-----------> set new value: $newGrid to $keyGrid\n";
	
	#######################################################################
	#### Execution
	#######################################################################
	
	#$executionString="./$executable --parameterFile=./$executable.input >  grepTemp.txt";
	$executionString="(time ./$executable) >sim.txt 2>&1";
	push(@commands, $executionString);
	print "+++try to start program: $executionString\n";
	$grepOutPutName="grepOut$vorwortA$valueA$vorwortB$valueB.txt";
	system("$executionString &") ==0 or die "\n+++->execution did not work (check e.g. spelling and paths)\n";

	# system("./$executable --parameterFile=./$executable.input | tee > grepTemp.txt") ==0 or die "\n+++->execution did not work (check e.g. spelling and paths)\n";
	# system("egrep 'Storage in  wPhase:|Time step ' grepTemp.txt > $grepOutPutName ")==0 or die $!;
	# system("rm grepTemp.txt")==0 or die "grepTemp deletion did not work";
    }    
#}
    #$moveIt='../';
    #chdir($moveIt) or die("not possible to move up");
    #print "+++changed to directory: \t$moveIt \n";
}

###############################################################################
######## Execution in parallel
###############################################################################

    $num_commands = @commands;
    $i = 0;
    
#     foreach $command (@commands) {
#    
#       $pid = fork();
#       print "PID = $pid \n";
#       if ($pid == 0) {
#         print "\n+++Command[$i]: $command\n"; 
#         print "+++Location[$i]: \t@location_changes[$i]\n";
#       
# 	###### Change to the directory where to execute the simulation
# 	system (cd "@location_changes[$i]") or die("not possible to change to @location_changes[$i]");
# 	print "+++changed to directory: \t@location_changes[$i] \n";
# 	    $dir = cwd;
# 	print ("++++++++++++++$dir \n");
# 	#######################################################################
#       
#       	#######################################################################
# 	#### Execution
# 	#######################################################################
#       	print "+++try to start program: $executionString\n";
# 	#system("$command") ==0 or die "\n+++->execution did not work (check e.g. spelling and paths)\n";
#  	#system($command);
# 	exit 0;
#        }
#        
#        $i = $i +1;
#     }
#################################################################################

    
print  "\n+++Script Execution Finished!!!\n";

####################################################
######Functions				    ########
####################################################
# find a value in the line a searchstring is found. The first word after the "=" sign is taken
# arguments
#     1st: the searchstring, 2nd: the filename, 3rd: the value(return)
sub searchAndReplaceAfterEqual 
{
    my $found = 0;
    my $searchString = @_[0]; 		# the word I am looking for
    my $fileName = @_[1];		# the file I look in
    my $parameter = @_[2];		#the value I want to write into the file

    open(REPLACE_FILE, "<$fileName" ) or  die $! ;
    @fileContent =<REPLACE_FILE>;
    close  (REPLACE_FILE);

    foreach $line (@fileContent)
    {
	if ( $line =~ m/$searchString/ ) 	# if the searchs tring is in the line (m stands for match)
	{
	    $found++;
	    chomp ($line); 				# get rid of the \n at end of line
	    @array1 = split ("=", $line); 		# split in everything before and after "="
	    @array2 = split ("#", $array1[1]); 		# everything after the comment symbol has to be restored
	    chomp(@array2);
	    $newLine = "$searchString = $parameter #$array2[1]\n"; # compose the the line of: the searchs tring + equal + value + comment symbol + everything that could have been there before
	    $line = $newLine;
	    last; 						# Stop Searching if the value was found once 
	}
    }
    
    # write the old file plus the changed line to disc
    open(REPLACE_FILE,">$fileName") or die $!;
    print REPLACE_FILE @fileContent;
    close REPLACE_FILE ;
    return $found;
}

# find a value in the line a searchstring is found. The first word after the "=" sign is taken
# arguments 
#     1st: the searchstring, 2nd: the filename, 3rd: the value(return)
sub searchAndReadAfterEqual 
{
	my $found = 0;
	my $searchString = @_[0];		# the word I am looking for
	my $fileName = @_[1];			# the file I look in
	open (SEARCH_DATEI, $fileName) or die $!;
	    @fileContent =<SEARCH_DATEI>;
	close  (SEARCH_DATEI);

	foreach $line(@fileContent)
	{
		if ( $line =~ m/$searchString/ ) # if the searchs tring is in the line (m stands for match)
		{
		    $found ++;
		    chomp ($line); 				# get rid of the \n at end of line
		    @array1 = split ("=", $line); 		# split in everything before and after "="
		    @array2 = split (" ", $array1[1]); 		# in case there are numbers of blanks in between words
		    $parameter=@array2[0]; 			# the first thing after the first "=" hopefully is the value
		    @_[2] = $parameter;				# write the found value into the third function argument (return value)
		    last;					# Stop Searching if the value was found once 
		}
	}
	return $found; 
}

# find a value in the line *after* a searchstring is found
# arguments 
#     1st: the searchstring, 2nd: the filename, 3rd: the value(return)
sub searchAndReadNextLine
{
        my $found = 0;
	my $searchString = @_[0];
	my $fileName = @_[1];
	open (SEARCH_DATEI, $fileName) or die $! ;
	    @fileContent =<SEARCH_DATEI>;
	close  (SEARCH_DATEI);
	$i=0;
	foreach $line(@fileContent)
	{
		if ( $line =~ m/$searchString/ ) #wenn der searchstring in der zeile vorkommt
		{
		    $found++;
		    $line = @fileContent[$i+1] ; 	# one line after the search string was found
		    chomp ($line); 				# get rid of the \n at end of line

		    @array = split (" ", $line); 		# in case there are numbers of blanks in between words
		    $parameter=@array[0]; 		# the line above split (with blanks as delimiter) )the line. We take the first word of it
		    @_[2] = $parameter;			# write the found value into the third function argument (return value)
		    last;						# Stop Searching if the value was found once 
		}
		$i++;
	}
	return $found;
}



