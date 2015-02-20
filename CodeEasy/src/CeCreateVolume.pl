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
# Usage:   %> CeCreateVole.pl <args> 
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

our $progname="CeCreateVol.pl";    # name of this program

# command line argument values
our $volume  = "ce_test_vol";      # cmdline arg: volume to create (default name)
our $create_volume;                # cmdline arg: create_volume
our $remove_volume;                # cmdline arg: remove_volume
our $snapshot_create;              # cmdline arg: snapshot name to create
our $snapshot_delete;              # cmdline arg: snapshot name to delete
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
# create volume
#--------------------------------------- 
&create_volume()   if ($create_volume);


#--------------------------------------- 
# remove volume
#--------------------------------------- 
&remove_volume()   if ($remove_volume);


#--------------------------------------- 
# exit program successfully
#--------------------------------------- 
print "$progname exited successfully.\n\n";
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

              'vol|volume=s'     => \$volume,        # volume to create
	      'c|create'         => \$create_volume, # remove volume
	      'r|remove'         => \$remove_volume, # remove volume

              'v|verbose'        => \$verbose,       # increase output verbosity
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
      -h|-help                    : show this help info

      -vol|-volume <volume name>  : volume name 
                                    default value is ce_test_vol
      -c|-create                  : create volume
      -r|-remove                  : remove volume

      -v|-verbose                 : enable verbose output

      Examples:
	create a volume name <ce_test_vol>
        %> $progname -vol ce_test_vol

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

    # NOTE: volumes will be created by the DEAMON, so they will be mounted to the
    # CE_DAEMON_ROOT vs the CE_USER_ROOT

    my $junction_path = "$CeInit::CE_DAEMON_ROOT/$volume";

    #--------------------------------------- 
    # create volume
    #--------------------------------------- 
    $out = $naserver->invoke("volume-create", "volume",               $volume, 
					      "junction-path",        $junction_path,
                                              "containing-aggr-name", $CeInit::CE_AGGR, 
                                              "size",                 $CeInit::CE_DAEMON_VOL_SIZE, 
                                              "unix-permissions",     $CeInit::CE_UNIX_PERMISSIONS, 
                                              "export-policy",        $CeInit::CE_POLICY_EXPORT, 
                                              "snapshot-policy",      $CeInit::CE_SSPOLICY_DEVOPS_USER, 
                                              "space-reserve",        "none");

    # check status of the volume creation
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to create volume $volume \n";
        print "ERROR ($progname): volume-create returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO ($progname): Successfully created volume <$volume>\n";

} # end of sub create_volume()

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



