###Modify values of lines 4,7-10,13,16,19,and 22 for your network setup#####

#Domain/parent OU#
$MainOU= 'DC=adatum,DC=com'


$TargetOU = @("OU=IT,DC=Adatum,DC=com",
           "OU=Sales,DC=Adatum,DC=Com",
            "OU=Research,DC=Adatum,DC=Com",
            "OU=Development,DC=Adatum,DC=Com")
 
#OU for Disabled Users# 
$DisabledUsersOU = "OU=Disabled Users,DC=Adatum,DC=com"
 
#OU for Disabled Computers# 
$DisabledComputersOU = "OU=Disabled Computers,DC=Adatum,DC=com"
 
#Inactivity threshhold for Disabled - 30 days in my example# 
$DisableDate = "30.00:00:00"

#Inactivity threshhold for Delete - 60 days in my example# 
$deletedate = "60.00:00:00"

###Verifying and/or Building the Disabled OUs###
if (Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$DisabledUsersOU'") { Write-Host "$DisabledUsersOU already exists."} else { New-ADOrganizationalUnit -Name "Disabled Users" -Path $MainOU -ProtectedFromAccidentalDeletion $false}

if ( Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$DisabledComputersOU'") { Write-Host "$DisabledComputersOU already exists."} else { New-ADOrganizationalUnit -Name "Disabled Computers" -Path $MainOU -ProtectedFromAccidentalDeletion $false}

###Searching for Users that meet criteria for disable, disabling, and moving to disabled OU###
$DisabledUsers = Foreach($OU in $TargetOU){
Search-ADAccount -Searchbase $OU –AccountInActive –TimeSpan $DisableDate -UsersOnly}

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
$DisabledComputers = Search-ADAccount -Searchbase "CN=Computers,DC=Adatum,DC=com" –AccountInActive –TimeSpan $DisableDate -ComputersOnly 
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
$DUs = $DisabledUsersOU

$AllADUsers = @()

foreach ($DN in $DUs) {
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

Search-ADAccount -Searchbase "$DUs" –AccountInActive –TimeSpan $deletedate -UsersOnly| Remove-ADUser
        
         
###Searching for Computers that meet criteria for deletion, copying that info to CSV file (CSV File is saved on the C:\) for record and then deleting the Computer account###

$Path = Split-Path -Parent "C:\*.*"
$LogDate1 = Get-Date -f yyyyMMdd
$Csvfile1 = $Path + "\AllADComputersDeleted_$logDate1.csv"
$DCs = $DisabledComputersOU


$AllADComputers = @()

foreach ($DC in $DCs) {
    $Computers = Get-ADComputer -SearchBase $DCs -Filter * -Properties * 

        $AllADComputers += $Computers
        }

$AllADComputers | Sort-Object Name | Select-Object `
@{Label = "Computer Name"; Expression = { $_.Name } },
@{Label = "Last Logon Date"; Expression = { $_.lastlogondate } },
@{Label = "DNS Host Name"; Expression = { $_.DNSHostName } },
@{Label = "Operating System"; Expression = { $_.OperatingSystem } },
@{Label = "Operating System Version"; Expression = { $_.OperatingSystemVersion } } |

Export-csv -Encoding UTF8 -Path $Csvfile1 -NoTypeInformation  #-Delimiter ";" 

Search-ADAccount -Searchbase "$DCs" –AccountInActive –TimeSpan $deletedate -ComputersOnly | Remove-ADComputer