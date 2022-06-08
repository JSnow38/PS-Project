###Modify values of lines 4,7-9,12,15,18,and 21 for your network setup#####

#Domain/parent OU#
$MainOU= 'DC=adatum,DC=com'

#OU we will target to scan for accounts and devices that are not in compliance#
$TargetOU= @( 'OU=IT,DC=adatum,dc=com'
                'OU=Computers,DC-Adatum,dc=com'
                )
 
#OU for Disabled Users# 
$DisabledUsersOU = "OU=Disabled Users,DC=Adatum,DC=com"
 
#OU for Disabled Computers# 
$DisabledComputersOU = "OU=Disabled Computers,DC=Adatum,DC=com"
 
#Inactivity threshhold for Disabled - 30 days in my example# 
$InactivityDisable = (Get-Date) - (New-TimeSpan -Days 30)

#Inactivity threshhold for Delete - 60 days in my example# 
$InactivityDelete = (Get-Date) - (New-TimeSpan -Days 60)

###Verifying and/or Building the Disabled OUs###
if (Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$DisabledUsersOU'") { Write-Host "$DisabledUsersOU already exists."} else { New-ADOrganizationalUnit -Name "Disabled Users" -Path $MainOU -ProtectedFromAccidentalDeletion $false}

if ( Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$DisabledComputersOU'") { Write-Host "$DisabledComputersOU already exists."} else { New-ADOrganizationalUnit -Name "Disabled Computers" -Path $MainOU -ProtectedFromAccidentalDeletion $false}

###Searching for Users that meet criteria for disable, disabling, and moving to disabled OU###
$DisabledUsers = Search-ADAccount -searchbase 'OU=IT,DC=Adatum,DC=Com' -AccountInactive -TimeSpan $InactivityDisable -UsersOnly
foreach ($DisabledUser in $DisabledUsers){
    $sam=$DisabledUser.samaccountname
    $dn=$DisabledUser.distinguishedName

    if ($dn -notmatch $DisabledUsersOU){
        
        $DisabledUser|Disable-ADAccount         
         
        $DisabledUser| Move-ADObject -TargetPath $DisabledUsersOU
        Set-ADUser $sam -Description ("Moved from: " + $dn,"Due to Inactivity")
    }
}

###Searching for Computers that meet criteria for disable, disabling, and moving to disabled OU###
$DisabledComputers = Search-ADAccount -searchbase 'CN=Computers,DC=Adatum,DC=Com' -AccountInactive -TimeSpan $InactivityDisable -ComputersOnly
foreach ($DisabledComputer in $DisabledComputers){
    $sam=$DisabledComputer.samaccountname
    $dn=$DisabledComputer.distinguishedName

    if ($dn -notmatch $DisabledComputersOU){
         
        $DisabledComputer|Disable-ADAccount
         
        $DisabledComputer| Move-ADObject -TargetPath $DisabledComputersOU  
        Set-ADComputer $sam -Description ("Moved from: " + $dn,"Due to Inactivity")
    }
} 

###Searching for Users that meet criteria for deletion, copying that info to CSV file (CSV File is saved on the C:\) and then deleting the User account### 
$Path = Split-Path -Parent "C:\*.*"
$LogDate = Get-Date -f yyyyMMdd
$Csvfile = $Path + "\AllADUsersDeleted_$logDate.csv"
$DNs = $DisabledUsersOU

$AllADUsers = @()

foreach ($DN in $DNs) {
    $Users = Get-ADUser -SearchBase $DN -Filter * -Properties * 

        $AllADUsers += $Users
}

$AllADUsers | Sort-Object Name | Select-Object `
@{Label = "First name"; Expression = { $_.GivenName } },
@{Label = "Last name"; Expression = { $_.Surname } },
@{Label = "Display name"; Expression = { $_.DisplayName } },
@{Label = "User logon name"; Expression = { $_.SamAccountName } },
@{Label = "User principal name"; Expression = { $_.UserPrincipalName } },
@{Label = "Country/region"; Expression = { $_.Country } },
@{Label = "Job Title"; Expression = { $_.Title } },
@{Label = "Department"; Expression = { $_.Department } },
@{Label = "Company"; Expression = { $_.Company } },
@{Label = "Manager"; Expression = { % { (Get-AdUser $_.Manager -Properties DisplayName).DisplayName } } },
@{Label = "Description"; Expression = { $_.Description } },
@{Label = "Office"; Expression = { $_.Office } },
@{Label = "Telephone number"; Expression = { $_.telephoneNumber } },
@{Label = "E-mail"; Expression = { $_.Mail } },
@{Label = "Account status"; Expression = { if (($_.Enabled -eq 'TRUE') ) { 'Enabled' } Else { 'Disabled' } } },
@{Label = "Last logon date"; Expression = { $_.lastlogondate } }|

Export-Csv -Encoding UTF8 -Path $Csvfile -NoTypeInformation #-Delimiter ";"

Search-ADAccount -searchbase $DisabledUsersOU -AccountInactive -TimeSpan $InactivityDelete -UsersOnly | Remove-ADUser
        
         
###Searching for Computers that meet criteria for deletion, copying that info to CSV file (CSV File is saved on the C:\) for record and then deleting the Computer account###

$Path = Split-Path -Parent "C:\*.*"
$LogDate1 = Get-Date -f yyyyMMdd
$Csvfile1 = $Path + "\AllADComputersDeleted_$logDate1.csv"

$date = (Get-Date) - (New-TimeSpan -Days 60)
Get-ADcomputer -Filter 'lastLogondate -lt $date' | ft

Get-ADcomputer -Filter 'lastLogondate -lt $date' -properties canonicalName,lastlogondate | 
select name,canonicalname,lastlogondate | ft -AutoSize | Export-csv -Encoding UTF8 -Path $Csvfile1 -NoTypeInformation  #-Delimiter ";" 

Search-ADAccount -searchbase $DisabledcomputersOU -AccountInactive -TimeSpan $InactivityDelete -ComputersOnly | Remove-ADComputer