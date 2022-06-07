# Teams Client Installer Fix
This example script set is intended for use with Proactive Remediation. This package is only intended for use with Windows 365 Enterprise systems. Further modification must be done for it to work with Business SKUs that are not leveraging MEM.  Do not deploy this package to Azure Virtual Desktop multi-session hosts.

## The Problem it Solves
The functionality around installing Teams Machine Wide Installer for VDI had a slight change that impacted the ability for installed Teams clients to auto-update or have the user run an update check. This example solution uninstalls the Teams client, downloads and installs Teams Machine Wide Installer with the proper arguments, removes a Registry Key that can prevent the Teams client from installing, and then sets up a scheduled task to allow the Teams client to be reinstalled without a reboot or logoff.

## Detection Script
The detection script checks three paths for the presence of the Teams client. If the Teams client is found in either Program Files or Program Files (x86), or isn't detected at all the script will return non-compliant. If the Teams client is found in the users' Appdata folder the script returns compliant.

## Remediation Script
The remediation script first checks to see if a user is logged into the Cloud PC, and if their user state is disconnected. If the user is currently logged in and active, the script will exit. This is to ensure the end user isn't disturbed by the remediation process. If the user isn't logged in or they are in a disconnected state, the script starts the remediation.

The following steps are what happens during Remediation:
- Download Teams Machine Wide Installer MSI and stages the file in C:\Windows\Temp
- Kills all active Teams processes
- Scan the registry to find the GUID of Teams Machine Wide Installer.
- Uninstall existing Teams Machine Wide Installer using GUID from previous step
- Uninstall existing Teams client installation
- Installs Teams Machine Wide Installer 
- Checks for, and removes if found, a registry key value that prevents the installation of the Teams client
- Checks again to see if a user is logged in. If not, the script returns compliant

At this point, when the user logs into their Cloud PC, the Teams client should install automatically.

If a user is logged on but disconnected from the Cloud PC after the prior steps complete, Teams client will not automatically install until the Cloud PC is rebooted or the user logs out and back in. This is not a desireable outcome as it impacts the user and can possibly generate help desk tickets. In order to avoid this situation, the remediation script performs the following steps:
- Determines the users' SID from the registry
- Creates a XML file with information to create a Scheduled Task
- Creates a PS1 file for the Scheduled Task to run
- Creates the scheduled task

At this point, the Remediation script will return success.

## The Scheduled Task and PowerShell Script
In order to have the Teams client install, the installer must be run with the end-users' account. The Scheduled Task uses the users' SID to populate the account that will be used when running the script. The scheduled task is set to run on Remote Connection, which is triggered when a user reconnects to their Cloud PC. The Scheduled Task is set to expire after a given time - the default being 3 days. This is to stop the task from running in perpetuity. This time frame can be adjusted by altering the $DayOffset variable in the Remediation Script.

When the Scheduled Task is executed, the following steps occur:
- Checks for the existing of temporary files to indicate if the script has already successfully run. If files are not found, the script exits
- The Teams client installer is executed by the users' account
- Attempts to delete the scheduled task. This will fail if the user does not have administrative rights
- Removes temporary files (Machine Wide Installer MSI and Scheduled Task XML)

## Logging
This package will generate three log files:
- Detection Script - c:\windows\temp\Teams-MWI-detect.log
- Remediation Script - c:\windows\temp\Teams-MWI-remediate.log
- Scheduled Task Script - c:\windows\temp\Teams-MWI-remediate-child.log

