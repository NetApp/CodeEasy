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
use CeInit;



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
    my $naserver = NaServer->new($CeInit::CE_CLUSTER_PORT, 1, 1);

    #$naserver->set_admin_user("vsadmin", "devops123");
    $naserver->set_admin_user(@CeInit::CE_ADMIN_USER);
    $naserver->set_transport_type("HTTP");
    if ($CeInit::CE_DEFAULT_VSERVER) {
        printf "INFO  ($main::progname): %-16s=> %s\n", "vserver", $CeInit::CE_DEFAULT_VSERVER;
        $naserver->set_vserver($CeInit::CE_DEFAULT_VSERVER);
    }

    $out =  $naserver->invoke("system-get-version");

    # check error status and exit if basic communication with the file can't be estabilished.
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($main::progname): FAIL: Unable to obtain $CeInit::CE_CLUSTER_PORT version\n";
        print "ERROR ($main::progname): system-get-version returned with $errno and reason: " . 
	                          '"' .  $out->results_reason() . "\n";
        print "ERROR ($main::progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO ($main::progname): Filer <$CeInit::CE_CLUSTER_PORT> is running cDOT version\n" .  
                $out->child_get_string("version") . " \n";

    return $naserver;

} # end of init_filer()




# ALL PERL PACKAGES (.pm files) must end with '1;'  
# So don't remove...
1;


