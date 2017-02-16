<#
.SYNOPSIS
    Find users from AD and resolves them in K2, and using PoshRSJob, does multiple users at once.  Thus, speeding up the process drastically.

    The PoshRSJob module can be downloaded here - https://github.com/proxb/PoshRSJob

    Limitations: 
    - Only resolves users.
    - Needs to be run on the K2 server with an account that has DB access
    - Due to the nature of PoshRSJob, variables need to replaced in multiple places in the script
    - Replace port 5555 with other as needed
        
    Name:    ResolveUsersMultipe[.ps1]
    Author:  Mark Wilbert
    Created: [19.01.2017]
    Company: K2NE 
	Technolog(y/ies): K2, PoshRSJob
    Version: 1.0
	
.PARAMETER adFilterQuery
    [required]
	The filter to find users for the ldap query
.PARAMETER SQLServer
    The K2 host DB server
.PARAMETER SQLDBName
    [required]
	The K2 DB Server
.PARAMETER poshRSJobModulePath
    [required]
	The path to import the PoshRSJob module from
.PARAMETER LDAPpath
    [required]
	The ldap paths to search for users

.EXAMPLE
    ResolveUsersMultiple    
	Calls the script with all mandatory parameters
.DESCRIPTION
    1.0   // MRW // Creation-Date // Init
#> 

param(
[string]$adFilterQuery = "(&(objectClass=user)(whenCreated>=20120817000000.0Z)(!(objectClass=computer))(!(useraccountcontrol:1.2.840.113556.1.4.803:=2)))",
[string]$SQLServer = "K2dbServer" ,
[string]$SQLDBName = "K2",
[string]$poshRSJobModulePath = "N:\MyFiles\PoshRSJob", # Can be downloeded here https://github.com/proxb/PoshRSJob
$LDAPpaths = @(
    "LDAP://DC=EUROPE,DC=DENALLIX,DC=COM",
    "LDAP://DC=ASIA,DC=DENALLIX,DC=COM",
    "LDAP://DC=US,DC=DENALLIX,DC=COM"
)
)

# Search for users in the given LDAP path
Function SearchUsers{
    Param($ldapPath)

    $dirEntry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
    $searcher = New-Object System.DirectoryServices.DirectorySearcher($dirEntry)
	
    $searcher.Filter = $adFilterQuery
    $searcher.PageSize = 1000;
    $searcher.SearchScope = "Subtree"
    $searcher.all
    $searcher.PropertiesToLoad.Add("sAMAccountName") | Out-Null
    $searcher.PropertiesToLoad.Add("objectClass") | Out-Null
    $searcher.PropertiesToLoad.Add("msDS-PrincipalName") | Out-Null

    $searchResult = $searcher.FindAll()

    $queryResutls = @()

    foreach ($result in $searchResult) {

        $queryResutls += (@{"logonName" = $result.Properties["msds-principalname"];
                            "class" = $result.Properties["objectClass"];
                          "fqn" = ("K2:" + $result.Properties["msds-principalname"] ) });
    }

    $searchResult.Dispose()
    $searcher.Dispose()
    $dirEntry.Dispose()

    return $queryResutls

}

# Looks to see if the user is already resolved in K2
Function isUserResolved{
    param([string]$userIDforSQL)

    [string]$userFQN = $userIDforSQL;
    $SqlQuery = "select [Resolved] from [Identity].[Identity] where FQN = '$userFQN'"

    #Write-Debug $SqlQuery
 
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = $SQLServer; Database = $SQLDBName; Integrated Security = True"
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $SqlQuery
    $SqlCmd.Connection = $SqlConnection
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
    $DataSet = New-Object System.Data.DataSet
    $SqlAdapter.Fill($DataSet) | Out-Null
    $SqlConnection.Close()
    if ($DataSet.Tables[0].rows.count -gt 0)
       { 
            if($DataSet.Tables[0].Rows[0].Resolved -eq $true){
                return $true
            }
            else
                {return $false}
       }
    else
        {return $false}
}

# A self-contained function to resolve users in K2
# All references are loaded in the function to support use through posh RSJob
# Replace Host and Port of the K2 server as needed
Function ResolveUserClean{
	Param( $user)
	
    Add-Type -AssemblyName ("SourceCode.Security.UserRoleManager.Management, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d")
    Add-Type -AssemblyName ("SourceCode.HostClientAPI, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d")

    $constr = New-Object -TypeName SourceCode.Hosting.Client.BaseAPI.SCConnectionStringBuilder
	$constr.IsPrimaryLogin = $true
	$constr.Authenticate = $true
	$constr.Integrated = $true
	$constr.Host = "localhost"
	$constr.Port = "5555"

    $urm = New-Object SourceCode.Security.UserRoleManager.Management.UserRoleManager
    $urm.CreateConnection() | Out-Null
    $urm.Connection.Open($constr) | Out-Null
    

	$fqn = New-Object -TypeName SourceCode.Hosting.Server.Interfaces.FQName -ArgumentList $user
	$urm.ResolveIdentity($fqn, [SourceCode.Hosting.Server.Interfaces.IdentityType]::User, [SourceCode.Hosting.Server.Interfaces.IdentitySection]::Identity)
	$urm.ResolveIdentity($fqn, [SourceCode.Hosting.Server.Interfaces.IdentityType]::User, [SourceCode.Hosting.Server.Interfaces.IdentitySection]::Members)
    $urm.ResolveIdentity($fqn, [SourceCode.Hosting.Server.Interfaces.IdentityType]::User, [SourceCode.Hosting.Server.Interfaces.IdentitySection]::Containers)

    $urm.Connection.Close()
}


### <Process flow> ###
$sw = [Diagnostics.Stopwatch]::StartNew()

Write-Host "Starting K2 ResolveUser script."


$usersToResolve = @()
$resolvedUsers = @()
$otherObjects = @()
$objectsAllConfiguredDomains = @()



# Execute the LDAP Query for each domain
foreach($path in $LDAPpaths){
    $objectsAllConfiguredDomains += SearchUsers($path) 
}

# Seperate Users, groups, throw out everything else
# This loop should be taylored to your specific AD needs, as likely too many accounts will be caught
# Example, admin users accounts, or dummy accounts
foreach ($ADobject in $objectsAllConfiguredDomains) {
    if($ADObject -ne $null ) {
	    if ($ADObject -ne $null -and 
            $ADobject.class.Contains("user") -eq $true -and
            $ADobject.class.Contains("computer") -eq $false ) {
                
                $isResolved = isUserResolved($ADobject.fqn)

                if($isResolved -eq $false){
                    $usersToResolve += $ADobject.fqn
                    Write-Debug "$($sw.ElapsedMilliseconds)ms: Adding $ADobject to list of users to resolve."
                }
                else{
                    $resolvedUsers += $ADobject.fqn
                }
        } 
        else {
            Write-Debug "$($sw.ElapsedMilliseconds)ms: Skipping $($objResult.Path) - Not a User/Group ObjectClass"
            $otherObjects += $ADobject
        }
    }
    else{
    $otherObjects += $ADobject
    }
}



#Done - Get K2 AD LDAP Strings from DB

Write-Host "Found $($usersToResolve.Count) users to resolve. Found $($groupsToResolve.Count) groups to resolve. Time used until now: $($sw.ElapsedMilliseconds)ms."
Write-Debug "$($sw.ElapsedMilliseconds)ms: Cleaning up AD resources..."


Import-Module -Name N:\PS-scripts\PoshRSJob
$usersToResolve | Start-RSJob -Name {$_} -ScriptBlock { ResolveUserClean( $_)} -FunctionsToLoad ResolveUserClean -Throttle 15

Write-Host "K2 ResolveUser script completed in $($sw.ElapsedMilliseconds)ms. Use Get-RSJob to check the status of the jobs created"

### <End Process flow> ###
 