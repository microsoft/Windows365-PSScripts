# Introduction

The Remote Desktop Multimedia Redirection (RDMMR or MMR) is a critical tool in optimizing video played in a Cloud PC's web browser, and it needs to be kept up to date.
As of now, the MMR does not automatically update, causing many customers to have older versions of this solution still in production –
and degrading user experience. 

This script solution aims to solve these problems by detecting both the latest and the installed versions of MMR Client. If an upgrade is required,
the script will download the latest version automatically.  The script also detects if the user state is active or disconnected, and only installing
the upgrade when the user state is disconnected – avoiding end user impact.

> This solution will not work in a multi-session environment, nor with user profiles managed by FSLogix. 

## Deploying with Proactive Remediation

### Detection Script

The detection script checks for the installed and the latest available version of the MMR client.

The script will return Compliant if the latest version is installed.

If the version of the MMR client is out-of-date, or if it isn’t installed, it will return Non-Compliant.

### Remediation Script

The detection script verifies if the user is logged on, and if their state is active or inactive. The script will return Non-Compliant if the user
state is Active so as to ensure the user isn’t impacted by the upgrade. If the user state isn’t active, the script will continue to download
and install the latest version of the MMR Client.

## Remediation Stand Alone

The remediation script can be deployed without Proactive Remediation. The script has four parameters that can allow the script to run continuously
in the background until a users’ state is not active.

-retry

Using this parameter causes the script to not immediately return non-compliant if the users’ state is Active. Instead, the script will pause for a
time, and then re-check the user state. Default behavior doesn’t have this switch enabled.

-StateDetWait

This parameter sets the time in seconds that the script waits to re-check the user state. The default value is 300 seconds.

-DCNTwait

This parameter controls a secondary pause after the user state has disconnected. This wait’s purpose is to prevent impacting a user if they have accidentally disconnected from their Cloud PC, and are immediately reconnecting.  Default value is 600 seconds

-Timeout

This is a parameter to specify how long the script should continue to try and install before quitting. The default value is 60 minutes.

## Logging

Verbose logging is built into the script. By default, the scripts write their logs to c:\windows\temp. This can be changed by using the parameter -logpath. While Proactive Remediation should be able to help diagnose upgrade issues, looking at the logs can provide further insight into the script behavior.
