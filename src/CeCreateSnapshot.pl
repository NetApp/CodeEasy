#!/usr/bin/perl -w 
################################################################################
# CodeEasy Customer Toolkit Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to create/remove a snapshot of a parent volume
#          
#
# Usage:   %> CeCreateSnapshot.pl <args> 
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
use CeInit;        # contains CodeEasy script setup values
use CeCommon;      # contains CodeEasy common Perl functions; like &init_filer()


############################################################
# Global Vars / Setup
############################################################

our $progname="CeCreateSnapshot.pl";    # name of this program

# command line argument values
our $volume;                       # cmdline arg: volume to create (default name: $CeInit::CE_DEFAULT_VOLUME_NAME)
our $snapshot_name;                # cmdline arg: snapshot name to create
our $snapshot_delete;              # cmdline arg: delete snapshot
our $list_snapshots;               # cmdline arg: list available snapshots
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
#exit 0    if (defined $test_only);

if (defined $test_only) {
   print "\nINFO  ($main::progname): Test ONTAP API access connectivity only...exiting.\n\n";
   exit 0;
}

#--------------------------------------- 
# list available snapshots
#--------------------------------------- 
if (defined $list_snapshots) {
    &CeCommon::list_snapshots($naserver, $volume); # list available snapshots
    exit 0;
}

#--------------------------------------- 
# create snapshot
#    create snapshot unless -remove option is provided on the cmdline
#--------------------------------------- 
&snapshot_create() if (! defined $snapshot_delete);


#--------------------------------------- 
# remove snapshot
#--------------------------------------- 
&snapshot_delete() if (defined $snapshot_delete);


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
  GetOptions ('h|help'           => sub { &show_help() },   

              'vol|volume=s'     => \$volume,            # volume to snapshot
	      's|snapshot=s'     => \$snapshot_name,     # snapshot name

	      'ls'               => \$list_snapshots,    # list available snapshots

	      'r|remove'         => \$snapshot_delete,   # remove snapshot

	      't|test_only'      => \$test_only,     # test filer connection then exit

              'v|verbose'        => \$verbose,           # increase output verbosity
	      '<>'               => sub { &CMDParseError() },
	      ); 


    # check if volume name was passed on the command line
    if (defined $volume ) {
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

      -vol|-volume   <volume name>    : source voj3j0
                                        default value is set in the CeInit.pm file
				        by var \$CeInit::CE_DEFAULT_VOLUME_NAME

      -s|-snapshot <snapshot name>    : name of the snapshot to create 

      -ls                             : list snapshots (exludes hourly, daily and weekly snapshots)

      -r|-remove                      : remove snapshot

      -v|-verbose                     : enable verbose output

      -t|-test                        : test connection to filer then exit

      Examples:
	create a snapshot for volume ce_test_vol
        %> $progname -volume ce_test_vol -snapshot ce_test_vol_snapshot_01 

];

    print $helpTxt;
    exit 0;

} # end of sub &show_help()



###################################################################################
# snapshot_create:    create snapshot of a volume
#   $volume:          The volume to be snap'd
#   $snapshot:        Snapshot name
#
#	snapshot-create -volume   $volume   \
#	                -snapshot $snapshot
#
###################################################################################
sub snapshot_create {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    print "INFO  ($progname): Creating snapshot '$snapshot_name' for volume '$volume'\n" .
	  "      UNIX path    = $CeInit::CE_UNIX_MASTER_VOLUME_PATH/.snapshot/$snapshot_name\n";

    #--------------------------------------- 
    # check if snapshot already exists
    #--------------------------------------- 
    # vserver>  vol snapshot show -volume project_A_jenkin_build 
    my %snapshot_list = &CeCommon::getSnapshotList($naserver, $volume);


    # check if the snapshot already exists.
    if (defined $snapshot_list{$snapshot_name} ) {
	print "\nERROR ($progname): Snapshot '$snapshot_name' already exists for volume '$volume'.\n" .
	        "      Try selecting a different snapshot name or delete this snapshot.\n" .
	        "Exiting...\n\n";
	exit 1;
    } 

    #--------------------------------------- 
    # create snapshot
    #--------------------------------------- 
    $out = $naserver->invoke("snapshot-create", "volume",   $volume, 
                                                "snapshot", $snapshot_name);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to create snapshot $volume \n";
        print "ERROR ($progname): snapshot-create returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "\nINFO  ($progname): Snapshot <$snapshot_name> successfully created.\n";


} # end of sub snapshot_create()


###################################################################################
# snapshot_delete:    remove snapshot
#   $volume:          The volume that contains the snapshot
#   $snapshot:        Snapshot name
#
#	snapshot-delete -volume   $volume   \
#	                -snapshot $snapshot
#
###################################################################################
sub snapshot_delete {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    print "INFO  ($progname): Deleting snapshot '$snapshot_name' for volume '$volume'\n";

    #--------------------------------------- 
    # check if snapshot does not exists
    #--------------------------------------- 
    # vserver>  vol snapshot show -volume project_A_jenkin_build 
    my %snapshot_list = &CeCommon::getSnapshotList($naserver, $volume);


    # check if the snapshot already exists.
    if (! defined $snapshot_list{$snapshot_name} ) {
	print "\nERROR ($progname): Snapshot '$snapshot_name' does not exist on volume '$volume'.\n" .
	        "      Check that you have specified the correct snapshot name.\n" .
	        "Exiting...\n\n";
	exit 1;
    } 


    #--------------------------------------- 
    # delete snapshot
    #--------------------------------------- 
    $out = $naserver->invoke("snapshot-delete", "volume",   $volume, 
                                                "snapshot", $snapshot_name);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to delete snapshot $snapshot_name \n";
        print "ERROR ($progname): snapshot-delete returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "\nINFO  ($progname): Snapshot <$snapshot_name> successfully deleted.\n";


} # end of sub snapshot_delete()


