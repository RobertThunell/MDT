#####################################################################
# Create a virtual machine for each line of a specified csv file
# Author: Robert Thunell
# Email: Robert.Thunell@Qbranch.se
# Please modify and run in test lab before moving to production*
#
# CSV format:
# VMHost 		Name		Datastore			DiskGB		DiskStorageFormat		MemoryGB		NumCpu		GuestId					Role1					EnableDHCP		AdapterCount		IPAddress		Subnet			Gateway			DNS							AdapterName		DNSSuffix
# 192.168.0.10	CoolSRV05	LocalDatastore01	40			Thin					4				1			windows8Server64Guest	Desktop, Laptop, Server	False, True		1					192.168.0.65	255.255.255.0	192.168.0.254	192.168.0.61,192.168.0.254 	Coolsite LAN	coolsite.local
#
# $VM.VMHost	$VM.Name	$VM.Datastore		$VM.DiskGB	$VM.DiskStorageFormat	$VM.MemoryGB	$VM.NumCpu	$VM.GuestId				$VM.Role1				$VM.EnableDHCP	$VM.AdapterCount	$VM.IPAddress	$VM.Subnet		$VM.Gateway		$VM.DNS						$VM.AdapterName	$VM.DNSSuffix
#
# parameters:
# -filename to input list of vms to create 
# Example:
#.\CreateVM.ps1 -filename CreateVM.csv
#
# Example:
#.\CreateVM.ps1 .\CreateVM.csv
#
#####################################################################

param(
    [parameter(Mandatory = $true)]
    [string[]]$filename
    )

$VMs = Import-CSV $filename -UseCulture

#Region Load Modules
Set-ExecutionPolicy Unrestricted
if (!(Get-Module MDTDB))
{
Import-Module \\coolsrv03\d$\MDTDB\MDTDB.psm1
}

if (!(Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue))
{
Add-PSSnapin VMware.VimAutomation.Core
}

#End Load Modules

#Region Constants
[string]$VCentreHost = "192.168.0.50"
[string]$ESXHost = "192.168.0.10"
#EndConstants

#Region Initialise

# Connect to the VSphere host, using appropriate credentials, the following
# are the defaults for a VSphere 5 appliance
Connect-VIServer -Server $VCentreHost -User root -Password 180Grain
#Connect-VIServer -Server $ESXHost -User root -Password 180Grain

Connect-MDTDatabase �sqlServer coolsrv03.coolsite.local �database MDT -ErrorAction Stop
#End Initialise

 ForEach($VM in $VMs){

#    $ClusterHost = Get-Cluster $VM.Cluster | Get-VMHost | Where {$_.ConnectionState -eq "Connected"} | Get-Random
    
#    New-vm -VMhost $ClusterHost -Name $VM.VMName -ResourcePool (Get-cluster $VM.Cluster | Get-ResourcePool $VM.ResourcePool) -Location $VM.Location -Datastore $VM.Datastore -Template $VM.Template -Description $VM.Description -DiskStorageFormat "Thin"

	New-VM -VMHost $VM.VMHost -Name $VM.Name -Datastore $VM.Datastore -DiskGB $VM.DiskGB -DiskStorageFormat $VM.DiskStorageFormat -MemoryGB $VM.MemoryGB -NumCpu $VM.NumCpu -GuestId $VM.GuestId 
	
	$Role1 = $VM.Role1
	$EnableDHCP = $VM.EnableDHCP
	$AdapterCount=$VM.AdapterCount
	$IPadress = $VM.IPAddress
	$Subnet=$VM.Subnet;
	$Gateway=$VM.Gateway;
	$DNS=$VM.DNS;
	$AdapterName=$VM.AdapterName;
	$DNSSuffix=$VM.DNSSuffix;

	$adapter= Get-NetworkAdapter -VM $VM.Name
		Remove-NetworkAdapter -NetworkAdapter $adapter -confirm:$false
		$VM = Get-VM $VM.Name
			New-NetworkAdapter -VM $vm -NetworkName "VM Network" -Type "vmxnet3" -StartConnected
			$scsiController = Get-HardDisk -VM $VM.Name | Select -First 1 | Get-ScsiController
		Set-ScsiController -ScsiController $scsiController -Type VirtualLsiLogicSAS

$nicmac=Get-NetworkAdapter -VM $VM | ForEach-Object {$_.MacAddress}

New-MDTComputer -macAddress $nicmac.toUpper() -settings @{

	OSInstall='YES';
	ComputerName=$VM.Name;
	Fullname=$VM.Name;
	OSDComputerName=$VM.Name;
	OSDAdapter0EnableDHCP=$EnableDHCP;
	OSDAdapterCount=$AdapterCount
	OSDAdapter0MacAddress=$nicmac.toUpper()
	OSDAdapter0IPAddressList=$IPadress;
	OSDAdapter0SubnetMask=$Subnet;
	OSDAdapter0Gateways=$Gateway;
	OSDAdapter0DNSServerList=$DNS;
	OSDAdapter0Name=$AdapterName;
	OSDAdapter0DNSSuffix=$DNSSuffix;
}

get-mdtcomputer -macAddress $nicmac.toUpper() | Set-MDTComputerRole -roles $Role1

#Start the machine
$startMachine = Read-Host "Start"$VM"? Type [Y]ES or [N]O"
if ($startMachine.toUpper() -eq "Y")
	{
		$vm = Get-VM $VM.Name
		$vm | Start-VM -Confirm:$false
	} #Close If
}