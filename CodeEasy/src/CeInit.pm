################################################################################
# CodeEasy Setup File
#    Basic Initialization Variables
# 
# This file should be customized for each project
################################################################################

# declair this file (.pm) as a Perl package
package CeInit;


########################################
# Users Info - for login permisions etc. 
########################################

    our $CE_DEVOPS_USER = "devops";      # user who has filer permissions.  can do any write 
					 # operations including add/remove volume/snaps/etc.
					 # this is the user the Daemon runs as

    our $CE_USER        = "unknown";     # Average user - set to unknown for now until determined by script
    our $CE_GROUP       = "ubuntu";      # UNIX group name: project or dept group to use

    # NetApp filer access usr/pass pair
    # admin permissions to access filer - used as part of volume creation process
    #   Example:    $naserver->set_admin_user("vsadmin", "devops123");
    our @CE_ADMIN_USER  = ("vsadmin","devops123");



########################################
# UNIX File System Setup
########################################
    # UNIX root path where volumes will be mounted 
    our $CE_DAEMON_ROOT          = "/x/eng/devops/daemon";
    our $CE_USER_ROOT            = "/x/eng/devops/users";     
    # USER FlexClones will be stored at 
    #    /x/eng/<site>/users/<username>/<flexclone> 

    # symlink to the daemon's space - location of build environment


########################################
# NetApp Storage Config Info  
########################################
    our $CE_CLUSTER_PORT    = "sv5-devops-01";    
    our $CE_DEFAULT_VSERVER = "sv5-devops-01";
    our $CE_AGGR            = "aggr_devops_05";

    # Storage Mount Points
    # root of the junction path 
    # this should be mounted on the unix side, then all other flexclones are automatically mounted when created.
    #      sudo mount -t nfs <vserver>:<junction_path> <unix mount point>
    our $CE_MOUNT_ROOT_DIR    = "/share/devops";    
						    
    our $CE_DEFAULT_VOLUME_NAME    = "ce_test_volume";
    # location on the filer where DAEMON's volume and snapshots are stored
    our $CE_MOUNT_DAEMON_ROOT      = "$CE_MOUNT_ROOT_DIR/daemon";
    # location on the filer where USER FlexClone volumes are stored
    our $CE_MOUNT_USER_ROOT        = "$CE_MOUNT_ROOT_DIR/users";

    # Volume attributes
    our $CE_DAEMON_VOL_SIZE        = "3000g";
    our $CE_CLONE_SIZE             = 500 * (10 ** 9);
    our $CE_SSRESERVE_PERCENT      = 20;
    our $CE_VOLUME_SPACE_GUARANTEE = "none";
    our $CE_SSPOLICY_DEVOPS_USER   = "devops_user";
    our $CE_POLICY_EXPORT          = "aws_bb2";
    our $CE_ATIME_UPDATE           = "false";
    our $CE_UNIX_PERMISSIONS       = "775";

    # misc UNIX tool paths - this may need to be modified based on customer
    # environment
    our $CE_CMD_FIND   = "/usr/bin/find";
    our $CE_CMD_XARGS  = "/usr/bin/xargs";

    # sur script for handling permission changes etc.  
    # compiled as part of this kit
    our $CE_CMD_SUR    = "$FindBin::Bin/sur";


########################################
# Export variable for use by flow
########################################
our @EXPORT = qw($CE_DEVOPS_USER $CE_USER $CE_GROUP @CE_ADMIN_USER$
                 $CE_CLUSTER_PORT $CE_DEFAULT_VSERVER $CE_AGGR
		 $CE_USER_ROOT $CE_DAEMON_ROOT 
                 $CE_DAEMON_VOL_SIZE 
                 $CE_DEFAULT_VOLUME_NAME  $CE_MOUNT_ROOT_DIR $CE_MOUNT_DAEMON_ROOT $CE_MOUNT_USER_ROOT
                 $CE_CLONE_SIZE $CE_SSRESERVE_PERCENT $CE_VOLUME_SPACE_GUARANTEE $CE_SSPOLICY_DEVOPS_USER 
		 $CE_POLICY_EXPORT $CE_ATIME_UPDATE $CE_UNIX_PERMISSIONS
                 $CE_CMD_FIND $CE_CMD_XARGS 
                 $CE_P4PORT $CE_CMD_P4 );


# ALL PERL PACKAGES (.pm files) must end with '1;'  
# So don't remove...
1;
