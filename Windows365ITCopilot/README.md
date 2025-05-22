# Windows 365 IT Copilot
The purpose of these PowerShell scripts is to demonstrate the functionality of various cmdlets that assist administrators in manually managing their Cloud PC-related resources. While all the capabilities provided by these scripts are also available through the Microsoft Intune portal, the scripts offer an alternative method for those who prefer or require automation and command-line control.

To use these scripts effectively, administrators need to supply relevant data sources. This information can be conveniently retrieved from the Windows 365 IT Copilot experience within the Intune portal. The IT Copilot provides contextual insights and data that can be used to populate script parameters, making the management process more efficient and tailored to your environment.

These scripts are particularly useful for scenarios such as bulk operations, scheduled tasks, or integration into broader automation workflows, where using the graphical interface might be less practical.

## LicenseManagement.psm1
This PowerShell script is designed to help you manage your Cloud PC licenses more efficiently. It streamlines the processes of resizing by automating the manual steps involved in upgrading, downgrading, and reclaiming licenses, thereby improving operational efficiency and reducing administrative overhead.

### Resize-CloudPCs
This function is used to resize Enterprise Cloud PCs, including those assigned licenses directly as well as those managed through group-based licensing.

#### Parameters

##### CloudPCBasedUrl
The CloudPC graph based url

##### TenantId
The TenantId

##### CloudPCListPath
The path of the source data, it should be a csv file

#### Required Permission
User.ReadWrite.All, CloudPC.ReadWrite.All, Group.ReadWrite.All

#### Example

PowerShell Command
```powershell
Import-Module "C:\repos\Windows365-PSScripts\Windows365ITCopilot\LicenseManagement.psm1" -Force
Reclaim-CloudPCs -TenantId "633fc03f-56d0-459c-a1b5-ab5083fc35d4" -CloudPCListPath "C:\repos\Windows365-PSScripts\Windows365ITCopilot\SampleData\SampleDataForLicenseManagement.CSV"
```

Step1: Setup environment, connect to graph
![ReclaimConnectionToGraph](./Image/ReclaimConnectionToGraph.png)

Step2 (manually consent): You need to consent to remove licnenses
![ConsentToRemoveLicense](./Image/ConsentToRemoveLicense.png)

Step3 (manually consent):
Wait for All the Cloud PCs enter into grace period status and you need to consent to start deprovision Cloud PCs
![WaitToGracePeriodStatus](./Image/WaitToGracePeriodStatus.png)

Step4:
Success to depovision CloudPCs
![DeprovisionSuccess.png](./Image/DeprovisionSuccess.png)

### Resize-CloudPCs
This function is used to resize Enterprise Cloud PCs, including those assigned licenses directly as well as those managed through group-based licensing.

#### Parameters

##### CloudPCBasedUrl
The CloudPC graph based url

##### TenantId
The TenantId

##### CloudPCListPath
The path of the source data, it should be a csv file

#### Required Permission
User.ReadWrite.All, CloudPC.ReadWrite.All, Group.ReadWrite.All

#### Example
PowerShell Command
```powershell
Import-Module "C:\repos\Windows365-PSScripts\Windows365ITCopilot\LicenseManagement.psm1" -Force
Resize-CloudPCs -TenantId "633fc03f-56d0-459c-a1b5-ab5083fc35d4" -CloudPCListPath "C:\repos\Windows365-PSScripts\Windows365ITCopilot\SampleData\SampleDataForLicenseManagement.CSV"
```

Step1: Setup environment, connect to graph
![ResizeConnectionToGraph](./Image/ResizeConnectionToGraph.png)

Step2 (manually consent): You need to consent to trigger bulk resize action
![ConsentToTriggerBulkResize](./Image/ConsentToTriggerBulkResize.png)

Step3: Wait all group based license Cloud PCs enter license pending status
![ResizePending](./Image/ResizePending.png)

Step4 (manually consent): You need to consent to remove the user from the source group
![ConsentToRemoveUser](./Image/ConsentToRemoveUser.png)

Step5 (manually consent): You need to consent to create a new group and naming for the new group
![ConsentToCreateNewGroup](./Image/ConsentToCreateNewGroup.png)

Step6 (manually consent): You need to consent to add users to the new group and assign license
![ConsentToAddUserAndAssignLicense](./Image/ConsentToAddUserAndAssignLicense.png)

Step7: Resize Successfully
![ResizingSuccess](./Image/ResizingSuccess.png)
