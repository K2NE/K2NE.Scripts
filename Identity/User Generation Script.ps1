# Use at own risk :)
# Parameters set to work on Denallix VMs, and 'BulkUsers' OU will be created automatically. 
# For other environments adjust cmdlets parameters appropriately.

# Specify number of users and OUs to be created below
$Num_of_Users= 250
$Num_of_OU= 250

import-module ActiveDirectory
# Create target OU:
NEW-ADOrganizationalUnit “BulkUsers” –path “DC=DENALLIX,DC=COM”

# Begin users generation process
for ($ouCount=1;$ouCount -le $Num_of_OU; $ouCount++)  {
    $ouName = "BulkUsers" + $ouCount.ToString("0000")
    $lastGroup = "";
    New-ADOrganizationalUnit -Name $ouName -Path "OU=BulkUsers,DC=DENALLIX,DC=COM" -ProtectedFromAccidentalDeletion $false
    $ouPath = "OU="+$ouName+",OU=BulkUsers,DC=DENALLIX,DC=COM";
    Write-Host "Added OU " $ouName
    if ($ouCount % 10 -eq 0)
    {
        $groupName = "BulkGroup" + ($ouCount / 10).ToString("00");
        $groupDesc = "Group for OU " + $ouName;
        New-ADGroup -Name $groupName -DisplayName $groupName -Description $groupDesc -GroupScope Global -Path $ouPath
        Write-Host "Created new group " $groupName;
    } 
    for($userCount=1;$userCount -le $Num_of_Users; $userCount++) {
        $userName = "BulkUser." + $ouCount.ToString("0000") + "." + $userCount.ToString("0000");
        $userDisp = "Bulkuser "+$oucount +" " + $userCount;
        $userDesc = "User " + $userCount + " of the OU " + $ouName;
        $userPass = ConvertTo-SecureString -String "K2pass!" -AsPlainText -force
        
        New-ADUser -Name $userName -Description $userDesc -CannotChangePassword $true -DisplayName $userDisp -Enabled $true -PasswordNeverExpires $true -AccountPassword $userPass -Path $ouPath
        Write-host "Added new user " $userName;
        if ($lastGroup -ne "") {
            Add-ADGroupMember -Identity $groupName -Members $userName
        }
    }
}
