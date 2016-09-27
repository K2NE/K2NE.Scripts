param([string]$K2Server = "localhost", [string]$K2ManagementPort = "5555")

[Reflection.Assembly]::LoadWithPartialName("SourceCode.HostClientAPI") | out-null
[Reflection.Assembly]::LoadWithPartialName("SourceCode.SmartObjects.Client") | out-null



$builder = new-object SourceCode.Hosting.Client.BaseAPI.SCConnectionStringBuilder;
$builder.Authenticate = $true;
$builder.Host = "localhost";
$builder.Port = 5555;
$builder.Integrated = $true;
$builder.IsPrimaryLogin = $true;
$builder.SecurityLabelName = "K2";


$soServer = New-Object SourceCode.SmartObjects.Client.SmartObjectClientServer;
$soServer.CreateConnection() | out-null

$soServer.Connection.Open($builder.ConnectionString) | out-null;

$soServiceInstance = $soServer.GetSmartObject("SmartObjects_Management_ServiceInstance")
$soServiceInstance.MethodToExecute = "List"



$ServiceInstanceList = $soServer.ExecuteList($soServiceInstance)

foreach ($ServiceInstance in $ServiceInstanceList.SmartObjectsList)
    {
    write-host $ServiceInstance.Properties["DisplayName"].Value -ForegroundColor Green
    
    $ServiceTypeGuid = $ServiceInstance.Properties["ServiceInstanceGuid"].Value
    write-host "Guid:" $ServiceTypeGuid -ForegroundColor Cyan


            $soSettingKeyInfo = $soServer.GetSmartObject("SmartObjects_Services_Management_SettingKeyInfo")
            $soSettingKeyInfo.MethodToExecute = "List_Existing"
            $soSettingKeyInfo.Properties["ServiceInstanceGuid"].Value = $ServiceTypeGuid
            $SettingKeyInfos = $soServer.ExecuteList($soSettingKeyInfo)

            write-host "`t Settings:" -ForegroundColor Yellow

            foreach ($SettingKeyInfo in $SettingKeyInfos.SmartObjectsList)
            {
            write-host "`t -" $SettingKeyInfo.Properties["DisplayName"].Value": " -ForegroundColor Gray  -NoNewline 
            write-host $SettingKeyInfo.Properties["Value"].Value -ForegroundColor white
            }

    }
    
Write-Host "Press any key to continue ..."

$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
