# Introduction

The WebRTC Client is a critical tool in optimizing the Teams experience when using Windows 365 Cloud PCs that needs to be kept up to date.
As of now, the WebRTC Client does not automatically update, causing many customers to have older versions of this solution still in production –
and degrading user experience. When updating the WebRTC Client, it also restarts Team automatically, disrupting end users who are using Teams.

This script solution aims to solve these problems by detecting both the latest and the installed versions of the WebRTC Client. If an upgrade is required,
the script will download the latest version automatically.  The script also detects if the user state is active or disconnected, and only installing
the upgrade when the user state is disconnected – avoiding end user impact.

## Deploying with Proactive Remediation

### Detection Script

The detection script checks for the installed and the latest available version of the WebRTC client, as well as the installation of Teams –
a prerequisite for the WebRTC installer.

The script will return Compliant if the latest version is installed, or if Teams is not installed.

If the version of the WebRTC client is out-of-date, or if it isn’t installed, it will return Non-Compliant.

### Remediation Script

The detection script verifies if the user is logged on, and if their state is active or inactive. The script will return Non-Compliant if the user
state is Active so as to ensure the user isn’t in an active Teams Meeting. If the user state isn’t active, the script will continue to download
and install the latest version of the WebRTC Client, as well as checking and setting required registry keys.

## Remediation Stand Alone

The remediation script can be deployed without Proactive Remediation. The script has four parameters that can allow the script to run continuously
in the background until a users’ state is not active.

-retry

Using this parameter causes the script to not immediately return non-compliant if the users’ state is Active. Instead, the script will pause for a
time, and then re-check the user state. Default behavior doesn’t have this switch enabled.

-StateDetWait

This parameter sets the time in seconds that the script waits to re-check the user state. The default value is 300 seconds.

-DCNTwait

This parameter controls a secondary pause after the user state has disconnected. This wait’s purpose is to prevent terminating a users’ Teams
sessions if they have accidentally disconnected from their Cloud PC, and are immediately reconnecting.  Default value is 600 seconds

-Timeout

This is a parameter to specify how long the script should continue to try and install before quitting. The default value is 60 minutes.

## Logging

Verbose logging is built into the script. By default, the scripts write their logs to c:\windows\temp. This can be changed by using the parameter -logpath. While Proactive Remediation should be able to help diagnose upgrade issues, looking at the logs can provide further insight into the script behavior.
