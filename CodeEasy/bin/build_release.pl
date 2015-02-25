#!/usr/bin/perl -w 
################################################################################
# CodeEasy build release script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to package up the CodeEasy eval kit. This script will NOT 
#          be shipped to the customer
#          
#
# Usage:   %> build_release.pl 
#
# Author:  Michael Johnson (michael.johnson@netapp.com)
#           
#
# Copyright 2015 NetApp
#
################################################################################

use Env;	   # Perl library which contains the ENV function;
use Cwd;
use Getopt::Long;  # Perl library for parsing command line options
use strict;        # require strict programming rules

# Use CSV package which is located in the same location as the executable.
# The FindBin helps indentify the path this executable and thus its path
use FindBin ();

# find this script's location
use lib "$FindBin::Bin/.";



############################################################
# Global Vars / Setup
############################################################
# determine date
my $date = `date`; chomp $date; $date =~ s/\s+/ /g;

our $progname="build_release.pl";    # name of this program

our $verbose;

# get location one level above this script
our $proj_dir    = "$FindBin::Bin/..";
our $release_dir = "$FindBin::Bin/../release";

# name of ther release comes from the bin/release_version file
our $version_name;

# list of things to package
our @packaging_list = ('src', 
                       'docs' 
		       );

# list of files to remove from the release directory
our @files_to_remove = ('src/fast_chown', 
                        'src/sur'
                        );


############################################################
# Start Program
############################################################

# parse command line inputs
&parse_cmd_line();

# release version info from file
&read_version_info();

# package the release
&package_release();


# exit program successfully
print "$progname exited successfully.\n" .
      "################################################################################\n\n";
exit 0;


############################################################
# Subroutines
############################################################

########################################
# Command line Parser
########################################

sub parse_cmd_line {

  # parse command line 
  GetOptions ("h|help"           => sub { &show_help() },   
              'v|verbose'        => \$verbose,       # increase output verbosity
	      '<>'               => sub { &CMDParseError() },
	      ); 

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
      -h|-help                    : show this help info

      -v|-verbose                 : enable verbose output

      Examples:
	build release
        %> $progname 

];

    print $helpTxt;
    exit 0;

} # end of sub &show_help()



########################################
# get version value from file
########################################
sub read_version_info {

    # get version info out of the bin/release_version file
    $version_name = `/bin/cat $proj_dir/bin/release_version`;
    # clean-up the version info - remove end chars and whitespace
    chomp $version_name;
    $version_name =~ s/\s//g;

    print "INFO: Building Version => $version_name\n";

} # end of sub &read_version_info();

########################################
# package release
########################################
sub package_release {

    my $cmd;

    # new release directory
    $release_dir = "$release_dir/$version_name";

    # make release directory
    $cmd = "/bin/mkdir -p $release_dir";
    if (system($cmd) == 0) {
	print "INFO ($progname): Successfully created release directory\n" .
	      "     $release_dir\n";
    } else {
	print "ERROR ($progname): failed to create release directory\n" .
	      "     $release_dir\n" .
	      "     Exiting...\n";
	exit 1;
    }

    # copy build directory into release area
    foreach my $item (@packaging_list) {

	# copy each item to the release area
	$cmd = "/bin/cp -r $proj_dir/$item $release_dir/.";
	print "DEBUG: $cmd\n";
	if (system($cmd) == 0) {
	    print "INFO ($progname): Successfully copied $item\n" .
		  "     $release_dir\n";
	} else {
	    print "ERROR ($progname): failed to copy $item to the $proj_dir\n" .
		  "     $release_dir\n" .
		  "     Exiting...\n";
	    exit 1;
	}

    }

    # clean-out all CVS directories from the release
    $cmd = qq[/bin/find $release_dir -type d -name CVS -exec /bin/rm -fr {} \\; ];
    if (system("$cmd") == 0) {
	print "INFO ($progname): Successfully removed CVS directories\n";
    } else {
	print "ERROR ($progname): failed to remove CVS directories\n" .
	      "     $cmd\n";
    }

    # remove misc files
    foreach my $file (@files_to_remove) {
	if (-e "$release_dir/$file" ) {
	    $cmd = "/bin/rm -f $release_dir/$file";
	    system($cmd);
	}
    }

    # generate tarball
    $cmd = "/bin/tar -zcvf ${release_dir}.tgz $release_dir";
    print "DEBUG: $cmd\n";
    if (system($cmd) == 0) {
	print "INFO ($progname): Release tarball ${release_dir}.tgz\n";
    } else {
	print "ERROR ($progname): failed to create release tarball\n" .
	      "     $cmd\n";
    }


} # end of sub &package_release();


