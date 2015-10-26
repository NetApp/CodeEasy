/*
################################################################################
# CodeEasy Customer Toolkit Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: 
#          This program performs runs a command line as a new user, such
#          as a devops or build user who has permissions to do things
#          like create snapshot, create flexclones, etc.
#
#          [SEE BELOW FOR 'setuid' manpage]      
# 
#
# Usage:   %> sur <sur_dispatch_exe> <super username> <command line to execute>
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
*/

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <libgen.h>
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>

main (int argc, char ** argv) {
    int    id;
    char * sur_dispatch_exe;
    char * suser;
    int    suid;
    struct passwd * pw;
    int ix;
    

    // check that minimum number of command line arguments were passed
    if (argc <= 3) {
        fprintf(stderr, "\nERROR (%s): Invalid number of arguments.\n",       argv[0]);
	fprintf(stderr,   "        Usage:  \%> %s <username> <sur_dispatch cmd>  <cmdline to execute>\n\n", argv[0]);
	fprintf(stderr,   "      Example:  \%> %s /codeeasy_path/bin/sur devops 'CeChownList.pl -d <dir> -u <user> ' \n", argv[0]);
	fprintf(stderr,   "                will perform the equivalent of \%> chown <user>:<unchanged> file1 file2 file3\n\n");     
	exit(1);
    }

    // capture command line values 
    suser            = argv[1];
    sur_dispatch_exe = argv[2];  

    //-------------------------------------- 
    // determine new user id and then switch process id
    //-------------------------------------- 

    // Try getting UID from username passed from the cmd line
    pw = getpwnam (suser);
    if (pw == NULL) {
        fprintf (stderr, "\nERROR (%s): Failed to get UID for USER '%s'\n", argv[0], suser);
        fprintf (stderr,   "      Check that username exists.\n\n");
        exit (1);
    }

    // apply the uid
    suid = pw->pw_uid;
    fprintf(stdout, "INFO  (%s): Username '%s' converted to UID '%d' \n", argv[0], suser, suid);

    // set the new uid - all child processes will be run as the user with the new uid
    setuid (suid);

    // check that the new uid was actually set properly
    id = getuid ();
    if (id != suid) {
        fprintf (stderr, "ERROR (%s): Sur command failed to set UID to %d\n", argv[0], suid);
        exit (1);
    }

    //-------------------------------------- 
    // check that the sur_dispatch_exe is found and is executable
    //-------------------------------------- 
    if (access (sur_dispatch_exe, F_OK) == 0) {
        fprintf(stdout, "INFO  (%s): sur_dispatch_cmd = %s\n", argv[0], sur_dispatch_exe);
    } else {
        fprintf(stdout, "ERROR (%s): sur_dispatch_cmd '%s' not found.\n       %s\n", argv[0], sur_dispatch_exe);
	// Now perform the lchown operation
	exit(1);
    }

    //-------------------------------------- 
    // execute command with new uid
    //-------------------------------------- 
    // show command line which will launch via execv
//fprintf(stdout, "INFO  (%s): execv command.\n", argv[0]);
//    fprintf(stdout, "      (user=%s) \%> %s", suser, sur_dispatch_exe);
    fprintf(stdout, "INFO  (%s): Executing as user=%s \%> %s ", argv[0], suser, sur_dispatch_exe);
    
    // loop thru each file passed on the command line
    for(ix=3; argv[ix]; ix++) {
	fprintf(stdout, " %s", argv[ix]);
    }
    fprintf(stdout, "\n");


    // Like all of the exec functions, execv replaces the calling process image with a new process image. 
    // This has the effect of running a new progam with the process ID of the calling process. 
    // Note that a new process is not started; the new process image simply overlays the original process image. 
    // The execv function is most commonly used to overlay a process image that has been created by a call to the fork function.
    //
    // NOTE: &argv[2] contains all the cmd line args AFTER the 2 element.  aka: argv[3], argv[4], ...argv[n]
    //       Example: execv( sur_dispatch, <cmd line to execute with new UID> )
    if (execv (sur_dispatch_exe, &argv[2]) == -1) {
	fprintf(stderr, "ERROR (%s): execv command failed.\n", argv[0]);

	fprintf(stderr, "ERROR (%s): System call command failed.   \%> %s ", argv[0], sur_dispatch_exe);
	// loop thru each file passed on the command line
	for(ix=3; argv[ix]; ix++) {
	    fprintf(stdout, " %s", argv[ix]);
	}
	fprintf(stdout, "\n");
	fprintf(stdout, "Exiting...\n");

	// exit on error
	exit (1);
    } else {
	fprintf(stdout, "INFO  (%s): sur_dispatch_exe completed successfully.\n", argv[0], sur_dispatch_exe);
    }

    exit(1);

} 


/*
Name
    setuid - set user identity

Synopsis
    #include <sys/types.h>
    #include <unistd.h>
    int setuid(uid_t uid);

Description
    setuid() sets the effective user ID of the calling process. If the effective 
    UID of the caller is root, the real UID and saved set-user-ID are also set.
    Under Linux, setuid() is implemented like the POSIX version with the _POSIX_SAVED_IDS 
    feature. This allows a set-user-ID (other than root) program to drop all of its user 
    privileges, do some un-privileged work, and then reengage the original effective 
    user ID in a secure manner.

    If the user is root or the program is set-user-ID-root, special care must be taken. 
    The setuid() function checks the effective user ID of the caller and if it is the 
    superuser, all process-related user ID's are set to uid. After this has occurred, 
    it is impossible for the program to regain root privileges.

    Thus, a set-user-ID-root program wishing to temporarily drop root privileges, assume 
    the identity of an unprivileged user, and then regain root privileges afterward cannot 
    use setuid(). You can accomplish this with seteuid(2).

Return Value
    On success, zero is returned. On error, -1 is returned, and errno is set appropriately.

*/
