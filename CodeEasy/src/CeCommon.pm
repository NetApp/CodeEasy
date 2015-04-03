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
# Usage:   %> CeCreateVole.pl <args> 
#
# Author:  Michael Johnson (michael.johnson@netapp.com)
#           
#
# Copyright 2015 NetApp
#
################################################################################

# declair this file (.pm) as a Perl package
package CeCommon;

use Env;           # package to allow reading UNIX environment vars
use Cwd;
use FindBin();     # The FindBin helps indentify the path this executable and thus its path
use strict;        # require strict programming rules


#---------------------------------------- 
# load NetApp manageability SDK APIs
#---------------------------------------- 
# SDK setenv not set, assume the SDK is in parallel to the CodeEasy
# tarball installation    ***** CUSTOMIZE ME *****
use lib "$FindBin::Bin/../../netapp-manageability-sdk-5.2.2/lib/perl/NetApp";

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
    print "\tstorage controler  = $CeInit::CE_CLUSTER_PORT\n";
    my $naserver = NaServer->new($CeInit::CE_CLUSTER_PORT, 1, 1);

    # sets the name of the Storage Virtual Machine (SVM, formerly known as Vserver) 
    # to which a Cluster API need to be tunneled from a Cluster Management Interface.
    print "\tset_vserver        = $CeInit::CE_DEFAULT_VSERVER\n";
    $naserver->set_vserver($CeInit::CE_DEFAULT_VSERVER);

    # set API transport type - HTTP is the default
    print "\tset_transport_type = HTTP\n";
    $naserver->set_transport_type("HTTP");

    # pass username/password for vserver ontapi application access
    #     $naserver->set_admin_user("vsadmin", "devops123");
    $naserver->set_admin_user(@CeInit::CE_ADMIN_USER);

    # check connection to the filer by requesting a simple ontapi version status
    $out =  $naserver->invoke("system-get-version");

    # check error status and exit if basic communication with the filer can't be estabilished.
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($main::progname): FAIL: Unable to connect to $CeInit::CE_CLUSTER_PORT \n";
        print "ERROR ($main::progname): system-get-version returned with $errno and reason: " . 
	                          '"' .  $out->results_reason() . "\n";
        print "ERROR ($main::progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO  ($main::progname): Storage Controller <$CeInit::CE_CLUSTER_PORT> is running ONTAP API version:\n" . 
          "      " . $out->child_get_string("version") . " \n\n";
      

    # check that filer is running cDOT and not 7-mode
    if ( $out->child_get_string("is-clustered") eq "true") {
	print "\nDEBUG ($main::progname): Storage Controller <$CeInit::CE_CLUSTER_PORT> is running cDOT.\n\n" if ($main::verbose);
    } else {
	print   "ERROR ($main::progname): Storage Controller <$CeInit::CE_CLUSTER_PORT> is running in 7-mode\n" .
	        "       These scripts support cDOT (Clustered Data OnTap) only\n" .
	        "Exiting...\n";
	exit 1;
    }

    # return to calling program
    return $naserver;

} # end of init_filer()




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
