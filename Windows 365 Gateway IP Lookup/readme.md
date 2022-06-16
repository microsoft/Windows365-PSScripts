# Windows 365 Gateway IP Address Lookup Script
## Purpose
This script helps to easily retrieve the Gateway IPs associated with the Windows 365 service and outputs the list in a CSV format. This list can then be used by admins to import the data into their VPN solutions to minimize end user Cloud PC performance degradation and disconnects.

## Usage

Download the script and save it to a folder, then run it as Administrator from within the folder. There are no parameters accepted.

### How it works

The script will check if the required modules (az.network and az.accounts) are installed. If they are not installed, the script will install and import them. The script can also check if the modules are out of date by changing the variable $CheckUpdates to $True. This is disabled by default to save time.

The script will then prompt the user to provide Azure credentials. After successfully authenticating, the script will download the raw data, parse out the IP addresses, and write the list to a temporary CSV file.

On the first run of the script, it will save the downloaded information in a new CSV file (W365-Gateways.CSV). The name of the CSV file can be changed by modifying the $CSVFile variable in the beginning of the script. Do not change the path in the variable.

On subsequent runs, the script it will import the data from the existing CSV file and compare it to the temporary CSV file for differences. If no difference is found, nothing in the list has changed and the script will exit. If a difference is found, the list has updated and the existing CSV (W365-Gateways.CSV) will be updated with the latest Gateway IP addresses.

