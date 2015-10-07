################################################################################
# Makefile for building CodeEasy C-programs 
#
# Programs:
#   sur - is a program which allows a sub program to run with root permission.
#
#   fast_chown - is a program which reads a file of directories and files and 
#                then performs a very fast parallel 'chown' operation to
#                change permission of the files and directories
#
#   PERMISSIONS: chmod 0711    -> user            read/write/exe
#                                 group and other exe only
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

# sudo command
#    because the two programs below will compiled as root, since root
#    permissions are required to do operations like 'chown'.


# build all targets
all: sur fast_chown

# build the 'sur' program
# chmod u+s enables setuid to work
sur: sur.c
	sudo gcc -o sur sur.c
	sudo chmod 4755 sur

# build the 'fast_chown' program
fast_chown: fast_chown.c
	sudo gcc -O2 -o fast_chown fast_chown.c
	sudo chmod 4755 fast_chown

# clean or remove prior builds 
clean:
	sudo rm -f sur fast_chown

