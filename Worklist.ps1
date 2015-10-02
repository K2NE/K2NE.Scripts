Add-Type -AssemblyName ('SourceCode.Workflow.Client, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d')
$k2con = New-Object -TypeName SourceCode.Workflow.Client.Connection
$k2con.Open("localhost")
$k2con.ImpersonateUser("K2:DENALLIX\jonno");

$wlc = New-Object -TypeName SourceCode.Workflow.Client.WorklistCriteria
$wlc.AddFilterField([SourceCode.Workflow.CLient.WCLogical]::Or, [SourceCode.Workflow.CLient.WCField]::WorklistItemOwner, "Me", [SourceCode.Workflow.Client.WCCompare]::Equal, [SourceCode.Workflow.CLient.WCWorklistItemOwner]::Me);
$wlc.AddFilterField([SourceCode.Workflow.CLient.WCLogical]::Or, [SourceCode.Workflow.CLient.WCField]::WorklistItemOwner, "Other", [SourceCode.Workflow.Client.WCCompare]::Equal, [SourceCode.Workflow.CLient.WCWorklistItemOwner]::Other);

$wl = $k2con.OpenWorklist($wlc);

Write-Host "Total amount of workitems: " $wl.TotalCount
if ( $wl.TotalCount -gt 0) {
    Write-Host 
    foreach ($wli in $wl) {
        write-host  $wli.ProcessInstance.ID, $wli.Data, $wli.AllocatedUser, $wli.Status
    }

}

$k2con.close()
