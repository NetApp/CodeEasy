################################################################################
# CodeEasy QuickStart Guide 
# Please refer to the complete docs/QUICKSTART document in the release
################################################################################

****************************************
   Introduction 
****************************************
The challenge for developers who work with large volumes of data such as 
multimedia assets, video game art, and firmware designs, etc, is the ability 
to get a quick copy of source and build assets. By using NetApp Snapshot 
and FlexClone technologies  a new workspace can be created in minutes instead of hours.

I want to introduce you to CodeEasy, NetApp's methodology for DevOps. CodeEasy
utilizes NetApp's FlexClone technology to save TB of Developer workspaces and
save developers hours of time by reducing the time to checkout and build their
workspaces.  NetApp's own internal DevOps team has been using CodeEasy for 7
years and we have recently packaged up CodeEasy into an Toolkit for
easy adoption by our customers.
 
CodeEasy is a methodology for DevOps which utilizes NetApp?s SnapShot and FlexClone 
technologies to dramatically save developer checkout and build time while also 
significantly decreasing storage usage. The CodeEasy Toolkit utilizes the 
NetApp Manageabilitys SDK to automate the steps required to create and manage 
developer FlexClone workspaces.  The best thing is CodeEasy fits into most DevOps 
environments with little to no changes.  

The CodeEasy Toolkit is so easy, that within 2 hours , you can see both the time 
and storage savings found by utilizing NetApp technologies.  By trying a few scripts 
from any code management tool (git, svn, perforce or any home grown system), and 
using NetApp?s FlexClone technology (which you already use), we can accelerate 
dev-to-production cycles, and minimize the resources needed for every dev/test environment, 
lowering the toll on the storage system and allowing you to run more such systems in 
parallel. It also makes cleanup much faster and tighter. 

A few examples: 
- NetApp's internal SW organization has been using CodeEasy for over 7 year.  
  Our figures show that using CodeEast saves roughly 100 man years per year.

- A Silicon Valley network chip manufacturer was able to reduce their checkout and build time 
  from about 55 minutes to 5 minutes and at the save time save an average of 200GB 
  per developer workspace. 
 
****************************************
  Scope 
****************************************
The CodeEasy Toolkit scripts are an open-source shared with the developer community to refine and customized. Each development environment is unique and may have requirements of security, control, workflow, etc. Thus this script is meant to be only as a starting reference which can be enhanced to support requirements of your specific development environment.

Support for this script is through the NetApp community forums. Questions and issues should be posted there for further guidance.  

****************************************
  Requirements  
****************************************
In order to be able to utilize CodeEasy Toolkit the following is required:

- cDot 8.2 or later (7-mode is not supported)
- NetApp Manageability Software Development Kit (NMSDK) 5.3.x or later

****************************************
  Support 
****************************************
Currently the CodeEasy Toolkit is only supported for Unix environments and NFS.

****************************************
  Installation
****************************************
    STEP 1: Download NetApp Managability SDK 
	The SDK can be found on the mysupport.netapp.com 
	Downloads -> Software -> NetApp Manageability SDK
	Select "All Platforms" -> Go!
	Select "NetApp Manageability SDK 5.4" -> View & Download

	After clicking thru the EULA etc, you will get a file netapp-manageability-sdk-5.4.zip

    STEP 2: Place the CodeEasy Toolkit and the SDK next to each other.
	%> cd <workspace>
	%> unzip netapp-manageability-sdk-5.4.zip

    STEP 3: Download and untar the CodeEasy Toolkit
	%> tar -zxvf CodeEasy_1.x.x.tgz

    The final directory structure should look something like.
    <workspace>/
    	netapp-manageability-sdk-5.4/
	CodeEasy_1.x.x/

    The CodeEasy Perl scripts assume the SDK is at the same level as the Toolkit.
    This can be change by editing the .pl script if a different location
    is desired.

    NOTE: If the SDK is installed in a different location, edit the path in
    the CeCommon.pm file to use the correct path.
    =>         use lib "$FindBin::Bin/../../netapp-manageability-sdk-5.4/lib/perl/NetApp";
    Or Edit  # use lib "<your_full_path>/netapp-manageability-sdk-5.4/lib/perl/NetApp";
    
