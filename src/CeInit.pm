################################################################################
# CodeEasy Setup File
#    Basic Initialization Variables
# 
# This should be customized for each CodeEasy project.  This file is included
# by all the other CodeEasy scripts like CeCreateFlexClone.pl.
#
# Long term, this file could be replaced by a project config (.cfg) or (.xml)
# file whic contains the same information but in a loadable text format.  This
# was not implemented because the file parsing just adds additional complexity
# to this simple CodeEasy Toolkit implementation.
#
################################################################################

# declair this file (.pm) as a Perl package
package CeInit;


########################################
# NetApp Storage Config Info  
########################################
    # NetApp vserver admin access usr/pass pair
    # admin permissions to access filer 
    # IMPORTANT: the vserver admin must have 'ontapi' application access
    #            this login access to the vserver and not to the cluster.
    #            Check permission access
    #            cluster> security login show
    #
    #   SDK API Example:  $naserver->set_admin_user("vsadmin", "devops123");
    our $CE_STYLE           = "LOGIN";           # Sets the authentication mechanism to be used for communicating with the given server.
                                                 # default is 'LOGIN'
    our @CE_ADMIN_USER      = ("devops","netapp123");

    our $CE_VSERVER         = "10.45.84.128";    # name of the vserver port
    our $CE_TRANSPORT_TYPE  = "HTTP";            # The default transport type is HTTP. For secure transport, use HTTPS as the transport type.
    our $CE_PORT            = "80";              # Sets the port on which the API commands need to be invoked for the given server context
                                                 # HTTP -> use port 80, HTTPS -> use port 443

    # default volume name - is the default used by CeCreateSnapshot and CeCreateFlexClone
    our $CE_DEFAULT_VOLUME_NAME    = "project_A_jenkin_build";

    # user who owns the master volume and has sudo permissions to chown clones
    # and run filer commands
    our $CE_DEVOPS_USER = "devops";


    # Storage Mount Points
    # root of the junction path 
    # this should be mounted on the unix side, then all other flexclones are automatically mounted when created.
    #      sudo mount -t nfs <vserver>:<junction_path> <unix mount point>
    #      example:
    #      sudo mount -t nfs devops_vserver:/ce_projects /

    # location of root of the juction_path
    our $CE_JUNCT_PATH_ROOT        = "/ce_projects/";
						    
    # location on the filer where MASTER volume and snapshots are stored
    our $CE_JUNCT_PATH_MASTER      = "$CE_JUNCT_PATH_ROOT/project_A/jenkins_build";
    # Default volume will be created (or exists) at 
    #    JP = $CD_JUNCT_PATH_MASTER/$CE_DEFAULT_VOLUME_NAME
    #         /ce_projects/project_A/jenkin_build     , where jenkin_build is a volume 

    # location on the filer where USERS FlexClone volumes are stored
    our $CE_JUNCT_PATH_USERS       = "/ce_projects/project_A/users";
    # FlexClones will be created at 
    #    JP = $CE_JUNCT_PATH_USERS/<flexclone name>



########################################
# UNIX File System Setup
########################################

    # UNIX path where junction_path root volume is mounted 
    our $CE_UNIX_ROOT_VOLUME_PATH  = "/ce_projects";
    

    # UNIX path where master volume is mounted 
    #      this is volume which will be snapshot and flexcloned.
    our $CE_UNIX_MASTER_VOLUME_PATH  = "$CE_UNIX_ROOT_VOLUME_PATH/project_A/jenkin_build";

    # USER FlexClones will be stored at 
    #    /x/eng/<site>/users/<username>/<flexclone> 
    #    the CeCreateFlexClone.pl will automatically add the <username> to the
    #    path - the filer junction path will automatically mount this location
    our $CE_UNIX_USER_FLEXCLONE_PATH = "/ce_projects/project_A/users";


    #---------------------------------------- 
    # misc UNIX tool paths 
    #    this may need to be modified based on customer environment
    #---------------------------------------- 
    our $CE_CMD_FIND   = "/bin/find";
    our $CE_CMD_XARGS  = "/usr/bin/xargs";

    # sur script for handling permission changes etc.  
    # compiled as part of this kit
    our $CE_CMD_SUR    = "$FindBin::Bin/sur";



########################################
# OPTIONAL: Required to use CeCreateVolume.pl
########################################
    #---------------------------------------- 
    # Volume attributes 
    #   ONLY USED with CeCreateVolume.pl
    #   if CeCreateVolume.pl is not going to be used, these setting can be
    #   skipped.
    #
    #   Refer to the "Data ONTAP 8.2 Reference: CLI Session/Navigation Commands"
    #   for more options for use with the volume-create command.
    #---------------------------------------- 
    # [-user <user name>] - User ID
    #                       This optionally specifies the name or ID of the user that is set as the owner of the volume's root.
    my $CE_VOL_OWNER  = "root";       
    my $user_id       = getpwnam($CE_VOL_OWNER); 

    # [-group <group name>] - Group ID
    #                         This optionally specifies the name or ID of the group that is set as the owner of the volume's root.
    my $CE_VOL_GROUP  = "root";      # UNIX group name: project or dept group to use
    my $group_id      = getpwnam($CE_VOL_GROUP); 


    # REQUIRED options for volume-create (as found in CeCreateVolume.pl)
    our @CE_VOLUME_CREATE_REQUIRED = ("containing-aggr-name", 'aggr1_clus03_03_400SSD'
                                     );

    # OPTIONAL options for volume-create (as found in CeCreateVolume.pl)
    #          add or remove option pairs as needed.  
    our @CE_VOLUME_CREATE_OPTIONS  = ("size",                  '3000g',
                                      "unix-permissions",      '777',
                                      "export-policy",         'codeeasy_exports',
                                      "snapshot-policy",       'default',
                                      "user-id",               $user_id, 
                                      "group-id",              $group_id,
                                      "space-reserve",         'none',
				      "volume-security-style", 'unix'
				      );
                                                     


########################################
# Export variable for use by flow
########################################
our @EXPORT = qw(@CE_ADMIN_USER$
                 $CE_VSERVER 
		 $CE_STYLE
                 $CE_TRANSPORT_TYPE $CE_PORT
                 $CE_DEVOPS_USER
                 $CE_UNIX_ROOT_VOLUME_PATH $CE_JUNCT_PATH_ROOT
		 $CE_UNIX_USER_FLEXCLONE_PATH $CE_UNIX_MASTER_VOLUME_PATH 
                 $CE_DEFAULT_VOLUME_NAME  $CE_JUNCT_PATH_ROOT $CE_JUNCT_PATH_MASTER $CE_JUNCT_PATH_USERS
		 @CE_VOLUME_CREATE_REQUIRED @CE_VOLUME_CREATE_OPTIONS
                 $CE_CMD_FIND $CE_CMD_XARGS 
                 );


# ALL PERL PACKAGES (.pm files) must end with '1;'  
# So don't remove...
1;
