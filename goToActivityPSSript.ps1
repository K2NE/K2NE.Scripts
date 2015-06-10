[System.Console]::WriteLine("GoToActivity for K2 process instances")
$fromActivityName = "fromActivityName"
$toActivityName = "toActivityName"
$InstanceIDsPath = "InstanceIDs.txt"
$instanceIDsArray = gc $InstanceIDsPath
$count = 0  

cd "C:\Program Files (x86)\K2 blackpearl\Bin"
Add-Type -AssemblyName ("SourceCode.Workflow.Management, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d")
Add-Type -AssemblyName ("SourceCode.HostClientAPI, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d")
$wmserver = New-Object -TypeName SourceCode.Workflow.Management.WorkflowManagementServer
$constr = New-Object -TypeName SourceCode.Hosting.Client.BaseAPI.SCConnectionStringBuilder
$constr.IsPrimaryLogin = $true
$constr.Authenticate = $true
$constr.Integrated = $true
$constr.Host = "k2.denallix.com"
$constr.Port = 5555

$wmserver = New-Object -TypeName SourceCode.Workflow.Management.WorkflowManagementServer
$wmserver.CreateConnection()
$wmserver.Open($constr.ConnectionString)

foreach ($instanceID in $instanceIDsArray)
{ 
   $count += 1 
   
   $wmserver.GotoActivity($instanceID, $fromActivityName, $toActivityName) 

} 

$wmserver.Connection.Dispose()

[System.Console]::WriteLine("Instances count: "+$count)
[System.Console]::ReadLine()