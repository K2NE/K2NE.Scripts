param([string]$K2Server = "localhost", [string]$K2ManagementPort = "5555")
[Reflection.Assembly]::LoadWithPartialName("SourceCode.Workflow.Management") | out-null

function Get-WorkflowManagementConnection([string]$K2ServerManagement, [string]$K2ServerPortManagement)
{
    begin
    {
        Write-Host "Getting Workflow.Management Connection"      
        $K2ServerManagementConn = New-Object SourceCode.Workflow.Management.WorkflowManagementServer($K2ServerManagement, $K2ServerPortManagement)
    }

    process
    {
        Write-Output $K2ServerManagementConn
    }
}

Write-Host "K2 Server Name: $K2Server"
Write-Host "K2 Port: $K2ManagementPort"

#Getting and opening a connection to the K2 Management Server
$ManagementConnection = Get-WorkflowManagementConnection $K2Server $K2ManagementPort
$ManagementConnection.Open()

$ProcInstances = $ManagementConnection.GetProcessInstancesAll("","","")

#First check that there are running instances
if($ProcInstances.Count -ne 0)
{
    foreach($element in $ProcInstances)
    {
        #Now ensure that the instances are not in error state (0) or already stopped (4)
        if($element.Status -ne 0 -and $element.Status -ne 4)
        {   
            $stopResult = $ManagementConnection.StopProcessInstances($element.ID)
            Write-Host "Process Instance ID:" $element.ID "stopped"
        }
        else
        {
            Write-Host "Process ID:" $element.ID "either stopped or in error state"
        }
    }
}
else
{
    Write-Host "There are currently no running instances"
}
Write-Host "Closing Workflow.Management Connection"
$ManagementConnection.Connection.Close()
Write-Host "Processing Complete"
