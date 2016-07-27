#!/usr/bin/perl -w 
################################################################################
# CodeEasy Customer Toolkit Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to create/removes a volume 
#          
#
# Usage:   %> CeCreateVole.pl <args> 
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

# load CodeEasy packages
use lib "$FindBin::Bin/.";
use CeInit;        # contains CodeEasy script setup values (CeInit.pm file)
use CeCommon;      # contains CodeEasy common Perl functions; like &init_filer()


############################################################
# Global Vars / Setup
############################################################

our $progname="CeCreateVol.pl";    # name of this program

# command line argument values
our $volume;                       # cmdline arg: volume to create (default name: $CeInit::CE_DEFAULT_VOLUME_NAME)
our $remove_volume;                # cmdline arg: remove_volume
our $snapshot_create;              # cmdline arg: snapshot name to create
our $snapshot_delete;              # cmdline arg: snapshot name to delete
our $test_only;                    # cmdline arg: test filer init then exit
our $verbose;                      # cmdline arg: verbosity level



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
# create volume
#   a volume is created by default - unless the -remove option was given
#--------------------------------------- 
&create_volume()   if (! defined $remove_volume);


#--------------------------------------- 
# remove volume
#--------------------------------------- 
&remove_volume()   if ($remove_volume);


#--------------------------------------- 
# exit program successfully
#--------------------------------------- 
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
              'h|help'           => sub { &show_help() },   

              'vol|volume=s'     => \$volume,        # volume to create
	      'r|remove'         => \$remove_volume, # remove volume

	      't|test_only'      => \$test_only,     # test filer connection then exit

              'v|verbose'        => \$verbose,       # increase output verbosity
	      '<>'               => sub { &CMDParseError() },
	      ); 

    # check for invalid options passed to GetOptions
    if ( $results != 1 ) {
       print "\nERROR: Invalid option(s) passed on the command line.\n" .
               "       For usage information type the following command;\n" .
               "       %> $progname -help\n\n";
       exit 1;
    }

    # check if volume name was passed on the command line
    if ( defined $volume ) {
	# command line volume name 

    } elsif ( defined  $CeInit::CE_DEFAULT_VOLUME_NAME ){
	# use default volume name if it is specified in the CeInit.pm file
	$volume = "$CeInit::CE_DEFAULT_VOLUME_NAME";      
    } else {
	# no volume passed on the command line or set in the CeInit.pm file
	print "ERROR ($progname): No volume name provided.\n" .
	      "      use the -vol <volume name> option on the command line.\n" .
	      "      Exiting...\n";
	exit 1;
    }


} # end of sub parse_cmd_line()


########################################
# Error handling for cmd line parsing problems
########################################
sub CMDParseError {
    # report cmd line parsing errors, display help then exit
    print "\nERROR ($progname): Unrecognized command line option.\n" .
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

      -vol|-volume <volume name>  : volume name 
                                    default value is set in the CeInit.pm file
				    by var \$CeInit::CE_DEFAULT_VOLUME_NAME
    
      -r|-remove                  : remove volume 

      -v|-verbose                 : enable verbose output

      -t|-test                    : test connection to filer then exit

      Examples:
	create a volume named <ce_test_vol>
        %> $progname -vol ce_test_vol 

	remove a volume named <ce_test_vol>
        %> $progname -vol ce_test_vol -remove

];

    print $helpTxt;
    exit 0;

} # end of sub &show_help()




###################################################################################
# create_volume:    Create volume
#   $filer:           The filer in which the volume resides
#   $vserver:         The vserver in which the volume resides
#   $volume:          The volume to be created
#   $aggr:            The aggregate in which to create the volume
#   $user:            The integer user id that the volume belongs to
#   $group:           The integer group id that the volume belongs to
#   $volsize:         The size of the volume
#   $unixperm:        The unix permissions of the volume
#   $policy:          Export policy of volume
#   $snapshot_policy: The snapshot_policy for snapshots of volume
###################################################################################   
sub create_volume {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    #--------------------------------------- 
    # determine junction path  (mount point)
    #--------------------------------------- 
    # put the new volume at the end of the pre-mounted root directory
    # this will make it so the new volume will automatically be mounted

    # NOTE: volumes will be created by the common build user 'MASTER', so they will be mounted to the
    # CE_UNIX_MASTER_VOLUME_PATH vs the user path CE_UNIX_USER_FLEXCLONE_PATH

    my $junction_path = "$CeInit::CE_JUNCT_PATH_ROOT/$volume";
    my $UNIX_path     = "$CeInit::CE_UNIX_ROOT_VOLUME_PATH/$volume";
    print "INFO  ($progname): Creating new volume\n" .
          "      volume        = $volume\n" .
	  "      junction path = $junction_path \n" .
	  "      UNIX path     = $UNIX_path\n";

    #--------------------------------------- 
    # check that the volume does not already exists - if it does, then error
    #--------------------------------------- 
    # get list of volumes from the vserver
    my %volume_list = &CeCommon::getVolumeList($naserver);

    # check that the volume to create is not in the list of volumes available
    if (! defined $volume_list{$volume} ) {
	# the master volume must exist to clone 
	print "DEBUG: Volume '$volume' does not yet exists\n" if ($verbose);
    } else {
        # if not, then generate an error
	print "ERROR: Volume to create already exists.\n" .
	      "       Check that volume '$volume' is unique and does not already exist.\n" .
	      "       Exiting...\n\n";
	exit 1;
    }

    #--------------------------------------- 
    # Check for user approval
    #--------------------------------------- 
    print "\nPress 'y' to continue, or any other key to quit: ";
    my $input = <STDIN>;
    exit if $input ne "y\n";

    #--------------------------------------- 
    # create volume
    #--------------------------------------- 
    $out = $naserver->invoke("volume-create", "volume",               $volume, 
					      "junction-path",        $junction_path,
                                              @CeInit::CE_VOLUME_CREATE_REQUIRED,
                                              @CeInit::CE_VOLUME_CREATE_OPTIONS
					      );

    # check status of the volume creation
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to create volume $volume \n";
        print "ERROR ($progname): volume-create returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "\nINFO  ($progname): Volume: <$volume> successfully created.\n";

} # end of sub create_volume()



###################################################################################
# remove_volume:    Remove volume
#   $volume:          The volume to be removed
###################################################################################   
sub remove_volume {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    my $junction_path = "$CeInit::CE_JUNCT_PATH_ROOT/$volume";
    my $UNIX_path     = "$CeInit::CE_UNIX_ROOT_VOLUME_PATH/$volume";
    print "INFO  ($progname): Remove volume\n" .
          "      volume        = $volume\n" .
	  "      junction path = $junction_path \n" .
	  "      UNIX path     = $UNIX_path\n";

    #--------------------------------------- 
    # Check for user approval
    #--------------------------------------- 
    print "\nPress 'y' to continue, or any other key to quit: ";
    my $input = <STDIN>;
    exit if $input ne "y\n";

    #--------------------------------------- 
    # first make sure the volume is unmounted
    #--------------------------------------- 
    $out = $naserver->invoke("volume-unmount",  "volume-name",  $volume);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to unmount volume $volume \n";
        print "ERROR ($progname): volume-unmount returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        #print "ERROR ($progname): Exiting with error.\n";
        #exit 1;
    }
    print "INFO  ($progname): Volume <$volume> successfully unmounted \n";

    #--------------------------------------- 
    # 2nd make sure the volume is offline
    #--------------------------------------- 
    $out = $naserver->invoke("volume-offline",  "name",  $volume);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to take volume $volume offline\n";
        print "ERROR ($progname): volume-offline returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        #print "ERROR ($progname): Exiting with error.\n";
        #exit 1;
    }
    print "INFO  ($progname): Volume <$volume> successfully taken offline.\n";

    #--------------------------------------- 
    # 3rd remove/delete volume
    #--------------------------------------- 
    $out = $naserver->invoke("volume-destroy",  "name",         $volume);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to remove/destroy volume $volume \n";
        print "ERROR ($progname): volume-destroy returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO  ($progname): Volume <$volume> successfully removed.\n";

} # end of sub remove_volume()



