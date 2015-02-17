/*
################################################################################
# CodeEasy Customer Evaluation Script
#          This script was developed by NetApp to help demonstrate NetApp 
#          technologies.  This script is not officially supported as a 
#          standard NetApp product.
#         
# Purpose: 
#          This program performs a very fast chown operation on a large 
#          hierarchy of files.  

#          This small program is specialized version of /bin/chown that 
#          takes a numeric user id and a list of files to chown avoids 
#          fchdir() and lstat() system calls used by /bin/chown
#          [SEE BELOW FOR 'lchown' manpage]      
# 
#
# Usage:   %> fast_chown <uid|username> <file> [<more files>] 
#
# Author:  Michael Johnson (michael.johnson@netapp.com)
#           
# Copyright 2015 NetApp
#
################################################################################
*/

// look at generate_file_list() in CeUtil

#include <pwd.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

int main(
	 int argc,
	 char **argv)
{
    int ix;
    uid_t uid;
    struct passwd *pwd;
    char *endptr;

    if (argc < 3 ) {
        fprintf(stderr, "\nERROR (%s): Invalid number of arguments.\n",       argv[0]);
	fprintf(stderr,   "        Usage:  \%> %s <user id>  <file list>\n",   argv[0]);
	fprintf(stderr,   "           or:  \%> %s <username> <file list>\n\n", argv[0]);
	fprintf(stderr,   "      Example:  \%> %s builduser  file1 file2 file3\n");
	fprintf(stderr,   "                will perform the equivalent of \%> chown builduser:<unchanged> file1 file2 file3\n\n");     
	exit(1);
    }

    // convert the uid from a string to an integer value
    uid = strtol(argv[1], &endptr, 10);  /* Allow a numeric string */


    // check if the uid is actually a username.
    // if so, then look up the associated uid
    if (*endptr != '\0') {         /* Was not pure numeric string */
        pwd = getpwnam(argv[1]);   /* Try getting UID for username */
        if (pwd == NULL) {
            perror("getpwnam");
            exit(EXIT_FAILURE);
        }

	// apply the uid - and optionally report conversion of uname to uid values
        uid = pwd->pw_uid;
	fprintf(stdout, "INFO (%s): Username '%s' converted to UID '%d' \n", argv[0], argv[1], uid);
    }

    // loop thru each file passed on the command line
    for(ix=2; argv[ix]; ix++) {
	// Now perform the lchown operation
        // If the owner or group is specified as -1, then that ID is not changed.
	(void) lchown(argv[ix], uid, -1);

	// uncomment to perform error checking on lchown operations
	// this extra checking maybe noisy and run slower
	/*
        if (   lchown(argv[ix], uid, -1) == -1) {
            fprintf(stderr, "\nERROR (%s): lchown %s %i failed.\n", argv[0], argv[ix], uid);
            // exit(EXIT_FAILURE);
        }
	*/
	
    }
    return 0;
}

/*
NAME
    lchown - change the owner and group of a symbolic link

SYNOPSIS
    #include <unistd.h>

    int lchown(const char *path, uid_t owner, gid_t group); 

DESCRIPTION
    The lchown() function shall be equivalent to chown(), except in the case where the 
    named file is a symbolic link. In this case, lchown() shall change the ownership of 
    the symbolic link file itself, while chown() changes the ownership of the file or 
    directory to which the symbolic link refers.

    If the owner or group is specified as -1, then that ID is not changed.

RETURN VALUE
    Upon successful completion, lchown() shall return 0. Otherwise, it shall return -1 
    and set errno to indicate an error.

*/
