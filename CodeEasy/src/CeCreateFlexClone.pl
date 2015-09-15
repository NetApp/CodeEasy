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
# List Volumes - then exit
#--------------------------------------- 
&list_flexclones() if ($list_flexclones);

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
    # to the current user.
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
  GetOptions ("h|help"             => sub { &show_help() },   

              'vol|volume=s'       => \$volume,                  # volume to create
	      's|snapshot=s'       => \$snapshot_name,           # snapshot name
	      'c|clone=s'          => \$clone_name,              # clone name
	      'fc_volname=s'       => \$flexclone_vol_name,         # optional: junction_path name

	      'r|remove'           => \$volume_delete,           # remove clone volume

	      'ls'                 => sub { &CeCommon::list_snapshots() }, # list available snapshots
	      'lc'                 => sub { &list_flexclones()}, # list current flexclone volumes

	      't|test'             => \$test_only,               # test filer connection then exit

              'v|verbose'          => \$verbose,                 # increase output verbosity
	      '<>'                 => sub { &CMDParseError() },
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
	      "      Exiting...\n\n";
	exit 1;
    }

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


    #--------------------------------------- 
    # get current users name and
    # make sure user has a directory at mount point
    #--------------------------------------- 
    my $username = getpwuid( $< ); chomp $username;

    # the new FlexClone will be mounted at the UNIX_mount_path 
    my $UNIX_mount_path     = "$CeInit::CE_UNIX_USER_FLEXCLONE_PATH/$username";

    # the FlexClone's junction_path will have a corresponding path to the
    # UNIX_clone_path - if done correctly, the FlexClone will be automounted
    # automatically by the filer.
    my $UNIX_clone_path     = "$UNIX_mount_path/$clone_name";

    # create user path directory - this directory must exist for the lower
    # level mount to attach correctly. 
    # NOTE: NetApp filer junction_paths should take care of completing any
    # missing paths if setup correctly.  But in some cases, it might be
    # necessary to first create the full path.
#   my $cmd = "/bin/mkdir -p $UNIX_mount_path";
#
#   if ( system ($cmd) == 0) {
#       print "DEBUG ($progname): Created UNIX mount point for new FlexClone at $UNIX_mount_path\n" if ($verbose);
#   } else {
#       print "ERROR ($progname): Could not create UNIX mount point for new FlexClone at $UNIX_mount_path\n" .
#             "       Check that the UNIX path and permissions exist.\n" .
#             "       $cmd\n" .
#             "Exiting...\n";
#       exit 1;
#   }


    #--------------------------------------- 
    # determine junction path  (mount point)
    #--------------------------------------- 
    # put the new volume at the end of the pre-mounted root directory
    # this will make it so the new volume will automatically be mounted

    # NOTE: clones will be created by users, so they will be mounted to the
    # CE_JUNCT_PATH_USERS vs the CE_JUNCT_PATH_MASTER
    my $junction_path = "$CeInit::CE_JUNCT_PATH_USERS/$username/$clone_name";

    # place the FlexClone owner in the comment field so it can be tracked.
    # This can be any information which might make sense.
    # NOTE: 8.2.x does not support the comment field in the
    # volume-clone-create command - but the comment field exists - its just
    # not setable. 
    my $comment_field = $username;

    print "INFO  ($progname): Creating FlexClone volume\n" .
          "      flexclone volume name = $flexclone_vol_name\n" .
          "      parent-volume         = $volume\n" .
          "      parent-snapshot       = $parent_snapshot\n" .
          "      junction path         = $junction_path \n" .
          "      UNIX mount path       = $UNIX_mount_path\n" .
          "      UNIX clone path       = $UNIX_clone_path\n" .
	  "      Comment (clown owner) = <$comment_field>\n\n";
                  

    #--------------------------------------- 
    # check that the volume already exists - if not error
    #--------------------------------------- 
    # get list of volumes from the vserver
    my %volume_list = &CeCommon::getVolumeList($naserver);

    # check that the volume to clone is in the list of volumes available
    if (defined $volume_list{$volume} ) {
	# the master volume must exist to clone 
	print "DEBUG: Volume '$volume' to clone exists\n" if ($verbose);
    } else {
        # if not, then generate an error
	print "ERROR: Volume to clone does not exist.\n" .
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
    # check that the snapshot exists - if not error
    #--------------------------------------- 
    # determine the full UNIX path to the parent snapshot
    my $snapshot_path = "$CeInit::CE_UNIX_MASTER_VOLUME_PATH/.snapshot/$parent_snapshot";
    if (-e $snapshot_path) {
	print "DEBUG: Snapshot '$parent_snapshot' exists.\n" if ($verbose);
    } else {
	print "ERROR: Snapshot '$parent_snapshot' does not exist.\n" .
	      "       List the available snapshots to clone using the '%> $progname -ls' command.\n" .
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
						    );
						    # add this line back to the volume-clone-create
						    # command if using cDOT8.3 or later
						    #"comment",         $comment_field

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
	# user friendly error message
	print "ERROR ($progname): Unable to create FlexClone '$flexclone_vol_name'\n"; 
	# verbose debug
        print "ERROR ($progname): Unable to volume-clone-create snapshot $parent_snapshot \n";
        print "ERROR ($progname): volume-clone-create returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n" if ($verbose);
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

    print "DEBUG: Command to run CeChownList.pl\n" .
          "       $sur_cmd\n";

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
    # check flexclone already exists - if not error
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
    # first make sure the volume is unmounted
    #--------------------------------------- 
    $out = $naserver->invoke("volume-unmount",  "volume-name", $flexclone_vol_name);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to unmount FlexClone volume $clone_name\n";
        print "ERROR ($progname): volume-unmount returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n\n";
        exit 1;
    }
    print "INFO  ($progname): Flexclone volume <$flexclone_vol_name> successfully unmounted.\n";

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
        print "ERROR ($progname): Exiting with error.\n\n";
        exit 1;
    }
    print "INFO  ($progname): FlexClone volume <$clone_name> successfully taken offline.\n";

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
        print "ERROR ($progname): Exiting with error.\n\n";
        exit 1;
    }
    print "INFO  ($progname): FlexClone volume <$clone_name> successfully removed.\n";

} # end of sub remove_volume()


###################################################################################
# list current list of flexclones
###################################################################################   
sub list_flexclones {

    #--------------------------------------- 
    # initialize access to NetApp filer
    #--------------------------------------- 
    my $naserver = &CeCommon::init_filer();

    my %junction_path_map;
    my %comment_field_map;
    my %vol_usage_map;
    my %vol_dedup_saved;
    my %vol_dedup_shared;

    my @vlist = &CeCommon::vGetcDOTList( $naserver, "volume-get-iter" );

    foreach my $tattr ( @vlist ) {
	my $vol_id_attrs = $tattr->child_get( "volume-id-attributes" );
    #print "DEBUG: volume-id-attributes\n";
    #printf($tattr->sprintf());
	my $volume_name;
	if ( $vol_id_attrs ) {
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
	}
	my $vol_space_attrs = $tattr->child_get( "volume-space-attributes" );
	if ( $vol_space_attrs ) {
	    my $vol_usage = $vol_space_attrs->child_get_string( "size-used" );
	    if (defined $vol_usage) {
		$vol_usage_map{$volume_name} = $vol_usage;
		#print "DEBUG: vol usage: $volume_name $vol_usage_map{$volume_name}\n";
	    }
	}
	my $vol_sis_attrs = $tattr->child_get( "volume-sis-attributes" );
	#printf($vol_sis_attrs->sprintf());
	if ( $vol_sis_attrs ) {
	    my $dedup_saved  = $vol_sis_attrs->child_get_string( "percentage-total-space-saved" );
	    my $dedup_shared = $vol_sis_attrs->child_get_string( "deduplication-space-shared" );
	    if (defined $dedup_saved) {
		$vol_dedup_saved{$volume_name}  = $dedup_saved;
		$vol_dedup_shared{$volume_name} = $dedup_shared;
		print "DEBUG: dedup saved: $volume_name saved=$vol_dedup_saved{$volume_name}  shared=$vol_dedup_shared{$volume_name}\n" if ($verbose);
	    }
	}
    }

    # get volume clone info iteratively - it will return a list
    @vlist = &CeCommon::vGetcDOTList( $naserver, "volume-clone-get-iter" );

    print "\nList FlexClones\n";
	    #123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890 
    printf  "%-25s %-30s %-29s ", "Parent Volume", "Parent-Snapshot", "FlexClone";
    printf  "%15s",               "Parent Vol";
    printf  "%15s",               "FlexClone Vol";
    printf  "%15s",               "Split Est";
    printf  "%24s",               "FlexClone Act";
    printf  "%15s",               "Cloan Owner";
    printf  "  %s \n",            "Junction-path";
    print   "---------------------------------------------------------------------------------------" .
            "---------------------------------------------------------------------------------------------------\n"; 

    # for each clone entry
    foreach my $vol_data ( @vlist ) {
    #printf($vol_data->sprintf());
	    my $volume_name    = $vol_data->child_get_string( "parent-volume"  );
	    my $clone_name     = $vol_data->child_get_string( "volume"         );
	    my $snapshot       = $vol_data->child_get_string( "parent-snapshot");
	    my $flexclone_used = $vol_data->child_get_string( "used"           );
	    my $split_est      = $vol_data->child_get_string( "split-estimate" );
	    my $comment_field  = $comment_field_map{$clone_name};
	       $comment_field  = "USER_UNKNOWN" if ($comment_field eq "");

	    # parent volume: space used - represent data used in MB
	    my $parent_used = $vol_usage_map{$volume_name}/1024/1024;

	    # split estimate value is returned in blocks rather than bytes
	    $split_est      = $split_est*4096; # blocks => Bytes

	    # storage used by the FlexClone
	    my $flexclone_actual = $flexclone_used - $split_est;

	    # calculate % savings
	    my $savings      = ($flexclone_actual/$flexclone_used)*100;
	    my $compression  = (1-$flexclone_actual/$flexclone_used)*100;

	    # FlexClone volume: space used - represent data used in MB
	    $flexclone_used    = $flexclone_used/1024/1024;

	    # FlexClone calculated actual: space used - represent data used in MB
	    $flexclone_actual    = $flexclone_actual/1024/1024;

	    # split estimate value is returned in blocks rather than bytes
	    $split_est      = $split_est/1024/1024; # date in MiB

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
	    printf "%11.2f MB ",         $parent_used;
	    printf "%11.2f MB ",         $flexclone_used;
	    printf "%11.2f MB ",         $split_est;
	    printf "%11.2f MB",          $flexclone_actual;
	    printf " (%5.2f",            $savings; print "%)";
	    #printf " (%5.2f",           $compression; print "%)";
	    printf "%15s",               $comment_field;
	    printf "  %s\n",             $jpath;
    }


    # exit program successfully
    print "\n$main::progname exited successfully.\n\n";
    exit 0;

} # end of sub &list_flexclones()


