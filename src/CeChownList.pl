#!/usr/bin/perl -w 
################################################################################
# CodeEasy Customer Toolkit Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to change file ownership on a set of file provided from 
#          a list.  This script was developed to change the ownership
#          of a FlexClone volume and thus must be VERY fast due to the number
#          of files in a full volume.
#
#          The file list can be used to perform the chown (permissions)
#          changes on a FlexVolume.
#          
#
# Usage:   %> CeChownList.pl -d <root directory> -f <input filelist name>
#
# Author:  Michael Johnson (michael.johnson@netapp.com)
#           
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


############################################################
# Global Vars / Setup
############################################################
use constant TRUE  => 1;
use constant FALSE => 0;


# command line argument values
our $root_directory;                 # full path of the top level directory to scan
our $gen_filelist;                   # generate filelist_BOM cmd line arg
our $filelist_BOM;                   # name of filelist to generate
our $filelist_BOM_defaultname = "filelist_BOM";  # default filefile name
our $username;                       # username for chown operation
our $verbose;                        # cmdline arg: verbosity level

our $progname="CeChownList.pl";    # name of this program

# location of fast_chown program - typically compiled into the same directory
# as this script
my $fast_chown_exe = "$FindBin::Bin/fast_chown";

# define max parallel threads to use with xargs -p <max threads>
our $max_thread_count = 140;


###################################################################################
# Start Program
###################################################################################

# parse command line inputs
&parse_cmd_line();

# check that fast_chown.pl can be found - it needs to be compiled
if (! -e $fast_chown_exe) {
    print "ERROR ($progname): fast_chown program not found\n" .
          "      Expecting to find $fast_chown_exe\n";
    exit(1);
} 
print "INFO ($progname): Using the following fast_chown executable.\n" .
      "     $fast_chown_exe\n\n";

# for optimization purposes only show who is running this process with verbose option
if (defined $verbose) {
    my $whoami = `whoami`;
    chomp $whoami;
    print "INFO:  Script running as user <$whoami>\n";
}


# generate filelist_BOM 
&gen_filelist_BOM if (defined $gen_filelist);

# generate file list
&chmod_filelist_BOM();


# exit program successfully
exit(0);



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
	      'g|gen_file'    => \$gen_filelist,             # gen file BOM file list
	      'f|filelist=s'  => \$filelist_BOM,         # name of filelist to read
	      'u|user=s'      => \$username,             # username for chown operation
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

	print "INFO  ($progname): Preparing to chmod root directory\n" .
	      "      $root_directory\n" if (defined $verbose);
    } else {
	print "\nERROR ($progname): Directory $root_directory does not exist.\n" .
	        "      Check that the directory is a full UNIX path and exists.\n" .
	        "      Exiting...\n\n";
	exit 1;
    }

    # check that at least one of the actions has been selected
    if (! defined $filelist_BOM) {
	# use the default filename 
	$filelist_BOM = "$root_directory/$filelist_BOM_defaultname";
    } 

    # check that the filelist actually exists
    if (! -e $filelist_BOM ) {
	print "\nERROR ($progname): Filelist not found. Check file passed on the command line.\n" .
	        "      $filelist_BOM\n" .
	        "      Exiting...\n\n";
	exit(1);
    }

    # check that a username was provided and is a valid username
    if (! defined $username ) {
	print "\nERROR ($progname): Username argument was not passed on the command line.\n" .
	        "      Exiting...\n\n";
	exit(1);
    }
    if (system("id $username") == 0) {
	# username was found 
    } else {
	print "\nERROR ($progname): Username '$username' does not appear to be a valid username.\n" .
	        "      \%> id $username       => failed!\n" .
	        "      Exiting...\n\n";
	exit(1);
    }

} # end of sub parse_cmd_line()


########################################
# Error handling for cmd line parsing problems
########################################
sub CMDParseError {
    # report cmd line parsing errors, display help then exit
    print "\nERROR ($progname): Unrecognized command line option.\n" .
            "       @ARGV\n" .
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

      -d|-directory <directory name>  : root directory to chmod

      -g|-gen_file                    : generate filelist_BOM before running chown

      -f|-filelist  <filelist name>   : name of the filelist to read
                                        default=<directory name>/filelist_BOM
                                        (optional) 

      -u|-user <username>             : username for chown command

      -v|-verbose                     : enable verbose output

      Examples:
	create a filelist called /my_path/dir_to_scan/filelist.BOM
        %> $progname -user user_larry -d /my_path/dir_to_chmod/ -f /my_path/filelist_BOM

];

    print $helpTxt;


    # check that fast_chown.pl can be found - it needs to be compiled
    if (! -e $fast_chown_exe) {
	print "ERROR ($progname): fast_chown program not found\n" .
	      "      Expecting to find $fast_chown_exe\n" .
	      "      fast_chown must be compiled using the supplied Makefile\n\n";
	exit(1);
    } 
    print "INFO ($progname): Using the following fast_chown executable $fast_chown_exe\n\n";

    exit 0;

} # end of sub &show_help()

########################################
# generate filelist BOM
# essentially call CeFileListGen.pl before running chmod
########################################
sub gen_filelist_BOM {

    my $cmd = "$FindBin::Bin/CeFileListGen.pl";

    # check that the file list generator script is found 
    if (! -e  "$cmd") {
	print "ERROR: $cmd not found. \n";
	exit 1;
    }

    # generate filelist_BOM
    $cmd = "$cmd -d $root_directory";
    print "INFO:  Generating file list BOM\n" .
          "       $cmd\n";

    if (system($cmd) == 0) {
	print "INFO:  Successfully generated file list BOM\n";
    } else {
	print "ERROR: Generated file list BOM failed\n" .
	      "       $cmd\n" .
	      "Exiting...\n";
	exit 1;
    }

} # end of sub &gen_filelist_BOM

########################################
# chmod_filelist_BOM
#   This subroutine chmods all files and directories specified in 
#   a file list BOM (bill of materials). This was designed to change the 
#   ownership on the FlexClone volume.
#
#   This sub is written/optimized for very deep very high file count
#   directories. This sub uses parallel threads to accellerate the generation
#   of the file list.
#
########################################
sub chmod_filelist_BOM {

    # change to the root_directory so the find is a relative path
    chdir $root_directory;

    # xargs is capable of multi-threading the args passed to it. The
    # $max_thread_count variable set at the top of this script controls how
    # many parallel threads xargs launches.  

    # dump the content ofthe filelist into xargs to take care of processing
    # as many files and directories as it can at a time - xargs will then run
    # the 'fast_chown' script
    #  %> fast_chown <username> <file1...filen>
    my $cmd = "/bin/cat $filelist_BOM \| sudo /usr/bin/xargs -P $max_thread_count $fast_chown_exe $username ";

    # OR use the standard UNIX chown command - this is a little slower
    #my $cmd = "/bin/cat $filelist_BOM \| sudo /usr/bin/xargs -P $max_thread_count /bin/chown $username ";

    print "INFO: Running chown\n" .
          "      $cmd\n";
    system($cmd);

    print "      Finished running chown\n\n";

} # end of sub &chmod_filelist_BOM()


