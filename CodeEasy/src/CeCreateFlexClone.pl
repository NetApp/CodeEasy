#!/usr/bin/perl -w 
################################################################################
# CodeEasy Customer Evaluation Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to create flexclone of a parent volume snapshot based on 
#          a particular snapshot name
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

use Cwd;
use Getopt::Long;  # Perl library for parsing command line options
use FindBin();     # The FindBin helps indentify the path this executable and thus its path
use strict;        # require strict programming rules

# load NetApp manageability SDK APIs
#   --> this is done in the CeCommon.pm package

# load CodeEasy packages
use lib "$FindBin::Bin/.";
use CeInit;        # contains CodeEasy script setup values
use CeCommon;      # contains CodeEasy common Perl functions; like &init_filer()


############################################################
# Global Vars / Setup
############################################################

our $progname="CeCreateFlexClone.pl";    # name of this program

# command line argument values
our $volume;                       # cmdline arg: volume to create (default name: $CeInit::CE_DEFAULT_VOLUME_NAME)
our $snapshot_name;                # cmdline arg: snapshot to use for clone image
our $clone_name;                   # cmdline arg: create_clone
our $volume_delete;                # cmdline arg: remove volume
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
# create flexclone
#    flexclone volume is created by default - unless -remove is specified
#--------------------------------------- 
&clone_create($volume, $snapshot_name, $clone_name ) if (! defined $volume_delete);


#--------------------------------------- 
# remove volume (NOTE: removing a FlexClone is identical to removing a volume)
#--------------------------------------- 
&remove_volume() if ($volume_delete);


# exit program successfully
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

              'vol|volume=s'     => \$volume,               # volume to create
	      's|snapshot=s'     => \$snapshot_name,        # snapshot name
	      'cl|clone=s'       => \$clone_name,           # clone name

	      'r|remove'         => \$volume_delete,        # remove clone volume

	      't|test_only'      => \$test_only,            # test filer connection then exit

              'v|verbose'        => \$verbose,              # increase output verbosity
	      '<>'               => sub { &CMDParseError() },
	      ); 

    # check if volume name was passed on the command line
    if (defined $volume ) {
	# use volume name passed from the command line 

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

    # check that a snapshot and clone_name were specified
    if (! defined $snapshot_name) {
	print "ERROR ($progname): No SnapShot name provided.\n" .
	      "      Use the -snapshot <snap_name> option.\n" .
	      "Exiting...\n";
	exit 1;

    }

    # check that a snapshot and clone_name were specified
    if (! defined $snapshot_name) {
	print "ERROR ($progname): No SnapShot name provided.\n" .
	      "      Use the -snapshot <snap_name> option.\n" .
	      "Exiting...\n";
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

      -vol|-volume  <volume name>    : volume name 
                                       default value is set in the CeInit.pm file
				       by var \$CeInit::CE_DEFAULT_VOLUME_NAME

      -s |-snapshot <snapshot name>  : name of the Snapshot  to clone
      -cl|-clone    <clone name>     : name of the FlexClone to create
    
      -r|-remove                     : remove volume

      -v|-verbose                    : enable verbose output

      Examples:
	create a FlexClone with the name <ce_test_vol>
	starting with snapshot
        %> $progname -volume ce_test_vol -snapshot ce_test_snapshot \
	             -clone  my_flexclone_ce_test 

];

    print $helpTxt;
    exit 0;

} # end of sub &show_help()



###################################################################################
# clone_create:    create flexclone of an existing snapshot
#   $volume:          The volume that contains the snapshot
#   $snapshot:        name of the parent snapshot to clone
#   $clone:           name of the new clone to create
#
# create clone from parent volume
#   my $out = $naserver->invoke("volume-clone-create", "parent-snapshot", $snapshot, 
#                                                      "parent-volume",   $volume, 
#                                                      "volume",          $clone_name,
#                                                      "junction-path",   $junction_path
###################################################################################
sub clone_create { 

    # arguments passed into this sub
    my ($volume, 
        $parent_snapshot,
        $clone_name 
	) = @_;

    # temp vars for getting filer info and status
    my $out;
    my $errno;


    #--------------------------------------- 
    # get current users name and
    # make sure user has a directory at mount point
    #--------------------------------------- 
    my $username = getpwuid( $< ); chomp $username;
    my $UNIX_mount_dir = "$CeInit::CE_USER_ROOT/$username";

    # create user path directory
    if ( system ("/bin/mkdir -p $UNIX_mount_dir") == 0) {
	print "ERROR ($progname): Could not create user workspace.\n" .
	      "      $UNIX_mount_dir\n";
    }
    print "INFO  ($progname): FleClone volume will be mounted at $UNIX_mount_dir\n";


    #--------------------------------------- 
    # determine junction path  (mount point)
    #--------------------------------------- 
    # put the new volume at the end of the pre-mounted root directory
    # this will make it so the new volume will automatically be mounted

    # NOTE: clones will be created by users, so they will be mounted to the
    # CE_MOUNT_USER_ROOT vs the CE_MOUNT_DAEMON_ROOT
    my $junction_path = "$CeInit::CE_MOUNT_USER_ROOT/$username/$clone_name";

    print "INFO : clone_name      = $clone_name\n" .
          "       parent-volume   = $volume\n" .
          "       parent-snapshot = $parent_snapshot\n" .
          "       junction path   = $junction_path \n" .
          "       UNIX Mount path = $UNIX_mount_dir/$clone_name \n";
                  

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
    $out = $naserver->invoke("volume-unmount",  "volume-name",  $clone_name);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to unmount FlexClone volume $clone_name\n";
        print "ERROR ($progname): volume-unmount returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO ($progname): Successfully unmounted volume <$clone_name>\n";

    #--------------------------------------- 
    # 2nd make sure the volume is offline
    #--------------------------------------- 
    $out = $naserver->invoke("volume-offline",  "name",  $clone_name);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to take FlexClone volume $clone_name offline\n";
        print "ERROR ($progname): volume-offline returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO ($progname): Successfully took FlexClone volume <$clone_name> offline\n";

    #--------------------------------------- 
    # 3rd remove/delete volume
    #--------------------------------------- 
    $out = $naserver->invoke("volume-destroy",  "name",         $clone_name);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to remove/destroy FlexClone volume $clone_name \n";
        print "ERROR ($progname): volume-destroy returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO ($progname): Successfully removed volume <$clone_name>\n";

} # end of sub remove_volume()



