$SMONAME="Process_Instance"
$SMOMETHOD="List"
$INPUTPROPNAME="ProcessSetID"
$INPUTPROPVALUE=3
$LOOPAMOUNT= 5



Function GetK2InstallPath([string]$machine = $env:computername) {
    $registryKeyLocation = "SOFTWARE\SourceCode\BlackPearl\blackpearl Core\"
    $registryKeyName = "InstallDir"

	Write-Debug "Getting K2 install path from $machine "
    
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $machine)
    $regKey= $reg.OpenSubKey($registryKeyLocation)
    $installDir = $regKey.GetValue($registryKeyName)
    return $installDir
}

Function GetK2ConnectionString([string]$k2Server = "localhost", [int]$port = 5555) {
    Write-Debug "Creating connectionstring for machine '$k2Server' and port '$port'";
	Add-Type -AssemblyName ('SourceCode.HostClientAPI, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d')
		
    $connString = New-Object -TypeName "SourceCode.Hosting.Client.BaseAPI.SCConnectionStringBuilder";
    $connString.Integrated = $true;
    $connString.Authenticate = $true
    $connString.IsPrimaryLogin = $true;
    $connString.Host = $k2Server;
    $connString.Port = $port;

    return $connString.ConnectionString; 
}


$k2path = GetK2InstallPath
cd $k2path
Add-Type -AssemblyName ("SourceCode.SmartObjects.Client, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d")
Add-Type -AssemblyName ("SourceCode.HostClientAPI, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d")


for ($i=0;$i -lt $LOOPAMOUNT; $i++) {


    $smoServer = New-Object -TypeName SourceCode.SmartObjects.Client.SmartObjectClientServer
    $smoServer.CreateConnection()
    $connstr = GetK2ConnectionString
    $smoServer.Connection.Open($connstr)

    $smo = $smoServer.GetSmartObject($SMONAME)
    $smo.Properties[$INPUTPROPNAME].Value = $INPUTPROPVALUE
    $smo.MethodToExecute = $SMOMETHOD


    $smo2 = $smoServer.ExecuteList($smo)
    $amount = $smo2.SmartObjectsList.Count

    $smoServer.Connection.Close();
    $smoServer.Connection = $null;
    $smoServer = $null;




}