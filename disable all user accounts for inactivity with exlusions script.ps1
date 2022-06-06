[CmdletBinding()]
param (
[Parameter( Mandatory=$false)]
[int]$TimeFrame = 30,


     [Parameter( Mandatory=$false)] 
     [string]$UpdateInformation = "Disabled due to inactivity", 
 
     [Parameter( Mandatory=$false)] 
     [switch]$Remediate, 
 
     [Parameter( Mandatory=$false)] 
     [string]$LogName = "LogFile.txt", 
 
     [Parameter( Mandatory=$false)] 
     [string]$ExclusionsPath = $null, ###<-- add path for account disabled exemptions here###
 
     [Parameter( Mandatory=$false)] 
     [string]$TriggeredPath = ".\triggered.csv" 
 ) 
$Date = Get-Date -Format "MM/dd/yyyy"
$LogDate = Get-Date -Format "yyyy MMM d - HH:mm:ss tt"
$myDir = Split-Path -Parent C:\$
$LogPath = "$myDir\$LogName"
$TriggeredPath = "$myDir\$TriggeredPath"
$Report = New-Object PSObject
$TriggeredUsers = @()
$Exclusions = Get-Content $ExclusionsPath


Import-Module ActiveDirectory


$Users = Get-ADUser -Properties LastLogonDate,SamAccountName -Filter {Enabled -eq $true}


Function Write-LogFile {
[CmdletBinding()]
param(
[Parameter( Position=0,Mandatory=$true)]
[string]$LogData
)
"$Date - $LogData" | Out-file -FilePath $LogPath -Append
}


foreach ($User in $Users) {
if ($Exclusions -notcontains $User.SamAccountName) {
if ($User.LastLogonDate -lt (Get-Date).AddDays(-$TimeFrame) -AND $User.LastLogonDate -ne $null) {
if ($Remediate) {
if ($UpdateInformation -ne $null) {
$Info = Get-ADUser $User.DistinguishedName -Properties info | Where-Object {$.info}
$Info += "`n $UpdateInformation - $Date"
try {
Set-ADUser -Replace @{info="$Info"} -ErrorAction Stop
Write-LogFile -LogData "Successfully set Info field for $($User.Name). New Info: $Info"
}
catch {
Write-LogFile -LogData "Error - Failed to set Info field for $($User.Name) - $"
}
}
try {
Disable-ADAccount -Identity $User.DistinguishedName -ErrorAction Stop
Write-LogFile -LogData "$($User.Name) successfully disabled"
}
catch {
Write-LogFile -LogData "Error - Failed to disable AD Account $($User.Name) - $_"
}
}
$TriggeredUsers += $User | Select Name,LastLogonDate,SamAccountName
}
}
}


$TriggeredUsers | Format-Table
$TriggeredUsers | Export-Csv $TriggeredPath -NoTypeInformation