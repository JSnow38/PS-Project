New-VMSwitch ExternalSwitch -NetAdapterName Ethernet -AllowManagementOS $true
new-vm -name "SNO-DC1" -memorystartupbytes 2048mb -path "D:\school software"
New-VHD -path "d:\school software\SNO-DC1.vhdx" -sizebytes 20gb -dynamic
add-vmharddiskdrive -vmname "SNO-DC1" -path "d:\school software\SNO-DC1.vhdx"
set-vmdvddrive -vmname "SNO-DC1" -path "D:\Windows OSs\Server 2019 trial version.iso"
get-VMNetworkAdapter -VMName "SNO-DC1" | Connect-VMNetworkAdapter -Switchname ExternalSwitch 

start-vm -name "SNO-DC1"