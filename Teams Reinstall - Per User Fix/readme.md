# Teams Client Installer Fix
This example script set is intended for use with Proactive Remediation. The remediation script should work as a stand-alone option for Business customers, but this hasn't been tested yet.

## The Problem it Solves
The functionality around installing Teams Machine Wide Installer for VDI had a slight change that impacted the ability for installed Teams clients to auto-update or have the user run an update check. This uninstalls the Teams client, downloads and installs Teams Machine Wide Installer with the proper arguemnts, removes a Registry Key that can prevent the Teams client from installing, and then sets up a scheduled task to allow the Teams client to be reinstalled without a reboot or logoff.

## Detection Script
The detection script checks three paths for the presence of the Teams client. If the Teams client is found in either Program Files or Program Files (x86), the script will return non-compliant. If the Teams client is found in the users' Appdata folder or it doesn't find an installation, the script returns complant.

## Remediation Script
The remediation script first checks to see if a user is logged into the Cloud PC, and if their user state is disconnected. If the user is currently logged in and active, the script will return non-compliant. This is to ensure the end user isn't disturbed by the remediation process. If the user isn't logged in or they are in a disconnected state, the script starts the remediation.

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

If a user is determined to be logged into the Cloud PC, Teams client will not automatically install until the CPC is rebooted or the user logs out and back in. This is not a desireable outcome as it impacts the user and can possibly generate help desk tickets. In order to avoid this situation, if the remediation script determines the user is logged in, the following steps occur:
- Determines the users' SID from the registry
- Creates a XML file with information to create a Scheduled Task
- Creates a PS1 file for the Scheduled Task to run
- Creates the scheduled task

At this point, the Remediation script will return compliant.

## The Scheduled Task and PowerShell Script
In order to have the Teams client install, the installer must be run with the users' account. The Scheduled Task uses the users' SID to populate the account that will be used when running the script. The scheduled task is set to run on Remote Connection, which is triggered when a user reconnects to their Cloud PC. The Scheduled Task is set to expire after a given time, the default being 3 days. This is to stop the task from running in perpatuity. This timeframe can be adjusted by altering the $DayOffset variable in the Remediation Script.

When the Scheduled Task is executed, the following steps occur:
- Checks for the existing of temporary files to indicate if the script has already succesfully run. If files are not found, the script exits
- The Teams client installer is executed by the users' account
- Attempts to delete the scheduled task. This will fail if the user does not have administrative rights
- Removes temporary files (Machine Wide Installer MSI and Scheduled Task XML)

## Logging
This package will generate three log files:
- Detection Script - c:\windows\temp\Teams-MWI-detect.log
- Remediation Script - c:\windows\temp\Teams-MWI-remediate.log
- Scheduled Task Script - c:\windows\temp\Teams-MWI-remediate-child.log

