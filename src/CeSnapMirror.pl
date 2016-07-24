#!/usr/bin/perl -w 
################################################################################
# CodeEasy Customer Toolkit Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to snapmirror a volume 
#          
#
# Usage:   %> CeSnapMirror.pl <args> 
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

# load CodeEasy packages
use lib "$FindBin::Bin/.";
use CeInit;        # contains CodeEasy script setup values (CeInit.pm file)
use CeCommon;      # contains CodeEasy common Perl functions; like &init_filer()


############################################################
# Global Vars / Setup
############################################################

our $progname="CeSnapMirror.pl";    # name of this program

# command line argument values
our $volume;                       # cmdline arg: source volume for SnapMirror (default name: $CeInit::CE_DEFAULT_VOLUME_NAME)
our $new_volume;                   # cmdline arg: destination volume for SnapMirror
our $new_aggr;                     # cmdline arg: destination aggregate for SnapMirror
our $status_only;                  # cmdline arg: check the status of the relationship
our $update_only;                  # cmdline arg: perform a snapmirror update
our $break_only;                   # cmdline arg: break off the snapmirror relationship
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
exit 0    if (defined $test_only);


#--------------------------------------- 
# create snapmirror
#--------------------------------------- 
if ((! defined $status_only) && (! defined $update_only) && (! defined $break_only)) {
    &create_dp_volume();
    &create_snapmirror();
}

#--------------------------------------- 
# status of snapmirror
#--------------------------------------- 
&status_snapmirror()   if ($status_only);

#--------------------------------------- 
# update snapmirror
#--------------------------------------- 
&update_snapmirror()   if ($update_only);

#--------------------------------------- 
# break snapmirror
#--------------------------------------- 
&break_snapmirror()   if ($break_only);


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
  GetOptions ("h|help"           => sub { &show_help() },   

              'vol|volume=s'     => \$volume,        # src volume
              'new|new_volume=s' => \$new_volume,    # dst volume 
              'aggr|new_aggr=s'  => \$new_aggr,      # dst aggr
              's|status'         => \$status_only,   # check status of relationship for new_volume
              'u|update'         => \$update_only,   # update relationship for new_volume
              'b|break'          => \$break_only,    # break relationship for new_volume

	      't|test_only'      => \$test_only,     # test filer connection then exit

              'v|verbose'        => \$verbose,       # increase output verbosity
	      '<>'               => sub { &CMDParseError() },
	      ); 


    # check if volume and new_volume was passed on the command line for create or break.
    if ((! $status_only) && (! $update_only)) {
        if ((! defined $volume) || (! defined $new_volume)) {
	    # no volume passed on the command line or set in the CeInit.pm file
	    print "ERROR ($progname): No volume name or new_volume name provided.\n" .
	          "      use the -vol <volume name>  and -new <volume name> options on the command line.\n" .
	          "      Exiting...\n";
	    exit 1;
        }
    }

    # check for new_volume if we are doing a status or update.
    if (($status_only) || ($update_only)) {
        if (! defined $new_volume) {
	    print "ERROR ($progname): No new_volume name provided.\n" .
	          "      use the -new <volume name> option on the command line.\n" .
	          "      Exiting...\n";
	    exit 1;
        }
    }

    # check for new_aggr if we are creating a new relationship
    if ((! $status_only) && (! $update_only) && (! $break_only)) {
        if ((! defined $new_volume) || (! defined $new_aggr)) {
	    print "ERROR ($progname): No new_volume or new_aggr name provided.\n" .
	          "      use the -new <volume name> and -aggr <aggr name> options on the command line.\n" .
	          "      Exiting...\n";
	    exit 1;
            
        }
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
      -h|-help                        : show this help info

      -vol|-volume <volume name>      : volume name 
                                        default value is set in the CeInit.pm file
				        by var \$CeInit::CE_DEFAULT_VOLUME_NAME
    
      -new|-new_volume <volume name>  : new volume name 

      -aggr|-new_aggr <aggr name>     : new aggr name 

      -s|-status                      : check the SnapMirror status for new_volume

      -u|-update                      : update the SnapMirror for new_volume

      -b|-break                       : break the SnapMirror for new_volume 

      -v|-verbose                     : enable verbose output

      -t|-test                        : test connection to filer then exit

      Examples:
	start a new SnapMirror relationship from <vol1> to <vol2>
        %> $progname -vol vol1 -new vol2 -aggr aggr1

	check the status of a SnapMirror relationship for <vol2>
        %> $progname -new vol2 -status

	update the SnapMirror relationship for <vol2>
        %> $progname -new vol2 -update

	break off and cleanup the SnapMirror relationship for <vol2>
        %> $progname -vol vol1 -new vol2 -break

];

    print $helpTxt;
    exit 0;

} # end of sub &show_help()


###################################################################################
# create_dp_volume:   Create a type DP volume
#   $volume:          The source volume to be used for sizing
#   $new_volume:      The new volume to be created
#   $new_aggr:        The aggregate in which to create the volume
###################################################################################   
sub create_dp_volume {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    #--------------------------------------- 
    # check that the volume does not already exists - if it does, then error
    #--------------------------------------- 
    # get list of volumes from the vserver
    my %volume_list = &CeCommon::getVolumeList($naserver);

    # check that the volume to create is not in the list of volumes available
    if (! defined $volume_list{$new_volume} ) {
	# the master volume must exist to clone 
	print "DEBUG: Volume '$new_volume' does not yet exists\n" if ($verbose);
    } else {
        # if not, then generate an error
	print "ERROR: Volume to create already exists.\n" .
	      "       Check that volume '$new_volume' is unique and does not already exist.\n" .
	      "       Exiting...\n\n";
	exit 1;
    }

    #--------------------------------------- 
    # Find the source volume export polciy
    #--------------------------------------- 
    my @slist = &CeCommon::vGetcDOTList( $naserver, "volume-get-iter" );
    if ($#slist == 0) {
        print "ERROR ($progname): Error running volume-get-iter.  Exiting.\n";
        exit 1;
    } 
    my $policy;
    foreach my $source_volume (@slist) {
	my $id_attrs   = $source_volume->child_get("volume-id-attributes");
        my $found_vol  = $id_attrs->child_get_string("name");
	next unless ($found_vol eq $volume);
	my $export_attrs = $source_volume->child_get("volume-export-attributes");
        $policy = $export_attrs->child_get_string("policy");
    }
    if (! defined $policy) {
        print "ERROR ($progname): Error running finding export policy for $volume.  Exiting.\n";
        exit 1;
    } 

    #--------------------------------------- 
    # create volume
    #--------------------------------------- 
    $out = $naserver->invoke("volume-create", "volume",               $new_volume, 
					      "containing-aggr-name", $new_aggr,
					      "size",                 $volume_list{$volume},
					      "space-reserve",        "none",
					      "export-policy",        $policy,
					      "volume-type",          "dp"
					      );

    # check status of the volume creation
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to create volume $new_volume \n";
        print "ERROR ($progname): volume-create returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "\nINFO  ($progname): Volume: <$new_volume> successfully created.\n";

} # end of sub create_dp_volume()


###################################################################################
# create_snapmirror:  Create SnapMirror relationship
#   $volume:          The source volume
#   $new_volume:      The destiation volume 
###################################################################################   
sub create_snapmirror {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    #--------------------------------------- 
    # Create the relationship
    #--------------------------------------- 
    $out = $naserver->invoke("snapmirror-create", "source-volume",       $volume, 
					          "source-vserver",      $CeInit::CE_VSERVER,
					          "destination-volume",  $new_volume,
					          "destination-vserver", $CeInit::CE_VSERVER,
					          "relationship-type",   "data_protection"
					      );

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to create snapmirror\n";
        print "ERROR ($progname): snapmirror-create returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO  ($progname): snapmirror-create <$volume> -> <$new_volume> finished successfully.\n";

    #--------------------------------------- 
    # Initialize the relationship
    #--------------------------------------- 
    $out = $naserver->invoke("snapmirror-initialize", "destination-volume", $new_volume
					      );

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to initialize snapmirror\n";
        print "ERROR ($progname): snapmirror-initialize returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO  ($progname): snapmirror-initialize <$volume> -> <$new_volume> finished successfully.\n";

} # end of sub create_snapmirror()


###################################################################################
# update_snapmirror:  Update SnapMirror relationship
#   $volume:          The source volume
#   $new_volume:      The destiation volume 
###################################################################################   
sub update_snapmirror {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    #--------------------------------------- 
    # Update the relationship
    #--------------------------------------- 
    $out = $naserver->invoke("snapmirror-update", "destination-volume", $new_volume
					      );

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to update snapmirror\n";
        print "ERROR ($progname): snapmirror-update returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO  ($progname): snapmirror-update of <$new_volume> finished successfully.\n";

} # end of sub update_snapmirror()


###################################################################################
# break_snapmirror:   Break SnapMirror relationship
#   $new_volume:      The destiation volume 
###################################################################################   
sub break_snapmirror {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    #--------------------------------------- 
    # Break the relationship
    #--------------------------------------- 
    $out = $naserver->invoke("snapmirror-break", "destination-volume", $new_volume
					      );

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to break snapmirror\n";
        print "ERROR ($progname): snapmirror-break returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO  ($progname): snapmirror-break of <$new_volume> finished successfully.\n";

    #--------------------------------------- 
    # Relase the relationship on the source volume
    #--------------------------------------- 
    $out = $naserver->invoke("snapmirror-release", "source-volume",       $volume, 
					           "source-vserver",      $CeInit::CE_VSERVER,
					           "destination-volume",  $new_volume,
					           "destination-vserver", $CeInit::CE_VSERVER
					       );

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to release snapmirror\n";
        print "ERROR ($progname): snapmirror-release returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO  ($progname): snapmirror-release of <$new_volume> from <$volume> finished successfully.\n";

    #--------------------------------------- 
    # Destroy the snapmirror relationship
    #--------------------------------------- 
    $out = $naserver->invoke("snapmirror-destroy", "source-volume",       $volume, 
					           "source-vserver",      $CeInit::CE_VSERVER,
					           "destination-volume",  $new_volume,
					           "destination-vserver", $CeInit::CE_VSERVER
					       );

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to destroy snapmirror\n";
        print "ERROR ($progname): snapmirror-destroy returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO  ($progname): snapmirror-destroy of <$new_volume> from <$volume> finished successfully.\n";

    #--------------------------------------- 
    # Mount new_volume in the namespace
    #--------------------------------------- 
    my $junction_path = "$CeInit::CE_JUNCT_PATH_SNAPS/$new_volume";
    $out = $naserver->invoke("volume-mount", "volume-name",   $new_volume, 
					     "junction-path", $junction_path
					    );

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to mount volume\n";
        print "ERROR ($progname): volume-mount returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO  ($progname): volume-mount of <$new_volume> as $junction_path finished successfully.\n";

} # end of sub break_snapmirror()


###################################################################################
# status_snapmirror:  Show the status of the SnapMirror relationship
#   $new_volume:      The destiation volume 
###################################################################################   
sub status_snapmirror {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    #--------------------------------------- 
    # Get the status of the relationship
    #--------------------------------------- 
    my @slist = &CeCommon::vGetcDOTList( $naserver, "snapmirror-get-iter" );
    if ($#slist == 0) {
        print "ERROR ($progname): Error running snapmirror-get-iter.  Exiting.\n";
        exit 1;
    }
    printf "%-26s %-26s %-14s %-14s %-10s %6s\n", "Source Volume", "Destination Volume", "State", "Status", "Progress", "Lag (s)";
    print  "------------------------------------------------------------------------------------------------------\n";
    foreach my $snapmirror (@slist) {
        my $src_vol    = $snapmirror->child_get_string("source-volume");
        my $dst_vol    = $snapmirror->child_get_string("destination-volume");
        my $smstate    = $snapmirror->child_get_string("mirror-state");
        my $smstatus   = $snapmirror->child_get_string("relationship-status");
        my $smprogress = $snapmirror->child_get_string("relationship-progress");
        my $smlag      = $snapmirror->child_get_string("lag-time");
        if (! defined $smprogress) {
	    $smprogress = "-" 
        } else {
	    $smprogress = sprintf "%0.1f GB", $smprogress / (1024*1024*1024);
        }
	$smlag         = "-" if (! defined $smlag);
	next unless ($dst_vol eq $new_volume);
        printf "%-26s %-26s %-14s %-14s %-10s %-6s\n", $src_vol, $dst_vol, $smstate, $smstatus, $smprogress, $smlag;
    }

} # end of sub status_snapmirror()
