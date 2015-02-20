#!/usr/bin/perl -w 
################################################################################
# CodeEasy Customer Evaluation Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to create flexclone of a parent volume snapshot
#          
#
# Usage:   %> CeCreateFlexClone.pl <args> 
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

# The FindBin helps indentify the path this executable and thus its path
use FindBin();

# load NetApp manageability SDK APIs
use lib "$FindBin::Bin/../netapp-manageability-sdk-5.2.2/lib/perl/NetApp";
use NaServer;
use NaElement;

# load CodeEasy packages
use lib "$FindBin::Bin/.";
use CeInit;        # contains CodeEasy script setup values
use CeCommon;      # contains CodeEasy common Perl functions; like &init_filer()


############################################################
# Global Vars / Setup
############################################################
# determine date
my $date = `date`; chomp $date; $date =~ s/\s+/ /g;

our $progname="CeCreateFlexClone.pl";    # name of this program

# command line argument values
our $volume  = "ce_test_vol";      # cmdline arg: volume to create (default name)
our $create_clone;                 # cmdline arg: create_clone
our $remove_volume;                # cmdline arg: remove_volume
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


#--------------------------------------- 
# create flexclone
#--------------------------------------- 
my $parent_snapshot = "mj_snap3";
my $clone_name = "${parent_snapshot}_clone";
&clone_create($volume, $parent_snapshot, $clone_name ) if ($create_clone);


#--------------------------------------- 
# remove volume (NOTE: removing a FlexClone is identical to removing a volume)
#--------------------------------------- 
&remove_volume() if ($remove_volume);


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

              'vol|volume=s'     => \$volume,               # volume to create
	      's|snapshot=s'     => \$snapshot_create,      # snapshot name
	      'cl|clone=s'       => \$clone_name,           # clone name
	      'c|create'         => \$create_volume,        # create clone volume
	      'r|remove'         => \$remove_volume,        # remove clone volume

              'v|verbose'        => \$verbose,              # increase output verbosity
	      '<>'               => sub { &CMDParseError() },
	      ); 

    # check that at least one of the actions has been selected
    if ((! defined $create_volume) and (! defined $remove_volume)) {
        print "\nERROR ($progname): An action has not been specified.  Either -create or -remove volume\n" .
              "       must be specified on the command line.\n" .
              "       Exiting...\n\n";
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

      -vol|-volume <volume name>     : volume name 
                                       default value is ce_test_vol
      -s |-snapshot <snapshot name>  : name of the snapshot to clone
      -cl|-clone    <clone name>     : name of the snapshot to clone
      -c|-create                     : create volume
      -r|-remove                     : remove volume

      -v|-verbose                    : enable verbose output

      Examples:
	create a FlexClone with the name <ce_test_vol>
	starting with snapshot
        %> $progname -vol ce_test_vol -snapshot ce_test_snapshot -clone %my_flexclone_ce_test

];

    print $helpTxt;
    exit 0;

} # end of sub &show_help()



###################################################################################
# clone_create:    create flexclone of an existing snapshot
#   $volume:          The volume that contains the snapshot
#   $snapshot:        name of the parent snapshot to clone
#   $clone:           name of the new clone to create
###################################################################################
# create clone from parent volume
#   my $out = $naserver->invoke("volume-clone-create", "parent-snapshot", $snapshot, 
#                                                      "parent-volume",   $volume, 
#                                                      "volume",          $clone_name,
#                                                      "junction-path",   $junction_path
sub clone_create { 

    # arguments passed into sub
    my ($volume, $parent_snapshot,
        $clone_name ) = @_;

    # temp vars for getting filer info and status
    my $out;
    my $errno;


    #--------------------------------------- 
    # determine junction path  (mount point)
    #--------------------------------------- 
    # put the new volume at the end of the pre-mounted root directory
    # this will make it so the new volume will automatically be mounted

    # NOTE: clones will be created by users, so they will be mounted to the
    # CE_USER_ROOT vs the CE_DAEMON_ROOT
    my $junction_path = "$CeInit::CE_USER_ROOT/$clone_name";


    #--------------------------------------- 
    # create flexclone
    #--------------------------------------- 
    $out = $naserver->invoke("volume-clone-create", "parent-volume",   $volume, 
                                                    "parent-snapshot", $parent_snapshot,
                                                    "volume",          $clone_name,
						    "junction-path",   $junction_path
						    );

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to volume-clone-create snapshot $parent_snapshot \n";
        print "ERROR ($progname): volume-clone-create returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO ($progname): Successfully clone of snapshot <$clone_name> \n" .
          "                  at junction-path <$junction_path>\n";


    #--------------------------------------- 
    # change permission of clone from the original snapshot owner
    # to the current user.
    #--------------------------------------- 
    &chown_clone();


} # end of sub clone_create()



###################################################################################
# chown_clone:    change the ownership of the flexclone
#   $volume:          The volume that contains the snapshot
#   $snapshot:        name of the parent snapshot to clone
#   $clone:           name of the new clone to create
###################################################################################
sub chown_clone {

} # end of sub &chown_clone();



###################################################################################
# remove_volume:    Remove volume
#   $volume:          The volume to be removed
###################################################################################   
sub remove_volume {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

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
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO ($progname): Successfully unmounted volume <$volume>\n";

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
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO ($progname): Successfully took volume <$volume> offline\n";

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
    print "INFO ($progname): Successfully removed volume <$volume>\n";

} # end of sub remove_volume()



