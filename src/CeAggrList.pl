#!/usr/bin/perl -w 
################################################################################
# CodeEasy Customer Toolkit Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to get aggregate characteristics
#          
#
# Usage:   %> CeAggrList.pl <args> 
#
# Author:  Michael Arndt (michael.arndt@netapp.com)
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
use CeInit;        # contains CodeEasy script setup values (CeInit.pm file)
use CeCommon;      # contains CodeEasy common Perl functions; like &init_filer()


############################################################
# Global Vars / Setup
############################################################

our $progname="CeAggrList.pl";    # name of this program

# command line argument values
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
# Get aggr characteristics
#--------------------------------------- 
&get_aggrs();

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
  GetOptions ("h|help"           => sub { &show_help() },   

	      't|test_only'      => \$test_only,     # test filer connection then exit

              'v|verbose'        => \$verbose,       # increase output verbosity
	      '<>'               => sub { &CMDParseError() },
	      ); 

} # end of sub parse_cmd_line()


########################################
# Error handling for cmd line parsing problems
########################################
sub CMDParseError {
    # report cmd line parsing errors, display help then exit
    print "\nERROR ($progname): Unrecognized command line option.\n" .
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

      -v|-verbose                     : enable verbose output

      -t|-test                        : test connection to filer then exit

      Examples:
	Get listing of aggregates and their properties
        %> $progname 

];

    print $helpTxt;
    exit 0;

} # end of sub &show_help()


###################################################################################
# get_aggrs: Retrieve list of aggregates and some size details
###################################################################################   
sub get_aggrs {

    # temp vars for getting filer info and status
    my $out;
    my $errno;
    my (%aggr_data,$aggr_name);

    # Clear the set_vserver, this API must run against the cluster.
    $naserver->set_vserver("");

    #--------------------------------------- 
    # get list of aggrs
    #--------------------------------------- 
    my @slist = &CeCommon::vGetcDOTList( $naserver, "aggr-get-iter" );
    if ($#slist == 0) {
        print "ERROR ($progname): Error running aggr-get-iter.  Exiting.\n";
        exit 1;
    } 
    printf "%-32s %10s %10s %10s %10s %10s\n", "Aggregate Name", "Size (TB)", "Used (TB)", "Free (TB)", "Used (\%)", "Vol Count";
    print  "------------------------------------------------------------------------------------------------------\n";
    foreach my $aggr (@slist) {
        my $aggr_name   = $aggr->child_get_string("aggregate-name");
	my $space_attrs = $aggr->child_get("aggr-space-attributes");
	my $count_attrs = $aggr->child_get("aggr-volume-count-attributes");
	my $raid_attrs  = $aggr->child_get("aggr-raid-attributes");
	my $size        = $space_attrs->child_get_string("size-total");
	my $used        = $space_attrs->child_get_string("size-used");
	my $free        = $space_attrs->child_get_string("size-available");
	my $perc        = $space_attrs->child_get_string("percent-used-capacity");
	my $volcount    = $count_attrs->child_get_string("flexvol-count");
	my $isroot      = $raid_attrs->child_get_string("is-root-aggregate");
	next if ($isroot eq "true");
	$aggr_data{$aggr_name}{'size'} = sprintf "%0.1f", ($size / (1024*1024*1024*1024));
	$aggr_data{$aggr_name}{'used'} = sprintf "%0.1f", ($used / (1024*1024*1024*1024));
	$aggr_data{$aggr_name}{'free'} = sprintf "%0.1f", ($free / (1024*1024*1024*1024));
	$aggr_data{$aggr_name}{'perc'} = $perc;
	$aggr_data{$aggr_name}{'volcount'} = $volcount;
    }

    for $aggr_name (sort {$aggr_data{$b}{'free'} <=> $aggr_data{$a}{'free'}} keys %aggr_data) {
       printf "%-32s %10s %10s %10s %10s %10s\n", $aggr_name, $aggr_data{$aggr_name}{'size'}, $aggr_data{$aggr_name}{'used'}, $aggr_data{$aggr_name}{'free'}, $aggr_data{$aggr_name}{'perc'}, $aggr_data{$aggr_name}{'volcount'};
    }

} # end of sub create_dp_volume()

