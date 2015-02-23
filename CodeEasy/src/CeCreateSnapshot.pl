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

our $progname="CeCreateSnapshot.pl";    # name of this program

# command line argument values
our $volume  = "ce_test_vol";      # cmdline arg: volume to create (default name)
our $snapshot_name;                # cmdline arg: snapshot name to create
our $snapshot_create;              # cmdline arg: create snapshot 
our $snapshot_delete;              # cmdline arg: delete snapshot
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
# create snapshot
#--------------------------------------- 
&snapshot_create() if (defined $snapshot_create);


#--------------------------------------- 
# remove snapshot
#--------------------------------------- 
&snapshot_delete() if (defined $snapshot_delete);


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
  GetOptions ('h|help'           => sub { &show_help() },   

              'vol|volume=s'     => \$volume,            # volume to snapshot
	      's|snapshot=s'     => \$snapshot_name,     # snapshot name
	      'c|create'         => \$snapshot_create,   # create snapshot
	      'r|remove'         => \$snapshot_delete,   # remove snapshot

	      't|test_only'      => \$test_only,     # test filer connection then exit

              'v|verbose'        => \$verbose,           # increase output verbosity
	      '<>'               => sub { &CMDParseError() },
	      ); 

    # check that at least one of the actions has been selected
    if ((! defined $snapshot_create) and (! defined $snapshot_delete)) {
        print "\nERROR ($progname): An action has not been specified.  Either -create or -remove snapshot\n" .
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
      -h|-help                        : show this help info

      -vol|-volume   <volume name>    : volume name 
      -s  |-snapshot <snapshot name>  : volume name 
                                        default value is ce_test_vol
      -c|-create                      : create snapshot
      -r|-remove                      : remove snapshot

      -v|-verbose                     : enable verbose output

      Examples:
	create a snapshot for volume ce_test_vol
        %> $progname -vol ce_test_vol -snapshot <ce_test_vol_snapshot_01 -create

];

    print $helpTxt;
    exit 0;

} # end of sub &show_help()



###################################################################################
# snapshot_create:    create snapshot of a volume
#   $volume:          The volume to be snap'd
#   $snapshot:        Snapshot name
#
#	snapshot-create -volume   $volume   \
#	                -snapshot $snapshot
#
###################################################################################
sub snapshot_create {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    #--------------------------------------- 
    # create snapshot
    #--------------------------------------- 
    $out = $naserver->invoke("snapshot-create", "volume",   $volume, 
                                                "snapshot", $snapshot_create);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to create snapshot $volume \n";
        print "ERROR ($progname): snapshot-create returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO ($progname): Successfully created snapshot <$snapshot_create>\n";


} # end of sub snapshot_create()


###################################################################################
# snapshot_delete:    remove snapshot
#   $volume:          The volume that contains the snapshot
#   $snapshot:        Snapshot name
#
#	snapshot-delete -volume   $volume   \
#	                -snapshot $snapshot
#
###################################################################################
sub snapshot_delete {

    # temp vars for getting filer info and status
    my $out;
    my $errno;

    #--------------------------------------- 
    # delete snapshot
    #--------------------------------------- 
    $out = $naserver->invoke("snapshot-delete", "volume",   $volume, 
                                                "snapshot", $snapshot_delete);

    # check status of the invoked command
    $errno = $out->results_errno();
    if ($errno) {
        print "ERROR ($progname): Unable to delete snapshot $volume \n";
        print "ERROR ($progname): snapshot-delete returned with $errno reason: " . 
	                          '"' . $out->results_reason() . "\n";
        print "ERROR ($progname): Exiting with error.\n";
        exit 1;
    }
    print "INFO ($progname): Successfully deleted snapshot <$snapshot_delete>\n";


} # end of sub snapshot_delete()


