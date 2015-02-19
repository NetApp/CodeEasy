################################################################################
# Basic Initialization Variables
# 
# This file should be customized for each project
################################################################################


#--------------------------------------- 
# AWS Test Instructions
#--------------------------------------- 
#   You can use the AWS instance and filer that we set up for our project.  
#           |-> https://console.aws.amazon.com/console/home?region=us-west-1
#
#   You can log onto AWS with the following login info:
#           Email address:    alireza.moshtaghi@netapp.com
#           Password:         April.15
#
#   You can see instances here 
#           |-> https://console.aws.amazon.com/ec2/v2/home?region=us-west-1#Instances:sort=instanceId
#   
#   The instance we used was DevOps-Build and you can connect to it using SSH:
#           ssh -i /u/vsrividy/vidya.pem ubuntu@54.183.32.123

#   Once you log onto this instance, you can ssh to the filer:
#
#   UNIX mount a new volume and change permissions on the mount
#           sudo mount -t nfs <vserver>:<junction_path> <unix mount point>
#           sudo chown <usr:grp> <unix mount point>
#
#   UNIX unmount a volume
#           sudo umount <unix mount point>
#           
#--------------------------------------- 

package CeInit;


########################################
# Users Info - for login permisions etc. 
########################################
# MJ TODO: What are these used for - need description and tie back to code
our $CE_DEVOPS_USER = "devops";      # user who has all the filer permissions.  can do any write 
                                     # operations including add/remove volume/snaps/etc.
				     # this is the user the Daemon runs as
our $CE_ROOTUSER    = "root";        # UNIX root - used only for sur
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
						    
    # location on the filer where DAEMON's volume and snapshots are stored
    our $CE_MOUNT_DAEMON_ROOT = "$CE_MOUNT_ROOT_DIR/daemon";
    # location on the filer where USER FlexClone volumes are stored
    our $CE_MOUNT_USER_ROOT   = "$CE_MOUNT_ROOT_DIR/users";

    # Volume attributes
    our $CE_DAEMON_VOL_SIZE        = "3000g";
    our $CE_CLONE_SIZE             = 500 * (10 ** 9);
    our $CE_SSRESERVE_PERCENT      = 20;
    our $CE_VOLUME_SPACE_GUARANTEE = "none";
    our $CE_SSPOLICY_DEVOPS_USER   = "devops_user";
    our $CE_POLICY_EXPORT          = "aws_bb2";
    our $CE_ATIME_UPDATE           = "false";
    our $CE_UNIX_PERMISSIONS       = "775";


########################################
# Perforce setup information
########################################
    our $CE_P4PORT = "10.14.47.6:1666";
    our $CE_CMD_P4 = "/x/eng/devops_tools/p4 -p $CE_P4PORT";



########################################
# Export variable for use by flow
########################################
our @EXPORT = qw($CE_DEVOPS_USER $CE_ROOTUSER $CE_USER $CE_GROUP @CE_ADMIN_USER$
                 $CE_CLUSTER_PORT $CE_DEFAULT_VSERVER $CE_AGGR
		 $CE_USER_ROOT $CE_DAEMON_ROOT 
                 $CE_DAEMON_VOL_SIZE 
                 $CE_MOUNT_ROOT_DIR $CE_MOUNT_DAEMON_ROOT $CE_MOUNT_USER_ROOT
                 $CE_CLONE_SIZE $CE_SSRESERVE_PERCENT $CE_VOLUME_SPACE_GUARANTEE $CE_SSPOLICY_DEVOPS_USER 
		 $CE_POLICY_EXPORT $CE_ATIME_UPDATE $CE_UNIX_PERMISSIONS
                 $CE_P4PORT $CE_CMD_P4 );


# ALL PERL PACKAGES (.pm files) must end with '1;'  
# So don't remove...
1;
