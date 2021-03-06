<#
   .SYNOPSIS 
   Simple script to check if services are running and warm-up IIS

   .DESCRIPTION
   Stripped down version of the K2 Core VM's startup script. Only checks services, warms up IIS and starts services that needed to auto-start.
   
   .PARAMETER ConfigName
   Specifies the configuration section to use.  The section marked as default=true will be used if this parameter is left blank.

   .PARAMETER log
   Specifies the path to the log file to write. Will not write to a file if omitted.

   .INPUTS
   None. You cannot pipe objects to Startup.ps1.

   .OUTPUTS
   Log. Statup.ps1 generates information to console and StartupTransaction.log for all commands executed.

   .EXAMPLE
   C:\PS> .\Startup.ps1

   .EXAMPLE
   C:\PS> .\Startup.ps1 -ConfigName "Core"

   .EXAMPLE
   C:\PS> .\Startup.ps1 -log ./log/warmup.log

#>

param(
    [Parameter(Mandatory=$False)]
    [string]$ConfigName = "Core",

    [Parameter(Mandatory=$False)]
    [string]$log
);

# Disable Execution Policy
Set-ExecutionPolicy Unrestricted

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False, Position=0)]
        [string]
        $Message,

        [Parameter(Mandatory=$False)]
        [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory=$False)]
        [string]
        $logfile = $log
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss.ff")
    $Line = "$Stamp $Level $Message"
    If($logfile) {
        Add-Content $logfile -Value $Line
    }
    Write-Output $Message
}

# use try/catch to make sure we report a Ready state even if the scripts fail for some reason
try
{
    if($log) {Write-Log "* Starting warmup script * * * * * * * * * * * * * * * * * * * * * * * "}

    # Load Config
    [xml]$configs = Get-Content ./StartupConfig.xml

    # Load configuration by name
    $config = $configs.startupConfigurations.configuration | Where-Object {$_.name -eq $ConfigName }
    if($config -eq $null)
    {
        # Try again, but load configuration by default flag
        $config = $configs.startupConfigurations.configuration | Where-Object {$_.default -eq $true}
        if($config -eq $null)
        {
            Write-Log "Configuration for $configName not available." -level "WARN"
            Write-Log "Processing will stop." -level "WARN"
            Break
        }
    }
    # Build up the configuration section variables
    $serviceStatus = $config.serviceStatus
    $urls = $config.urls
    $ignoreService = $config.ignoreServiceAutostart

    
    # Need to see if the requested services are Running before continuing
    if($serviceStatus)
    {
	    Write-Host ""
	    Write-Log "---- Waiting for Services Startup ----"
	    foreach($status in $serviceStatus.status)
	    {
		    $serviceCheck = Get-Service -DisplayName $status.displayName
		    Write-Log "Checking $($serviceCheck.DisplayName) is $($status.status)"
            $counter=0		
            while(($serviceCheck.Status -ne $status.status) -and $counter -lt 20)
		    {
			    Write-Host -nonewline "."
			    Start-Sleep 1
			    $serviceCheck = Get-Service -DisplayName $status.displayName
                $counter++
		    }
		    Write-Log "$($serviceCheck.DisplayName) is $($serviceCheck.Status)"
	    }
        Write-Log "All required services have started."
    }

    Write-Host ""
    Write-Log "---- Warming up App Pools ----"
    Import-Module -Name WebAdministration 
    dir 'iis:\AppPools' -ErrorAction SilentlyContinue | foreach {
        $path = "IIS:\AppPools\" + $_.Name
        Start-WebItem $path
        Write-Log ("Application pool `"" + $_.Name + "`" started")
    } 

    if($urls)
    {
	    Write-Host ""
	    Write-Log "---- Warming up URLs ----"
	    foreach($url in $urls.url)
	    {
		    if($url.enabled -eq $true)
		    {
			    Write-Log "Warming up $($url.category) at URL $($url.path)"
                # ErrorAction doesn't work for this commandlet so use try/catch
                try
                {
                    Invoke-RestMethod -Uri $url.path -UseDefaultCredentials | Out-Null
                    Write-Log "Warm up URL $($url.path) completed."
                }
                catch
                {
                    Write-Log "ERROR: $_" -level "ERROR"
                }
		    }
	    }
    }

    # Make sure all services set to start Auto are started
    Write-Host ""
    Write-Log "---- Checking Services set to Auto start ----"
    $autoServices = gwmi win32_service -filter "startmode = 'auto' AND state != 'running'" 
    Write-Log "Found $($autoServices.Count) stopped services"
    foreach($autoService in $autoServices)
    {
        if($ignoreService)
        {
            $ignore = $ignoreService.service | Where-Object {$_.displayName -eq $autoService.DisplayName}
            if( $ignore )
            {
                Write-Log ("Skipping " + $autoService.DisplayName)
                continue
            }
        }
	    # See if service is "Stopping" first and if so lets just kill it and try again
	    if($autoService.Status -eq "Stopping")
	    {
		    Stop-Process -ProcessName $autoService.Name -Force
	    }
	    # Try to start the service.  Wait 20 seconds max
	    Write-Log "Starting $($autoService.DisplayName)"
	    Start-Service $autoService.Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        # | Out-Null
	    $autoService = Get-Service -Name $autoService.Name
	    $counter = 0
	    while(($autoService.Status -ne "Running") -and ($counter -lt 20))
	    {
		    Write-Host -nonewline "."
		    $autoService.Refresh();
		    Start-Sleep 1
		    $counter++
	    }
        if($counter -gt 0){Write-Log ""}
        Write-Log "$($autoService.DisplayName) is $($autoService.Status)"
    }
    Write-Host ""
    Write-Log "The system has been warmed up successfully."

}
catch
{
    [System.Exception]
    Write-Log "System Exception Occurred: $($Error)" -level "ERROR"
}
finally
{
   
}
