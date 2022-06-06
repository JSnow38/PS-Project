#Our target OU to scan# 
$parentOU = 'DC=Adatum,DC=com' 
#OU for Disabled Users# 
$UsersOU = "OU=Disabled Users,DC=Enterprise,DC=com" 
#OU for Disabled Computers# 
$ComputersOU = "OU=Disabled Computers,DC=Enterprise,DC=com" 
#Inactivity threshhold - 90 days in my example# 
$Inactivity = "90.00:00:00"

#Creating Disabled Users OU if it don't exist# 
if (Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$UsersOU'") { Write-Host "$UsersOU already exists."} else { New-ADOrganizationalUnit -DisplayName "Disabled Users" -Path $parentOU}
#Creating Disabled Computers OU if it don't exist# 
if (Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$ComputersOU'") { Write-Host "$ComputersOU already exists."} else { New-ADOrganizationalUnit -DisplayName "Disabled Computers" -Path $parentOU}

$DisabledUsers = Search-ADAccount -AccountInactive -TimeSpan $Inactivity -UsersOnly
foreach ($DisabledUser in $DisabledUsers){
    $sam=$DisabledUser.samaccountname
    $dn=$DisabledUser.distinguishedName
#Checking whether account is already in Disabled
    if ($dn -notmatch $UsersOU){
        #Disabling User Accounts#
        $DisabledUser|Disable-ADAccount 
        #Moving Accounts to Disabled OU# 
        $DisabledUser| Move-ADObject -TargetPath $UsersOU 
        Set-ADUser $sam -Description ("Moved from: " + $dn,"Due to Inactivity")
    }
}


$DisabledComputers = Search-ADAccount -AccountInactive -TimeSpan $Inactivity -ComputersOnly
foreach ($DisabledComputer in $DisabledComputers){
    $sam=$DisabledComputer.samaccountname
    $dn=$DisabledComputer.distinguishedName
#Checking whether account is already in Disabled
    if ($dn -notmatch $ComputersOU){
        #Disabling Computer Accounts# 
        $DisabledComputer|Disable-ADAccount 
        #Moving Computer Accounts to Disabled OU# 
        $DisabledComputer| Move-ADObject -TargetPath $ComputersOU 
        Set-ADComputer $sam -Description ("Moved from: " + $dn,"Due to Inactivity")
    }
}
 