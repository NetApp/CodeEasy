#!/router/bin/perl -w 
################################################################################
# CodeEasy Customer Toolkit Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to create/list/delete directories in the namespace.
#          
#
# Usage:   %> CeCreateDir.pl <args> 
#
# Author:  Michael Arndt (michael.arndt@netapp.com)
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

require 5.6.1;

use Cwd;
use Getopt::Long;  # Perl library for parsing command line options
use FindBin();     # The FindBin helps indentify the path this executable and thus its path
use strict;        # require strict programming rules
use warnings;

# load NetApp manageability SDK APIs
#   --> this is done in the CeCommon.pm package


############################################################
# Global Vars / Setup
############################################################

our $progname="CeCreateDir.pl";    # name of this program

# command line argument values
our $path;                         # cmdline arg: path of the directory to be created, listed, or removed.
our $perm;                         # cmdline arg: permissions for new directories (default 0755)
our $create_dir;                   # cmdline arg: create directory
our $list_dir;                     # cmdline arg: list directory
our $remove_dir;                   # cmdline arg: remove directory
our $test_only;                    # cmdline arg: test filer init then exit
our $verbose;                      # cmdline arg: verbosity level


# load CodeEasy packages
use lib "$FindBin::Bin/.";
use CeInit;        # contains CodeEasy script setup values
use CeCommon;      # contains CodeEasy common Perl functions; like &init_filer()

############################################################
# Start Program
############################################################

#--------------------------------------- 
# parse command line inputs
#--------------------------------------- 
&parse_cmd_line();

#--------------------------------------- 
# initialize access to NetApp filer
#--------------------------------------- 
our $naserver = &CeCommon::init_filer();

# test connection to filer only...
if (defined $test_only) {
   print "\nINFO  ($main::progname): Test ONTAP API access connectivity only...exiting.\n\n";
   exit 0;
}

#---------------------------------------
# create directory
#---------------------------------------
&create_dir()   if ($create_dir);

#---------------------------------------
# list directory
#---------------------------------------
&list_dir()   if ($list_dir);


#---------------------------------------
# remove directory
#---------------------------------------
&remove_dir()   if ($remove_dir);

# exit program successfully
print "\n$progname exited successfully.\n\n";
exit 0;


############################################################
# Subroutines
############################################################

########################################
# Command line Parser
########################################

sub parse_cmd_line {

  # parse command line 
  my $results = GetOptions (
              'h|help'             => sub { &show_help() },   

              'p|path=s'           => \$path,                    # directory path
              'm|perm=s'           => \$perm,                    # directory perms
              'c|create_dir'       => \$create_dir,              # create dir
              'l|list_dir'         => \$list_dir,                # list dir
              'r|remove_dir'       => \$remove_dir,              # remove dir

	      't|test'             => \$test_only,               # test filer connection then exit

              'v|verbose'          => \$verbose,                 # increase output verbosity
	      '<>'                 => sub { &CMDParseError() },
	      ); 

    # check for invalid options passed to GetOptions
    if ( $results != 1 ) {
       print "\nERROR: Invalid option(s) passed on the command line.\n" .
               "       For usage information type the following command;\n" .
               "       %> $progname -help\n\n";
       exit 1;
    }

    #---------------------------------------- 
    # check for correct inputs
    #---------------------------------------- 
    return if (defined $test_only);

    # check that a path was specified
    if (! defined $path) {
	print "ERROR ($progname): No path provided.\n" .
	      "      Use the -path <path> option.\n" .
	      "Exiting...\n\n";
	exit 1;

    }

    # Set default permission mode bits if not given.
    if (! defined $perm) {
        $perm = "0755";
    }

    # Make sure they specified and operation.
    if ((! defined $create_dir) && (! defined $list_dir) && (! defined $remove_dir)) {
	print "ERROR ($progname): No create/list/remove operation provided.\n" .
	      "Exiting...\n\n";
	exit 1;

    }

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
      -h|-help                       : show this help info

      -p|-path  <path>               : path to be operated on

      -m|-perm  <perms>              : unix permission mode bits (0755 default if not given)

      -c|-create_dir                 : create the given path in the namespace

      -l|-list_dir                   : list the given path in the namespace

      -r|-remove_dir                 : remove the given path in the namespace

      -v|-verbose                    : enable verbose output

      -t|-test                       : test connection to filer then exit
                                       recommended for initial setup testing and debug

      Examples:
	create a directory named dir1 under /workspace in the namespace
        %> $progname -path /workspace/dir1 -c 

	create a directory named dir1 under /workspace in the namespace with 0750 mode bits
        %> $progname -path /workspace/dir1 -perm 0750 -c

	list the contents of the /workspace portion of the namespace
        %> $progname -path /workspace -l 

	remove the directory named dir1 under /workspace in the namespace
        %> $progname -path /workspace/dir1 -r 

];

    print $helpTxt;
    exit 0;

} # end of sub &show_help()


###################################################################################
# create_dir:    create directory
#   $path:        the path to be created
#   $perm:        the permission mode bits to use
###################################################################################
sub create_dir { 

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    print "INFO  ($progname): Creating directory\n" .
          "      path         = $path\n" .
          "      perm         = $perm\n\n";
                  
    # Get the full path
    my $fullpath = get_fullpath($path);

    #--------------------------------------- 
    # create directory
    #--------------------------------------- 
    $out = $naserver->invoke("file-create-directory", "path", $fullpath,
                                                      "perm", $perm,
					     );

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
	# user friendly error message
	print "ERROR ($progname): Unable to create directory  '$path'\n"; 
        print "ERROR ($progname): file-create-directory returned with $errno reason: " . 
	                          '"' . $out->results_reason() . '"' . "\n";
        print "ERROR ($progname): Exiting with error.\n\n";

        exit 1;
    }

    print "INFO ($progname): Create directory <$path> successfully created.\n";

} # end of sub create_dir()


###################################################################################
# list_dir:    list directory
#   $path:        the path to be listed
###################################################################################
sub list_dir { 

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    print "INFO  ($progname): Listing directory <$path>\n\n";

    # Get the full path
    my $fullpath = get_fullpath($path);

    #--------------------------------------- 
    # list directory
    #--------------------------------------- 
    $out = $naserver->invoke("file-list-directory-iter", "path", $fullpath,
                                                         "max-records", "1000",
					     );

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
	# user friendly error message
	print "ERROR ($progname): Unable to list directory  '$path'\n"; 
        print "ERROR ($progname): file-create-directory returned with $errno reason: " . 
	                          '"' . $out->results_reason() . '"' . "\n";
        print "ERROR ($progname): Exiting with error.\n\n";

        exit 1;
    }

    # If we get here, show the API output. 
    print "Listing directory contents (up to 1000 entries):\n";
    my $file_info = $out->child_get("attributes-list");
    my @file_info = $file_info->children_get();
    for my $file (@file_info) {
        my $filename = $file->child_get_string("name");
        next if ($filename =~ /^\.+$/);
        print "$filename\n";
    }

    print "\n";
    print "INFO ($progname): list directory <$path> successfull.\n";

} # end of sub list_dir()


###################################################################################
# remove_dir:    remove directory
#   $path:        the path to be removed
###################################################################################
sub remove_dir { 

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    print "INFO  ($progname): Removing directory <$path>\n\n";
                  
    # Get the full path
    my $fullpath = get_fullpath($path);

    #--------------------------------------- 
    # remove directory
    #--------------------------------------- 
    $out = $naserver->invoke("file-delete-directory", "path", $fullpath);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
	# user friendly error message
	print "ERROR ($progname): Unable to remove directory  '$path'\n"; 
        print "ERROR ($progname): file-create-directory returned with $errno reason: " . 
	                          '"' . $out->results_reason() . '"' . "\n";
        print "ERROR ($progname): Exiting with error.\n\n";

        exit 1;
    }
    print "INFO ($progname): Remove directory <$path> successfully completed.\n";

} # end of sub remove_dir()


###################################################################################
# get_fullpath: get full path including root volume name
#   $path:        the relative path to be added in to the fullpath
###################################################################################
sub get_fullpath { 
    my ($path) = (@_);
    my ($out,$errno);

    #--------------------------------------- 
    # first we have to get the vserver root volume name.
    #--------------------------------------- 
    $out = $naserver->invoke("volume-get-root-name");
    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
	# user friendly error message
	print "ERROR ($progname): Unable to get vserver root volume name\n"; 
        print "ERROR ($progname): volume-get-root-name returned with $errno reason: " . 
	                          '"' . $out->results_reason() . '"' . "\n";
        print "ERROR ($progname): Exiting with error.\n\n";

        exit 1;
    }
    my $root_volume = $out->child_get_string("volume");
    my $fullpath = "/vol/" . $root_volume . $path;

    print "INFO ($progname): Fullpath is <$fullpath>.\n\n";

    return ($fullpath);

} # end of sub get_fullpath()
