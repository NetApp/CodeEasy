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
    my %vol_dedup_shared;

    #---------------------------------------- 
    # get list of all volumes 
    #---------------------------------------- 
    my @vlist = &CeCommon::vGetcDOTList( $naserver, "volume-get-iter" );

    #---------------------------------------- 
    # loop thru list of volumes and get specific volume attribute data
    #---------------------------------------- 
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
	    }
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
    printf  "%24s",               "FlexClone Act";
    printf  "%15s",               "Cloan Owner";
    printf  "  %s \n",            "Junction-path";
    print   "---------------------------------------------------------------------------------------" .
            "---------------------------------------------------------------------------------------------------\n"; 

    #---------------------------------------- 
    # get FlexCone info iteratively - it will return a list
    #---------------------------------------- 
    @vlist = &CeCommon::vGetcDOTList( $naserver, "volume-clone-get-iter" );

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

	    # split estimate actual: space used - represent data used in MB
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


