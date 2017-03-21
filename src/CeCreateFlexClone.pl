#!/usr/bin/perl 
################################################################################
# CodeEasy Customer Toolkit Script
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

our $progname="CeCreateFlexClone.pl";    # name of this program

# command line argument values
our $volume;                       # cmdline arg: volume to create (default name: $CeInit::CE_DEFAULT_VOLUME_NAME)
our $snapshot_name;                # cmdline arg: snapshot to use for clone image
our $clone_name;                   # cmdline arg: flexclone name - as mounted (as seen by the UNIX user)
our $flexclone_vol_name;           # cmdline arg: name of the flexclone volume name (as seen on the filer)
                                   #              (typically the same as flexclone name)
our $junction_path;                # cmdline arg: junction_path - if passed via the cmd line. 
our $username;
our $groupname;
our $list_snapshots;               # cmdline arg: list available snapshots
our $list_flexclones;              # cmdline arg: list available flexclone volumes
our $volume_delete;                # cmdline arg: remove flexclone volume
our $test_only;                    # cmdline arg: test filer init then exit
our $verbose;                      # cmdline arg: verbosity level

our @CLONE_OPTIONS;
our $uid;
our $gid;

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
# create flexclone
#--------------------------------------- 
if (! defined $volume_delete) {
    #--------------------------------------- 
    # create flexclone
    #    flexclone volume is created by default - unless -remove is specified
    #--------------------------------------- 
    &clone_create($volume, $snapshot_name, $clone_name ) 

    #--------------------------------------- 
    # change permission of clone from the original snapshot owner
    # to the current user. this can be handled here or in a wrapper script
    #--------------------------------------- 
    # NOTE: not yet implemented here 
    # &chown_clone();
}

#--------------------------------------- 
# remove volume (NOTE: removing a FlexClone is identical to removing a volume)
#--------------------------------------- 
if ($volume_delete) {
    &remove_volume(); 
}


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

              'vol|volume=s'       => \$volume,                  # volume to create
	      's|snapshot=s'       => \$snapshot_name,           # snapshot name
	      'c|clone=s'          => \$clone_name,              # clone name
	      'fc_volname=s'       => \$flexclone_vol_name,      # optional: flexclone volume name
              'jp|junction_path=s' => \$junction_path,           # optional: junction_path minus clone_name
                                                                 #           jp = jp + clone_name
              'user=s'             => \$username,          # optional: chown to new username          
              'group=s'            => \$groupname,         # optional: chown to new groupname          

	      'r|remove'           => \$volume_delete,           # remove clone volume

	      'ls'                 => \$list_snapshots,          # list available snapshots
	      'lc'                 => \$list_flexclones,         # list current flexclone volumes

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
	      "      Exiting...\n\n";
	exit 1;
    }

    # no further GetOps input checking if we are just listing the available snapshots
    return if (defined $list_snapshots);

    # no further GetOps input checking if we are just listing the available flexclones
    return if (defined $list_flexclones);

    # check that a snapshot was specified
    if (! defined $snapshot_name) {
	print "ERROR ($progname): No SnapShot name provided.\n" .
	      "      Use the -snapshot <snap_name> option.\n" .
	      "Exiting...\n\n";
	exit 1;

    }

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

      -vol|-volume  <volume name>    : volume name 
                                       (OPTIONAL) default value is set in the CeInit.pm file
				       by var \$CeInit::CE_DEFAULT_VOLUME_NAME

      -s |-snapshot <snapshot name>  : name of the Snapshot  to clone
                                       (REQUIRED)

      -cl|-clone <clone name>        : name of the new FlexClone volume to create
                                       this is the name which will be mounted
				       via junction_path by UNIX.
                                       (REQUIRED)

      -fc_volname <flexclone volume name>  
                                     : name of the FlexClone volume as stored on the filer
                                       (OPTIONAL) by default the FlexClone name will be used as 
				       the flexclone volume name.  But if there is a need for the flexclone
				       volume name to be different than the volume name seen by UNIX, then use this
				       option.
       -jp|-junction_path <junction_path>
                                     : OPTIONAL switch to allow passing a juction_path to the script.  This
                                       is useful when setting up the flow.  NOTE: that the clone_name is appended
                                       to the this option to great the full junction_path name.

        -user  <username>            : OPTIONAL chown new clone to username
        -group <groupname>           : OPTIONAL chown new clone to groupname

      -r|-remove                     : remove volume

      -ls                            : list snapshots (exludes hourly, daily and weekly snapshots)

      -lc                            : list current flexclones

      -v|-verbose                    : enable verbose output

      -t|-test                       : test connection to filer then exit
                                       recommended for initial setup testing and debug

      Examples:
	create a FlexClone with the name <ce_test_vol>
	starting with snapshot
        %> $progname -volume   ce_test_vol \
	             -snapshot ce_test_snapshot \
	             -clone    my_flexclone_ce_test 

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
    my $cmd;

    #--------------------------------------- 
    # Check if user and group info was passed on the command line
    # if not, then no uid/gid will be added to the create flexclone command
    #--------------------------------------- 
    # get uid and gid from actual UNIX user name and group names
    if (( defined $username) and (defined $groupname)) {
       # both user/group passed on the command line
       $uid   = getpwnam($username);
       $gid   = getgrnam($groupname);
    
       push @CLONE_OPTIONS, "uid", $uid;
       push @CLONE_OPTIONS, "gid", $gid;

     } elsif (((   defined $username) and (! defined $groupname)) or
              (( ! defined $username) and (  defined $groupname)) ) {
       # error both user and group must be specified
       print "ERROR: username and group name must both be specified.\n" .
             "       Exiting...\n";
       exit 1; 

     } else {
       # Username and groupname were not specified on the command line
       $username = getpwuid( $< ); chomp $username;
     } 

    #--------------------------------------- 
    # get current users name and
    # make sure user has a directory at mount point
    #--------------------------------------- 
    # the new FlexClone will be mounted at the UNIX_mount_path 
    my $UNIX_mount_path     = "$CeInit::CE_UNIX_USER_FLEXCLONE_PATH/$username";

    # the FlexClone's junction_path will have a corresponding path to the
    # UNIX_clone_path - if done correctly, the FlexClone will be automounted
    # automatically by the filer.
    my $UNIX_clone_path     = "$UNIX_mount_path/$clone_name";

    # test if UNIX mount point exits - if not create it
    if (! -d $UNIX_mount_path) {
	print "INFO: ($progname): UNIX Mount point does not exist!\n";
        $cmd = "/bin/mkdir -p $UNIX_mount_path";
        if (system($cmd) == 0) {
            print "INFO: ($progname): Successfully created $UNIX_mount_path\n";

        } else {
            print "ERROR: ($progname): Problem occured while trying to create $UNIX_mount_path\n" .
                  "       $cmd\n" .
                  "       Check to ensure write permissions on the directory tree.\n";
        }
    } else {
	print "INFO: ($progname: UNIX Mount point exists.\n" .
              "      $UNIX_mount_path\n";

    }


    #--------------------------------------- 
    # determine junction path  (mount point)
    #--------------------------------------- 
    # put the new volume at the end of the pre-mounted root directory
    # this will make it so the new volume will automatically be mounted

    # NOTE: clones will be created by users, so they will be mounted to the
    # CE_JUNCT_PATH_USERS vs the CE_JUNCT_PATH_MASTER
    if (defined $junction_path) {
      $junction_path = $junction_path . "/" . $clone_name;
      print "DEBUG: Junction_path set via the command line.\n" .
            "       $junction_path\n";
    } else {
      $junction_path = "$CeInit::CE_JUNCT_PATH_USERS/$username/$clone_name";
    }

    # place the FlexClone owner in the comment field so it can be tracked.
    # This can be any string of information.  One idea might be to 
    # write single line XML like 
    #      <clone_info><owner>jmichae1</owner><date_created>2016-07-21</date_created><project>project_A</project></clone_info>
    #
    #      Displayed in multiple lines for readability
    #      <clone_info>
    #          <owner>jmichae1</owner>
    #          <date_created>2016-07-21</date_created>
    #          <project>project_A</project>
    #      </clone_info>
    my $comment_field = $username;


    print "INFO  ($progname): Creating FlexClone volume\n" .
          "      flexclone volume name = $flexclone_vol_name\n" .
          "      parent-volume         = $volume\n" .
          "      parent-snapshot       = $parent_snapshot\n" .
          "      junction path         = $junction_path \n" .
          "      UNIX clone path       = $UNIX_clone_path\n" .
          "      Comment               = $comment_field\n" .
          "      space-reserve         = none\n\n";

    if (defined $gid) {
    print "INFO: Changing FlexClone user/group ownership.\n" .
          "      username              = $username\n" .
          "      groupname             = $groupname\n\n"; 
    } else {
    print "INFO: No change in FlexClone user/group ownership.\n\n";
    }
                  
    #--------------------------------------- 
    # check that the volume already exists - if not error
    #--------------------------------------- 
    # get list of volumes from the vserver
    my %vol_list = ();
    %vol_list = &CeCommon::getVolumeList($naserver);

    # check that the volume to clone is in the list of volumes available
    if (defined $vol_list{$volume} ) {
	# the master volume must exist to clone 
	print "DEBUG: Volume '$volume' to clone exists\n" if ($verbose);
    } else {
        # if not, then generate an error
	print "\nERROR: Volume to clone does not exist.\n" .
	      "       Check that volume '$volume' exists and has a valid snapshot.\n" .
	      "       Exiting...\n\n";
	exit 1;
    }

    #--------------------------------------- 
    # check flexclone already exists - if so error
    #--------------------------------------- 
    # get list of flexclones from the vserver
    my %clone_list = &CeCommon::getFlexCloneList($naserver);

    # check that the clone does not already exist
    if (defined $clone_list{$flexclone_vol_name} ) {
	# the flexclone already exists - error
	print "ERROR: The FlexClone '$flexclone_vol_name' already exists.\n" .
	      "       FlexClone names must be unique.\n" .
	      "       Exiting...\n\n";
	exit 1;
    } else {
	print "DEBUG: FlexClone does not yet exists\n" if ($verbose);
    }

    #--------------------------------------- 
    # check if snapshot exists - if not error
    #--------------------------------------- 
    my %snapshot_list = &CeCommon::getSnapshotList($naserver, $volume);

    # check if the snapshot exists.
    if (! defined $snapshot_list{$snapshot_name} ) {
	print "\nERROR ($progname): Snapshot '$snapshot_name' does not exist on volume '$volume'.\n" .
	        "      Check that you have specified the correct snapshot name.\n" .
	        "      List the available snapshots to clone using the '%> $progname -ls' command.\n" .
	        "Exiting...\n\n";
	exit 1;
    } 




    #--------------------------------------- 
    # create flexclone
    #--------------------------------------- 
    $out = $naserver->invoke("volume-clone-create", "parent-volume",   $volume, 
                                                    "parent-snapshot", $parent_snapshot,
                                                    "volume",          $flexclone_vol_name,
						    "junction-path",   $junction_path, 
						    "space-reserve",   'none',
						    "comment",         $comment_field,
                                                    @CLONE_OPTIONS
						    );

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
	# user friendly error message
	print "ERROR ($progname): Unable to create FlexClone '$flexclone_vol_name'\n"; 
	# verbose debug
        print "ERROR ($progname): volume-clone-create returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n\n";

        exit 1;
    }
    print "INFO ($progname): FlexClone <$clone_name> successfully created and mounted\n" .
          "                  at UNIX path <$UNIX_clone_path>\n";


} # end of sub clone_create()



###################################################################################
# chown_clone:    change the ownership of the flexclone
###################################################################################
sub chown_clone {

    # determine user running this script
    my $username = getpwuid( $< ); chomp $username;

    # the new FlexClone will be mounted at the UNIX_mount_path 
    my $UNIX_mount_path     = "$CeInit::CE_UNIX_USER_FLEXCLONE_PATH/$username";

    # the FlexClone's junction_path will have a corresponding path to the
    # UNIX_clone_path - if done correctly, the FlexClone will be automounted
    # automatically by the filer.
    my $UNIX_clone_path     = "$UNIX_mount_path/$clone_name";

    # command for running the chown command
    my $cmd     = "$FindBin::Bin/CeChownList.pl -d $UNIX_clone_path -u $username";

    # sur: the sur command will change user to the <build user> and then run
    # the cammand which follows as that person.
    #                            sur <build user>            <command to run>
    my $sur_cmd = "$FindBin::Bin/sur $CeInit::CE_DEVOPS_USER $cmd";

    print "INFO: Running CeChownList.pl\n" .
          "      $sur_cmd\n";

    # run the command and check the status
    if (system($sur_cmd) == 0) {
	print "INFO:  Successfully ran CeChownList.pl\n";
    } else {
	print "ERROR: Problem occured while running CeChownList.pl\n" .
	      "       This error might be due to sudo permissions required to run chown cmd.\n" .
	      "       Refer to the QUICKSTART guide for usage instructions\n" .
	      "       Exiting...\n";
        exit 1;
    }

} # end of sub &chown_clone();



###################################################################################
# remove_volume:    Remove volume
#   $volume:          The volume to be removed
###################################################################################   
sub remove_volume {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    print "INFO  ($progname): Deleting FlexClone volume\n" .
          "      flexclone volume name = $flexclone_vol_name\n\n";

    #--------------------------------------- 
    # check if flexclone exists - if not error
    #--------------------------------------- 
    # get list of flexclones from the vserver
    my %clone_list = &CeCommon::getFlexCloneList($naserver);

    # check that the clone does not already exist
    if (! defined $clone_list{$flexclone_vol_name} ) {
	# the flexclone does not exists - error
	print "ERROR: The FlexClone '$flexclone_vol_name' does not exists.\n" .
	      "       Check the list FlexClone report to see if it exists.\n" .
	      "       %> $progname -lc \n" .
	      "       Exiting...\n\n";
	exit 1;
    } else {
	print "DEBUG: FlexClone '$flexclone_vol_name' exists and will be removed.\n" if ($verbose);
    }


    #--------------------------------------- 
    # Step 1: Unmount the FlexClone volume
    #--------------------------------------- 
    $out = $naserver->invoke("volume-unmount",  "volume-name", $flexclone_vol_name);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to unmount FlexClone volume $flexclone_vol_name\n";
        print "ERROR ($progname): volume-unmount returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n\n";
        exit 1;
    }
    print "INFO  ($progname): Flexclone volume <$flexclone_vol_name> successfully unmounted.\n";

    #--------------------------------------- 
    # Step 2: make sure the flexClone volume is offline
    #--------------------------------------- 
    $out = $naserver->invoke("volume-offline",  "name",  $flexclone_vol_name);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to take FlexClone volume $flexclone_vol_name offline\n";
        print "ERROR ($progname): volume-offline returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n\n";
        exit 1;
    }
    print "INFO  ($progname): FlexClone volume <$flexclone_vol_name> successfully taken offline.\n";

    #--------------------------------------- 
    # Step 3: remove/delete FlexClone volume
    #--------------------------------------- 
    $out = $naserver->invoke("volume-destroy",  "name", $flexclone_vol_name);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to remove/destroy FlexClone volume $flexclone_vol_name\n";
        print "ERROR ($progname): volume-destroy returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n\n";
        exit 1;
    }
    print "INFO  ($progname): FlexClone volume <$flexclone_vol_name> successfully removed.\n";

} # end of sub remove_volume()


###################################################################################
# list current list of flexclones
###################################################################################   
sub list_flexclones {

    # pass arguments into sub-routine
    my ($naserver) = @_;

    my %junction_path_map;
    my %comment_field_map;
    my %vol_usage_map;
    my %vol_dedup_saved;
    my %vol_dedup_percent;

    #---------------------------------------- 
    # get list of all volumes 
    #---------------------------------------- 
    my @vlist = &CeCommon::vGetcDOTList( $naserver, "volume-get-iter" );

    #---------------------------------------- 
    # loop thru list of volumes and get specific volume attribute data
    #---------------------------------------- 
    foreach my $tattr ( @vlist ) {
	my $vol_id_attrs = $tattr->child_get( "volume-id-attributes" );

        # get the volume name
        my $volume_name;
        $volume_name = $vol_id_attrs->child_get_string( "name" );

        # get the junction path info for the volume - store it in a lookup for later
        my $jpath = $vol_id_attrs->child_get_string( "junction-path" );
        $junction_path_map{$volume_name} = $jpath;
        print "DEBUG: Volume: $volume_name \tJunction Path: $jpath \n" if ($verbose);

        # get the comment field from the volume - store it in a lookup for later
        my $comment_field = $vol_id_attrs->child_get_string( "comment" );
        if (defined $comment_field) {
                $comment_field_map{$volume_name} = $comment_field;
        } else {
                $comment_field_map{$volume_name} = "USER_UNKNOWN";
        }
        print "DEBUG: Volume: $volume_name \tComment Field: $comment_field_map{$volume_name}\n" if ($verbose);

        # get the volume size - store it in a lookup for later
        my $vol_space_attrs = $tattr->child_get( "volume-space-attributes" );
        if ( $vol_space_attrs ) {
            my $vol_usage = $vol_space_attrs->child_get_string( "size-used" );
            if (defined $vol_usage) {
                $vol_usage_map{$volume_name} = $vol_usage;
            }
        }

        # get volume storage efficiency data - store it in a lookup for later
        my $vol_sis_attrs = $tattr->child_get( "volume-sis-attributes" );
        if ( $vol_sis_attrs ) {
            my $saved_percent = $vol_sis_attrs->child_get_string( "percentage-total-space-saved" );
            my $saved_bytes   = $vol_sis_attrs->child_get_string( "total-space-saved" );
            if (defined $saved_bytes) {
                $vol_dedup_percent{$volume_name} = $saved_percent;
                $vol_dedup_saved{$volume_name}   = $saved_bytes;
            } else {
                $vol_dedup_percent{$volume_name} = 0;
                $vol_dedup_saved{$volume_name}   = 0;
            }
        } else {
            $vol_dedup_percent{$volume_name} = 0;
            $vol_dedup_saved{$volume_name}   = 0;
        }
    }


    #---------------------------------------- 
    # create report header
    #---------------------------------------- 
    print "\nList FlexClones\n";
	    #123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890 
    printf  "%-25s %-30s %-29s ", "Parent Volume", "Parent-Snapshot", "FlexClone";
    printf  "%15s",               "Parent Vol";
    printf  "%15s",               "FlexClone Vol";
    printf  "%15s",               "Split Est";
    printf  "%24s",               "FlexClone Actual";
    printf  "%15s",               "Clone Owner";
    printf  "  %s \n",            "Junction-path";
    printf  "%-25s %-30s %-29s ", "", "", "";
    printf  "%15s",               "(Phys Used)";
    printf  "%15s",               "(Phys Used)";
    printf  "%15s",               "(Logical Used)";
    printf  "%24s",               "(Phys Estimate)";
    printf  "%15s",               "";
    printf  "  %s \n",            "";

    print   "---------------------------------------------------------------------------------------" .
            "---------------------------------------------------------------------------------------------------\n"; 

    #---------------------------------------- 
    # get FlexCone info iteratively - it will return a list
    #---------------------------------------- 
    @vlist = &CeCommon::vGetcDOTList( $naserver, "volume-clone-get-iter" );

    # for each clone entry
    foreach my $vol_data ( @vlist ) {
	    my $volume_name    = $vol_data->child_get_string( "parent-volume"  );
            next if (($volume ne $CeInit::CE_DEFAULT_VOLUME_NAME) && ($volume_name ne $volume));
	    my $clone_name     = $vol_data->child_get_string( "volume"         );
	    my $snapshot       = $vol_data->child_get_string( "parent-snapshot");
	    my $flexclone_used = $vol_data->child_get_string( "used"           );
	    my $split_est      = $vol_data->child_get_string( "split-estimate" );
	    my $comment_field  = $comment_field_map{$clone_name};
	       $comment_field  = "USER_UNKNOWN" if ($comment_field eq "");

	    # parent volume: space used - represent data used in GB
	    my $parent_used = $vol_usage_map{$volume_name}/(1024*1024*1024);

	    # split estimate value is returned in blocks rather than bytes
	    $split_est      = $split_est*4096; # blocks => Bytes

	    # storage used by the FlexClone
            my $flexclone_actual = (($flexclone_used + $vol_dedup_saved{$clone_name}) - $split_est) * ((100 - $vol_dedup_percent{$clone_name}) *.01);

	    # calculate % savings
	    my $savings      = ($flexclone_actual/$flexclone_used)*100;

	    # FlexClone volume: space used - represent data used in BB
	    $flexclone_used    = $flexclone_used/(1024*1024*1024);

	    # FlexClone calculated actual: space used - represent data used in GB
	    $flexclone_actual    = $flexclone_actual/(1024*1024*1024);

	    # split estimate value is returned in blocks rather than bytes
	    $split_est      = $split_est/(1024*1024*1024); # date in GB

	    # determine juction-path info
	    my $jpath       = $vol_data->child_get_string( "junction-path"  );
	    # test if the value returned correctly
	    if ( defined $jpath ) {
		# perfect the look up worked correctly
	    } elsif ( defined $junction_path_map{$clone_name} ) {
		# ok lookup didn't work, but it was found by method #2
		$jpath = $junction_path_map{$clone_name};
	    } else {
		# no junction path found
		$jpath = "Not Mounted"; 
	    }

	    # print results
	    printf "%-25s %-30s %-30s ", $volume_name, $snapshot, $clone_name;
	    printf "%11.2f GB ",         $parent_used;
	    printf "%11.2f GB ",         $flexclone_used;
	    printf "%11.2f GB ",         $split_est;
	    printf "%11.2f GB",          $flexclone_actual;
	    printf " (%5.2f",            $savings; print "%)";
	    printf "%15s",               $comment_field;
	    printf "  %s\n",             $jpath;
    }


    # exit program successfully
    print "\n$main::progname exited successfully.\n\n";
    exit 0;

} # end of sub &list_flexclones()


