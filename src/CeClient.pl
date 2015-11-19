#!/usr/bin/perl -w  
################################################################################
# CodeEasy Customer Toolkit Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to create client for a client/server communication stream
#          The idea is the non-trusted user "client" can send a request to a
#          trusted "server" running as a trusted user process which can then
#          do things like authenticate and execute filer/sudo commands.
#          
#
# Usage:   %> CeClient.pl <args> 
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


# IO::Socket::INET provides an object interface to creating and using sockets in the AF_INET domain. 
#                  It is built upon the IO::Socket interface and inherits all the methods defined by IO::Socket.
# Install package: %> cpan install IO::Socket::INET
use IO::Socket::INET;

$socket = new IO::Socket::INET (
  PeerHost => '127.0.0.1',
  PeerPort => '40000',
  Proto => 'tcp',
) or die "Oops : $!\n";

print "Connected to the server.\n";

# read the message sent by server.
$serverdata = <$socket>;
print "Message from Server : $serverdata \n";

# Send some message to server.
#$clientdata = ".. ok, this is client speaking ...";
#print $socket "$clientdata \n";

# setup the CodeEasy command
my $ce_command = "CeCreateFlexClone -s mysnap -clone mysnap_clone";
print "<client> CE_CMD = <$ce_command>\n";

# send CodeEasy command thru the socket to the server
print $socket "CE_CMD: $ce_command\n";

$socket->close();

