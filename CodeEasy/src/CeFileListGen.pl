#!/usr/bin/perl -w 
################################################################################
# CodeEasy Customer Evaluation Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to create a complete file/directory list for a given
#          directory. This script is heavily multi-threaded to maximize
#          performance.
#
#          The file list can be used to perform the chown (permissions)
#          changes on a FlexVolume.
#          
#
# Usage:   %> CeFileListGen.pl -d <root directory> -f <output filelist name>
#
# Author:  Michael Johnson (michael.johnson@netapp.com)
#           
# NETAPP CONFIDENTIAL
# -------------------
# Copyright 2015 NetApp, Inc. All Rights Reserved.
#
# NOTICE: All information contained herein is, and remains the property
# of NetApp, Inc.  The intellectual and technical concepts contained
# herein are proprietary to NetApp, Inc. and its suppliers, if applicable,
# and may be covered by U.S. and Foreign Patents, patents in process, and are
# protected by trade secret or copyright law. Dissemination of this
# information or reproduction of this material is strictly forbidden unless
# permission is obtained from NetApp, Inc.
#
################################################################################

use Cwd;
use File::Basename;
use Getopt::Long;  # Perl library for parsing command line options
use strict;        # require strict programming rules

# Use CSV package which is located in the same location as the executable.
# The FindBin helps indentify the path this executable and thus its path
use FindBin ();

# load CodeEasy packages
use lib "$FindBin::Bin/.";
use CeInit;        # contains CodeEasy script setup values

############################################################
# Global Vars / Setup
############################################################
use constant TRUE  => 1;
use constant FALSE => 0;


# determine date
my $date = `date`; chomp $date; $date =~ s/\s+/ /g;

# command line argument values
our $root_directory;                 # full path of the top level directory to scan
our $filelist_BOM;                   # name of filelist to generate
our $filelist_BOM_defaultname = "filelist_BOM";  # default filefile name
our $verbose;                        # cmdline arg: verbosity level

our $progname="CeFileListGen.pl";    # name of this program

# use /temp disk to store temporary files for better performance
# this program will clean-up the temp directory upon exiting.
# TRUE  : fill create a temp directory in <progname>_tempdir_<PID> 
# FALSE : will create a temp directory in root_directory
our $use_tmp_disk = TRUE;
our $cleanup_temp = TRUE;
our $temp_dir;

# define max parallel threads to use 
our $max_thread_count = 140;

###################################################################################
# Start Program
###################################################################################

print "\n" .
      "------------------------------------------------------------\n" .
      "$progname: file list generator\n" .
      "------------------------------------------------------------\n"; 

# parse command line inputs
&parse_cmd_line();

# generate file list
&create_filelist_BOM();


# exit program successfully
&exit_prog(0);



###################################################################################
# Subrountines 
###################################################################################

########################################
# Command line Parser
########################################

sub parse_cmd_line {

  # parse command line 
  GetOptions ("h|help"        => sub { &show_help() },   
              'd|directory=s' => \$root_directory,       # root directory to use (full path)
	      'f|filelist=s'  => \$filelist_BOM,         # name of filelist to generate
              'v|verbose'     => \$verbose,              # increase output verbosity
	      '<>'            => sub { &CMDParseError() },
	      ); 

    # check to make sure that a directory name was specified on the command line
    if (! defined $root_directory) {
	print "\nERROR ($progname): No directory specified on the command line.\n" .
	        "      \%> $progname -d <directory name>\n\n" .
		"      For help\n" .
	        "        \%> $progname -help\n" .
		"      Exiting...\n\n";
	exit 1;
	
    }

    # check that the directory exists
    if ( -d $root_directory ) {
	# trim/clean-up $root_directory path to ensure no trailing /
	# example: /u/my_path/   should be just /u/my_path 
	$root_directory =~ s:/$::g;

	print "INFO  ($progname): Creating filelist for root directory\n" .
	      "      $root_directory\n";
    } else {
	print "ERROR ($progname): Directory does not exist.\n" .
	      "      check that the directory is a full UNIX path and exists.\n" .
	      "      Exiting...\n";
    }

    # check that at least one of the actions has been selected
    if (! defined $filelist_BOM) {
	# use the default filename 
	$filelist_BOM = "$root_directory/$filelist_BOM_defaultname";
    } else {
	# filelist was specified - check if it was just a filename or a full path filename

	# a full path should start with a '/' followed by a 'letter/
	# example:   /my_full_path/my_filelist
	if ( ! $filelist_BOM =~ m:^/\w: ) {
	    # full path NOT found - add root_directory to make it a full path
	    $filelist_BOM = "$root_directory/$filelist_BOM";
	}
    }

    print "INFO  ($progname): Output filelist named = $filelist_BOM\n";

} # end of sub parse_cmd_line()


########################################
# Error handling for cmd line parsing problems
########################################
sub CMDParseError {
    # report cmd line parsing errors, display help then exit
    print "\nERROR: Unrecognized command line option.\n" .
          "       use the -help option to get program usage help.\n\n"; 
    exit 1;
} # end sub &CMDParseError()

########################################
# Display Script Help Info
########################################
sub show_help {

# help/script usage information
my $helpTxt = qq[
$progname: Usage Information 
      -h|-help                        : show this help info

      -d|-directory <directory name>  : root directory to scan
                                        the program will inventory all files
					and directories from this directory
					downward. use full UNIX path
      -f|-filelist  <filelist name>   : name of the filelist to generate
                                        default=<directory name>/filelist.BOM
                                        (optional) 

      -v|-verbose                     : enable verbose output

      Examples:
	create a filelist called /my_path/dir_to_scan/filelist.BOM
        %> $progname -d /my_path/dir_to_scan/

];

    print $helpTxt;
    exit 0;

} # end of sub &show_help()



########################################
# create_filelist_BOM
#   This subroutine creates a file list BOM (bill of materials) which can then
#   be used later to change the ownership on the FlexClone volume.
#
#   This sub is written/optimized for very deep very high file count
#   directories. This sub uses parallel threads to accellerate the generation
#   of the file list.
#
########################################
sub create_filelist_BOM {

    # create a temporary directory for storying intermediate file list files
    my $temp_filelist_dir = &create_temp_dir();


    # create sub list of directories but only one level deep
    # -maxdepth 1 => maximum search depth 1 directory
    # -type d     => type directory
    my @dir_list = qx($CeInit::CE_CMD_FIND $root_directory -maxdepth 1 -type d );
    chomp(@dir_list);

    my @new_dir_list;

    # loop thru list of directories and remove any directories which should
    # NOT be included in the list
    foreach my $dir (@dir_list) {
	# skip the temp directory - since it will get deleted at the end of
	# this script
	next if ($dir eq $temp_dir);
	# skip root directory - it will be process separately
	next if ($dir eq $root_directory);
	# exclude the .snapshot directory
	next if ($dir =~ m:/.snapshot$:);
	# rebuild the directory list
	push @new_dir_list, $dir;
    }

    # re-assign the list back to the original name
    @dir_list = @new_dir_list;

    # determine number of directories in the array @dir_list
    my $total_dir_count= $#dir_list;
    printf("INFO  \(%s\): Total Dir = %d\n", $progname, $total_dir_count) if (defined $verbose);


    #--------------------------------------- 
    # find all files in each directory 
    #   - this is a multi-threaded implementation for performance
    #--------------------------------------- 
    my $cnt   = 0;
    my $p_cnt = 0;

    # change to the root_directory so the find is a relative path
    chdir $root_directory;
 
    # Limiting to $max_thread_count number of threads to have a better hand on the threads
    #   this loop will run in chunks of $max_thread_count directories
    for (my $i = 0; $i <= $#dir_list; $i += $max_thread_count) {

	# get the 140 elements from the array at a time.
        my @dirlist_filtered = @dir_list[$i..$i+$max_thread_count];
        @dirlist_filtered = grep {defined $_} @dirlist_filtered;
 
        print "INFO ($progname): For Dir Count = $#dirlist_filtered\n" if (defined $verbose);
	$p_cnt++;
	$cnt = 0;
 
        foreach my $dir (@dirlist_filtered) {
	    my $pid;
	    $cnt++;
	    next if $pid = fork;    # Parent goes to the next server
	    die "ERROR ($progname): fork process failed $!\n" unless defined $pid;
	    
	    print "INFO: Counter = (${p_cnt}_${cnt}) <$dir>\n" if (defined $verbose);
	    &run_file_find($dir);

	    exit;  # end the child process
	}

	# the following waits until all the child processes have finished
	# before allowing the parent to die
	1 while (wait() != -1) ;

    }

    print "INFO ($progname): All threads completed\n";

    # Accumlating all the fileslist into a single file
    my $cmd = "$CeInit::CE_CMD_FIND $temp_dir -name \*.list";
    my $list_filelists = qx($cmd);
    chomp $list_filelists;
    $cnt = 0;

    # open final filelist BOM and then cat all files to it.
    if (open (FILEOUT, ">$filelist_BOM") ) {
	print "INFO  ($progname): Writing complete file list file\n" .
	      "      $filelist_BOM\n";
    } else {
	print "ERROR ($progname): Could not open $filelist_BOM for writing\n" .
	      "      Exiting...\n";
	# exit with clean-up
	&exit_prog(1);
    }

    # loop thru the a sorted list of the file lists
    @ARGV = (sort split '^', $list_filelists);
    #foreach my $file (sort split '^', $list_filelists) {
    while (<>) {
	print FILEOUT;
    }
    # close the fileout
    close FILEOUT;

    # exit with clean-up
    &exit_prog(1);

} # end of sub &create_filelist_BOM()

########################################
# sub to initialize temp directory
#     use /temp disk to store temporary files for better performance
#     this program will clean-up the temp directory upon exiting.
#     TRUE  : fill create a temp directory in <progname>_tempdir_<PID> 
#     FALSE : will create a temp directory in root_directory
########################################
sub create_temp_dir {

    # get process id for this script/process
    my $pid = $$;

    # determine where to create temp directory - either in /temp/ or # $root_dir
    if ($use_tmp_disk == TRUE) {
	# use this scripts Process ID (PID) to make the directory name unique
	$temp_dir = "/tmp/${progname}_tempdir_$pid";

	# create the directory
	if (system ("/bin/mkdir $temp_dir") == 0) {
	    # successfully created temp directory
	    print "INFO  ($progname): Created temp directory in $temp_dir\n";

	    # return to calling subroutine
	    return $temp_dir;

	} else {
	    print "WARNING ($progname): Could not create temp directory in /temp.\n" .
	          "        $temp_dir\n";
	    # could not create temp directory - fail over and use
	    # $root_directory
	    $temp_dir = "$root_directory/${progname}_tempdir";

	    # tell script to use non-temp area
	    $use_tmp_disk = FALSE;
	}
    } 

    # setup to use $root_directory to create the temp directory
    if ($use_tmp_disk == FALSE) {
	# create temp directory in the $root_directory location
	$temp_dir = "$root_directory/${progname}_tempdir";

	# cleanup directory if it already exists
	if (-d $temp_dir) {
	    print "INFO  ($progname): Removing old temp directory\n" .
	          "      $temp_dir\n";
	    # call cleanup sub
            &cleanup_temp_dir();
	}

	# create the directory
	if (system ("/bin/mkdir $temp_dir") == 0) {
	    # successfully created temp directory
	    print "INFO  ($progname): Created temp directory in $temp_dir\n";

	    # return to calling subroutine
	    return $temp_dir;

	} else {
	    print "ERROR ($progname): Could not create temp directory.\n" .
	          "      Check that you have read/write permissions for this directory.\n" .
		  "      $temp_dir\n" .
		  "      Exiting...\n";
	    exit(1);
	}
    }

} # end of sub &create_temp_dir()


########################################
# sub to cleanup temp directory
#   because /temp/ is being used in some cases
#   it is cricial that this sub be run upon exiting this script
########################################
sub cleanup_temp_dir {

    # if the temp_dir has not yet been set, then there is not cleanup needed
    return if (! defined $temp_dir);

    # remove the temp directory
    if ( system("/bin/rm -fr $temp_dir" ) == 0 ) {
	print "INFO  ($progname): Temp directory cleaned up successfully.\n" .
	      "      $temp_dir \n";
    } else {
	print "ERROR ($progname): Temp directory cleaned up failed.\n" .
	      "      Manually clean-up the temp directory.\n" .
	      "      \%> \/bin\/rm -fr $temp_dir \n\n";
    }

} # end of sub &cleanup_temp_dir()


########################################
# sub to exit with clean-up
########################################
sub exit_prog {
    my ( $exit_code ) = @_;

    # this option is mostly for debug purposes
    if ( $cleanup_temp == TRUE ) {

	# call clean-up sub to clean-up temp directory before exiting
	&cleanup_temp_dir();
    }

    print "$progname exiting...\n";

    exit($exit_code);

} # end of sub &exit_prog()

########################################
# sub to find files in a given directory
########################################
sub run_file_find {
    # pass directory name into sub
    my ($dir) = @_;

    my $dir_basename = basename($dir);
    my $dir_list_file = "$temp_dir/$dir_basename.list";

    # command to find files and directories
    my $cmd = "$CeInit::CE_CMD_FIND './$dir_basename' -print > $dir_list_file ";
    if (system($cmd) == 0) {
        print "INFO: performed find on $dir -> list file $dir_list_file \n" if (defined $verbose);
    } else {
        print "ERROR ($progname): find command for $dir failed\n" .
	      "      $cmd\n";
    }

} # end of sub &run_file_find()

