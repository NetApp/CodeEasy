#!/usr/bin/perl -w 
################################################################################
# CodeEasy Customer Evaluation Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: This is a common Perl package which is included in the calling Perl
#          scripts vis the 'use <package>' constct
#          variables and sub-routines are called from other scripts as follows;
#              $my_variable   $CeCommon::VARIABLE
#              $my_subroutine $CeCommon::my_subroutine
#          
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

# declair this file (.pm) as a Perl package
package CeCommon;

use Env;           # package to allow reading UNIX environment vars
use Cwd;
use FindBin();     # The FindBin helps indentify the path this executable and thus its path
use strict;        # require strict programming rules
use warnings;


#---------------------------------------- 
# load NetApp manageability SDK APIs
#---------------------------------------- 
# SDK setenv not set, assume the SDK is in parallel to the CodeEasy
# tarball installation    ***** CUSTOMIZE ME *****
use lib "$FindBin::Bin/../../netapp-manageability-sdk-5.3.1/lib/perl/NetApp";
# use lib "<your_full_path>/netapp-manageability-sdk-5.2.2/lib/perl/NetApp";

# load the NetApp Manageability SDK components
use NaServer;      
use NaElement;  

#---------------------------------------- 
# load CodeEasy packages
#---------------------------------------- 
use lib "$FindBin::Bin/.";
use CeInit;                   # found in the file CeInit.pm



###################################################################################
# Initialize filer - return data structure
###################################################################################
sub init_filer {


    # temp vars for getting filer info and status
    my $out;
    my $errno;

    #--------------------------------------- 
    # initialize access to NetApp filer
    #--------------------------------------- 
    print "\nINFO  ($main::progname): Connecting to storage controler/vserver\n";

    # Creates a new object of NaServer class and sets the default value for the following object members:
    #   syntax: new($server, $majorversion, $minorversion)
    print "\tCluster controler  = $CeInit::CE_CLUSTER\n";
    my $naserver = NaServer->new($CeInit::CE_CLUSTER, 1, 21);

    # sets the name of the Storage Virtual Machine (SVM, formerly known as Vserver) 
    # to which a Cluster API need to be tunneled from a Cluster Management Interface.
    $naserver->set_vserver($CeInit::CE_VSERVER);
    # read back set value
    my $vserver = $naserver->get_vserver();
    print "\tset_vserver        = $vserver\n";

    # set API transport type - HTTP is the default
    $naserver->set_transport_type($CeInit::CE_TRANSPORT_TYPE);
    # read back set value
    my $transport_type = $naserver->get_transport_type();
    print "\tset_transport_type = $CeInit::CE_TRANSPORT_TYPE\n";

    # pass username/password for vserver ontapi application access
    #     $naserver->set_admin_user("vsadmin", "devops123");
    $naserver->set_admin_user(@CeInit::CE_ADMIN_USER);

    # set communication style - typically just 'LOGIN'
    $naserver->set_style($CeInit::CE_STYLE);

    # set communication port
    $naserver->set_port($CeInit::CE_PORT);
    # read back set value
    my $port_value = $naserver->get_port();
    print "\tset_port           = $port_value\n\n";


    # check connection to the filer by requesting a simple ontapi version status
    $out =  $naserver->invoke("system-get-version");

    # check error status and exit if basic communication with the filer can't be estabilished.
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($main::progname): FAIL: Unable to connect to $CeInit::CE_CLUSTER \n";
        print "ERROR ($main::progname): system-get-version returned with $errno and reason: " . 
	                          '"' .  $out->results_reason() . "\n";
        print "ERROR ($main::progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO  ($main::progname): Storage Controller <$CeInit::CE_CLUSTER> is running ONTAP API version:\n" . 
          "      " . $out->child_get_string("version") . " \n\n";
      

    # check that filer is running cDOT and not 7-mode
    if ( $out->child_get_string("is-clustered") eq "true") {
	print "\nINFO  ($main::progname): Storage Controller <$CeInit::CE_CLUSTER> is running cDOT.\n\n";
    } else {
	print   "ERROR ($main::progname): Storage Controller <$CeInit::CE_CLUSTER> is running in 7-mode\n" .
	        "       These scripts support cDOT (Clustered Data OnTap) only\n" .
	        "Exiting...\n";
	exit 1;
    }

    # return to calling program
    return $naserver;

} # end of init_filer()


###################################################################################
# list current list of snapshots
###################################################################################   
sub list_snapshots {

    my $snap_cnt      = 0;
    my $snap_skip_cnt = 0;


    # the snapshots can be found in the master directory
    my $snap_dir = "$CeInit::CE_UNIX_MASTER_VOLUME_PATH/.snapshot/";

    # check that the snapshot directory exists
    if (! -d $snap_dir) {
	print "\nERROR ($main::progname) The master volume Snapshot directory not found!\n" .
	        "      $snap_dir\n\n" .
		"      Check the \$CE_UNIX_MASTER_VOLUME_PATH/.snapshot/ setting in CeInit.pm\n" .
	        "Exiting...\n\n";
	exit 1;
    }


    my $cmd      = "ls $snap_dir";

    # execute cmd and capture the stdout/stderr to $cmd_out
    my $cmd_out = `$cmd`;

    # check status of the system call
    if ($? == 0) {

    }  else {
	print "ERROR: Could not find snapshot directories.\n" .
	      "       $cmd\n" .
	      "Exiting...\n";
	exit 1;
    }
    chomp $cmd_out;
    print "\nINFO  ($main::progname): Snapshot list for volume <$CeInit::CE_DEFAULT_VOLUME_NAME>\n";

    # loop thru list of snapshot directories 
    foreach my $snap (sort split /^/, $cmd_out) {

	# trip special characters off string
        chomp $snap;

	# skip regular snapshot - so only specifically named snapshots are shown
	if ( ($snap =~ /^hourly/) || ($snap =~ /^daily/) || ($snap =~ /^weekly/) ) {
	    $snap_skip_cnt++;
	    next;
	}

	# remaining snapshot
	print "\t$snap\n";

	# keep track of snapshot count
	$snap_cnt++;
    }

    # report nice message if not snapshot directories found
    if ($snap_cnt ==0 ) {
	print "\n      No snapshots found at $snap_dir\n";
	print   "      hourly/daily/weekly snapshots were found, but excluded\n\n" if ($snap_skip_cnt != 0);
    }

    # exit program successfully
    print "\n$main::progname exited successfully.\n\n";
    exit 0;


} # end of sub &list_snapshots()





# ALL PERL PACKAGES (.pm files) must end with '1;'  
# So don't remove...
1;



############################################################
# NaServer::new
############################################################
# Prototype
#   new($server, $majorversion, $minorversion)
#
# Description
#   Creates a new object of NaServer class and sets the default value for the following object members:
#
#   $user= root
#   $password= ""
#   $style= LOGIN
#   $port= 80
#   $transport_type= HTTP
#   $servertype= FILER
#
# You can overwrite the default values by using the set Core APIs.
