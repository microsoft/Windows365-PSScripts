# Windows 365 Gateway IP Address Lookup Script
## Purpose
This script helps to easily retrieve the Gateway IPs associated with the Windows 365 service and outputs the list in a CSV format. This list can then be used by admins to import the data into their VPN solutions to minimize end user Cloud PC performance degradation and disconnects.

## Usage

To use this script, simply run it. There are no parameters to pass. 

### How it works

The script will check if the required modules (az.network and az.accounts) are installed and up to date. If they are not installed, the script will install them. If they are installed, but out of date, the script will state so - but will not update the modules.

It will then check to see if the path for the script is available, and if not, it will create the folder. If the CSV file is already present, the script will prompt to either Overwrite or Archive the existing CSV file. If Overwrite is chosen, the existing CSV file will be deleted and a new CSV file will be created. If Archive is chosen, the existing script will have a file extension of ".old" appended to the file. If an existing .old file exists, it will be deleted.

Next, the script will prompt the user to provide Azure credentials. Upon entering credentials, the script will query Azure, parse the data, and output the list of Gateway IP addresses to the CSV file.

### Changing the output file
The name and path of the CSV file can be changed by modifying the $CSVFile variable found near the beginning of the script. 
