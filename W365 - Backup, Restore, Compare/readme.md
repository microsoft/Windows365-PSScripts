# Windows 365 - Backup, Restore, and Compare

This tool is intended to help Windows 365 Administrators protect and manage their Provisioning Policies, Azure Network Connections, and User Settings configurations. The solution achieves this through archiving Windows 365 objects in JSON format, then using those archives to restore the policies and deployments. It can also compare archived policies to current policies in Intune, which can be use for change control processes and preventing configuration drift.

## Use Cases

### Backup and Restore
Backed up Windows 365 objects can be used in the event of accidental deletion of a Provisioning Policy, ANC, or User Settings. Every backup is placed in a unique folder that is named with a timestamp. This gives a functionality very similar to version control. Deployment group names must currently named the same thing in both dev and prod environments.

### Dev / Prod 
The backups are tenant agnostic which allows for a backup to be restored to any tenant. This is useful for administrators who have separate development and production tenants and want to recreate what was built in Dev into Prod. This eliminates human error when recreating the policies in the production environment. Deployment group names must currently named the same thing in both dev and prod environments.

### Change Control Auditing
The tool can compare archived policy to current policy and list the differences, which is beneficial for change control scenarios and can prevent configuration drift or misconfigurations.

## How to use

Run the script named W365-BRC.ps1 to load the functions into PowerShell. Then use the following three commands.

### Backup

invoke-W365Backup

Parameters used:
-Object [All, ProvisioningPolicy, AzureNetworkConnection, CustomImages, UserSettings]
-Path [The folder to write the backups to]

### Restore

invoke-W365Restore

Parameters used:
-Object [All, ProvisioningPolicy, AzureNetworkConnection, CustomImages, UserSettings]
-JSON [Optional. Path to the JSON backup. If not provided, a file picker is displayed]

### Compare

invoke-W365Compare

No Parameters are used with this function.

The user will be presented with an Out-Grid view, asking first for the Object type and then the specific policy. The user will then be presented with a file picker, where they choose which backed up JSON file the previously selected object should be compared to. The result of the comparison will show what is different between the two policy objects.

## Known limitations
ANC backup and restore function does not work. GNDN. Coming soon.
Very Little Error Handling
