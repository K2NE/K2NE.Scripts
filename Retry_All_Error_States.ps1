param([string]$K2Server = "localhost", [string]$K2ManagementPort = "5555")
[Reflection.Assembly]::LoadWithPartialName("SourceCode.Workflow.Management") | out-null
Add-Type -AssemblyName ('SourceCode.Workflow.Client, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d')

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

$K2ServerManagementConn = New-Object SourceCode.Workflow.Management.WorkflowManagementServer($K2Server, $K2ManagementPort)
$K2ServerManagementConn.Open()

$ErrorProfile = $K2ServerManagementConn.GetErrorProfile("All")
$ErrorLogs = $K2ServerManagementConn.GetErrorLogs($ErrorProfile.ID)

# List all Process Instances in Error State (view only mode) with Folio and ErrorDate
function show-errors()
{

    foreach ($ErrorLog in $ErrorLogs)
    {
    write-host "Folio: `t`t" $ErrorLog.Folio -ForegroundColor Green
    write-host "ErrorDate: `t" $ErrorLog.ErrorDate
    write-host ""

    }

}

#Retry all Process Instances in Error State 
function retry-errors()
{
    foreach ($ErrorLog in $ErrorLogs)
    {
    $K2ServerManagementConn.RetryError($ErrorLog.ProcInstID, $ErrorLog.ID, $currentUser)
    write-host "Retried Folio:" $ErrorLog.Folio -ForegroundColor Green
    }
}

#Ask User for Mode ('View only' or 'Retry All')
$choice = ""
while ($choice -notmatch "[show|retry]"){
    $choice = read-host "Choose your mode? (show/retry)"
    }

if ($choice -eq "show"){
    write-host "Show all Instances in Error State" -ForegroundColor Yellow
    show-errors
    }

if ($choice -eq "retry"){
   write-host "Retry all Instances in Error State" -ForegroundColor Yellow
   retry-errors
}
    
