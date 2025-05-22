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
    [string]$SourceSkuId

    [ValidateNotNullOrEmpty()]
    [string]$SourceServicePlanId

    [ValidateNotNullOrEmpty()]
    [string]$GroupId

    [string]$TargetServicePlanId    

    [string]$TargetSkuId

    [string]$LisenceAssignedGroupId

    CloudPcModel (
        [string]$CloudPcId,
        [string]$DeviceName,
        [string]$UserPrincipalName,
        [string]$UserId,
        [string]$SourceServicePlanId,
        [string]$TargetServicePlanId,
        [string]$ProvisionPolicyId,
        [string]$SourceSkuId,
        [string]$TargetSkuId,
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
        $this.SourceSkuId = $SourceSkuId
        $this.TargetSkuId = $TargetSkuId
        $this.GroupId = $GroupId
        $this.LisenceAssignedGroupId = $LisenceAssignedGroupId
    }
}
