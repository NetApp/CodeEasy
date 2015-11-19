#!/usr/bin/perl
################################################################################
# CodeEasy Customer Toolkit Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: Script to create server for a client/server communication stream
#          The idea is the non-trusted user "client" can send a request to a
#          trusted "server" running as a trusted user process which can then
#          do things like authenticate and execute filer/sudo commands.
#          
#
# Usage:   %> CeServer.pl <args> 
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

# IO::Socket::INET provides an object interface to creating and using sockets in the AF_INET domain. 
#                  It is built upon the IO::Socket interface and inherits all the methods defined by IO::Socket.
# Install package: %> cpan install IO::Socket::INET
use IO::Socket::INET;

$socket = new IO::Socket::INET (
    LocalHost => '127.0.0.1',
    LocalPort => '40000',
    Proto => 'tcp',
    Listen => 10,
    Reuse => 1
) or die "Oops: $! \n";
print "Server is up and running ... \n";

while (1) {
  $clientsocket = $socket->accept();
  
  print " **** New Client Connected **** \n ";
  
  # Write some data to the client  
  $serverdata = "This is server speaking ...";
  print $clientsocket "$serverdata \n";
  
  # read the data from the client
  $clientdata = <$clientsocket>;
  print "Message received from Client : $clientdata\n";

  # parse client command and process CodeEasy command options
  if ($clientdata =~ /CE_CMD:(.*)/) {
    my $CE_CMD = $1;
    print "CE_CMD Recieved: <$CE_CMD>\n";

  }
}  
  
$socket->close();

