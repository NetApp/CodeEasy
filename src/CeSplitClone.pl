#!/usr/bin/perl -w 
################################################################################
# CodeEasy Customer Toolkit Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to convert a FlexClone into a normal volume.  This process
#          is called 'split'ing a Clone from its parent volume/snapshot pair
#          
#
# Usage:   %> CeSplitClone.pl <args> 
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

our $progname="CeSplitClone.pl";    # name of this program

# command line argument values
our $volume;                       # cmdline arg: volume to create (default name: $CeInit::CE_DEFAULT_VOLUME_NAME)
our $snapshot_name;                # cmdline arg: snapshot to use for clone image
our $clone_name;                   # cmdline arg: flexclone name - as mounted (as seen by the UNIX user)
our $flexclone_vol_name;           # cmdline arg: name of the flexclone volume name (as seen on the filer)
                                   #              (typically the same as flexclone name)
our $list_snapshots;               # cmdline arg: list available snapshots
our $list_flexclones;              # cmdline arg: list available flexclone volumes
our $volume_delete;                # cmdline arg: remove flexclone volume
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
exit 0    if (defined $test_only);

#--------------------------------------- 
# list available snapshots - then exit
#--------------------------------------- 
if (defined $list_snapshots) {
    &CeCommon::list_snapshots($naserver, $volume); # list available snapshots
    exit 0;
}

#--------------------------------------- 
# list Volumes - then exit
#--------------------------------------- 
&list_flexclones($naserver, $volume) if ($list_flexclones);

#--------------------------------------- 
# split estimate
#--------------------------------------- 
&split_estimate($clone_name );

#--------------------------------------- 
# split flexclone
#--------------------------------------- 
&split_clone($clone_name ); 



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
  GetOptions ("h|help"             => sub { &show_help() },   

	      'c|clone=s'          => \$clone_name,              # clone name
	      'fc_volname=s'       => \$flexclone_vol_name,         # optional: junction_path name

	      't|test'             => \$test_only,               # test filer connection then exit

              'v|verbose'          => \$verbose,                 # increase output verbosity
	      '<>'                 => sub { &CMDParseError() },
	      ); 

    #---------------------------------------- 
    # check for correct inputs
    #---------------------------------------- 

    # no further GetOps input checking if we are just listing the available flexclones
    return if (defined $list_flexclones);

    # check that a clone_name was specified
    if (! defined $clone_name) {
	print "ERROR ($progname): No FlexClone name provided.\n" .
	      "      Use the -clone <flexclone name> option.\n" .
	      "Exiting...\n\n";
	exit 1;
    }

    # flexclone volume name vs flexclone mount name
    if (defined $flexclone_vol_name) {
	# flexclone volume name will be different than the UNIX mounted
	# flexclone name
	print "DEBUG ($progname): FlexClone Volume Name passed on the command line = <$flexclone_vol_name)\n" if ($verbose);
    } else {
	# the flexclone volume and mount names will be the same
	$flexclone_vol_name = $clone_name;
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

      -cl|-clone <clone name>        : name of the new FlexClone volume to split
                                       (REQUIRED)

      -fc_volname <flexclone volume name>  
                                     : name of the FlexClone volume as stored on the filer
                                       (OPTIONAL) by default the FlexClone name will be used as 
				       the flexclone volume name.  But if there is a need for the flexclone
				       volume name to be different than the volume name seen by UNIX, then use this
				       option.

      -v|-verbose                    : enable verbose output

      -t|-test                       : test connection to filer then exit
                                       recommended for initial setup testing and debug

      Examples:
	create a FlexClone with the name <ce_test_vol>
	starting with snapshot
        %> $progname -clone    my_flexclone_ce_test 

];

    print $helpTxt;
    exit 0;

} # end of sub &show_help()


###################################################################################
# split_estimate      estimate the size of the new volume after split or separate 
#                     FlexClone from its parent volume/snapshot pair
#
# estimate clone size
#   my $out = $naserver->invoke("volume-clone-split-estimate", "volume", $clone_name);
###################################################################################
sub split_estimate { 

    # arguments passed into this sub
    my ( $clone_name 
	) = @_;

    # temp vars for getting filer info and status
    my $out;
    my $errno;


    print "INFO  ($progname): Estimating Split FlexClone volume\n" .
          "      flexclone volume name = $flexclone_vol_name\n\n";
                  
    #--------------------------------------- 
    # check flexclone already exists - if NOT error
    #--------------------------------------- 
    # get list of flexclones from the vserver
    my %clone_list = &CeCommon::getFlexCloneList($naserver);

    # check that the clone does not already exist
    if (! defined $clone_list{$flexclone_vol_name} ) {
	# the flexclone does not exists - error
	print "ERROR: The FlexClone '$flexclone_vol_name' doesn't exists.\n" .
	      "       Exiting...\n\n";
	exit 1;
    } else {
	print "DEBUG: FlexClone exists\n" if ($verbose);
    }

    #--------------------------------------- 
    # split flexclone
    #--------------------------------------- 
    $out = $naserver->invoke("volume-clone-split-estimate", "volume", $flexclone_vol_name,
						    );
    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
	# user friendly error message
	print "ERROR ($progname): Unable to return split-estimate information for FlexClone '$flexclone_vol_name'\n"; 
	# verbose debug
        print "ERROR ($progname): Unable to volume-clone-split-estimate $flexclone_vol_name \n";
        print "ERROR ($progname): volume-clone-create returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n" if ($verbose);
        print "ERROR ($progname): Exiting with error.\n\n";

        exit 1;
    }
    # get split estimate info

    my $estimate       = $out->child_get_string( "clone-split-estimate" );


    #--------------------------------------- 
    # Example: output of $estimate_block = $out->sprintf();
    #--------------------------------------- 
    #    <results status="passed">
    #	    <clone-split-estimate>
    #		    <clone-split-estimate-info>
    #			    <estimate-blocks>4078</estimate-blocks>
    #		    </clone-split-estimate-info>
    #	    </clone-split-estimate>
    #    </results>
    my $estimate_block = $out->sprintf();

    # grap just the block estimate value
    $estimate_block =~ /<estimate-blocks>(.*)<\/estimate-blocks>/;
    $estimate_block = $1;

    # split estimate value is returned in blocks rather than bytes
    my $split_est      = $estimate_block*4096; # blocks => Bytes
    # split estimate actual: space used - represent data used in MB
    $split_est      = $split_est/1024/1024; # date in MiB

    printf "INFO: Split estimate = %11.2f MB\n", $split_est;


} # end of sub split_estimate()




###################################################################################
# split_clone    split or separate FlexClone from its parent volume/snapshot pair
#   $clone:           name of the clone to split
#
# create clone from parent volume
#   my $out = $naserver->invoke("volume-clone-split-start",    "volume", $clone_name);
###################################################################################
sub split_clone { 

    # arguments passed into this sub
    my ( $clone_name 
	) = @_;

    # temp vars for getting filer info and status
    my $out;
    my $errno;


    print "INFO  ($progname): Split'ing FlexClone volume\n" .
          "      flexclone volume name = $flexclone_vol_name\n\n";
                  
    #--------------------------------------- 
    # check flexclone already exists - if NOT error
    #--------------------------------------- 
    # get list of flexclones from the vserver
    my %clone_list = &CeCommon::getFlexCloneList($naserver);

    # check that the clone does not already exist
    if (! defined $clone_list{$flexclone_vol_name} ) {
	# the flexclone does not exists - error
	print "ERROR: The FlexClone '$flexclone_vol_name' doesn't exists.\n" .
	      "       Exiting...\n\n";
	exit 1;
    } else {
	print "DEBUG: FlexClone exists\n" if ($verbose);
    }

    #--------------------------------------- 
    # split flexclone
    #--------------------------------------- 
    $out = $naserver->invoke("volume-clone-split-start", "volume", $flexclone_vol_name);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
	# user friendly error message
	print "ERROR ($progname): Unable to split FlexClone '$flexclone_vol_name'\n"; 
	# verbose debug
        print "ERROR ($progname): Unable to volume-clone-split-start $flexclone_vol_name \n";
        print "ERROR ($progname): volume-clone-create returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n" if ($verbose);
        print "ERROR ($progname): Exiting with error.\n\n";

        exit 1;
    }
    print "INFO ($progname): FlexClone <$clone_name> successfully split\n";


} # end of sub split_clone()





