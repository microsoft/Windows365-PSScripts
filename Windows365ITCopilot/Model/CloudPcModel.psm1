class CloudPcModel {
    [ValidateNotNullOrEmpty()]
    [string]$CloudPcId

    [ValidateNotNullOrEmpty()]
    [string]$DeviceName

    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName

    [ValidateNotNullOrEmpty()]
    [string]$UserId
    
    [ValidateNotNullOrEmpty()]
    [string]$ProvisionPolicyId

    [ValidateNotNullOrEmpty()]
    [string]$SkuId

    [ValidateNotNullOrEmpty()]
    [string]$SourceServicePlanId

    [ValidateNotNullOrEmpty()]
    [string]$GroupId

    [string]$TargetServicePlanId    

    [string]$LisenceAssignedGroupId

    CloudPcModel (
        [string]$CloudPcId,
        [string]$DeviceName,
        [string]$UserPrincipalName,
        [string]$UserId,
        [string]$SourceServicePlanId,
        [string]$TargetServicePlanId,
        [string]$ProvisionPolicyId,
        [string]$SkuId,
        [string]$GroupId,
        [string]$LisenceAssignedGroupId
    ) {
        $this.CloudPcId = $CloudPcId
        $this.DeviceName = $DeviceName
        $this.UserPrincipalName = $UserPrincipalName
        $this.UserId = $UserId
        $this.ProvisionPolicyId = $ProvisionPolicyId
        $this.SourceServicePlanId = $SourceServicePlanId
        $this.TargetServicePlanId = $TargetServicePlanId
        $this.SkuId = $SkuId
        $this.GroupId = $GroupId
        $this.LisenceAssignedGroupId = $LisenceAssignedGroupId
    }
}
