#requires -version 4
<#
.SYNOPSIS
  This is a simple collection of powercli functions which improve on the built-in powercli functions.
  Primarily intended for collecting from vCenter but most things work when connected only to an ESX host.


.DESCRIPTION
  I've slowly tuned these functions over the years for my own use. Some properties were added from much older
  versions of PowerCLI. There may be more efficient ways of obtaining some properties with more recent versions
  of PowerCLI.

  Two primary goals.
  1) Provide more and relevant information on top of existing commands.
  2) Increase performance.

.NOTES
  Version:        1.0
  Author:         Matt S.
  Creation Date:  5/16/2017
  Website:        http://mjs.one
  Github:
  VMTools table:  https://packages.vmware.com/tools/versions

.TODO
 - allow pipe into get-vmB
 - find faster methods for slower functions(get-vmbhost for example)
   get-view may be faster in some cases

#>

###############################################################################
# Initialisations
###############################################################################

# Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

# Add VMware PowerCLI core module if not already loaded
if ("VMware.VimAutomation.Core" -notin $(Get-Module).name) {
    Import-Module VMware.VimAutomation.Core
}

# Ignore invalid cert - commented as configuring powercli is out of scope.
#Set-PowerCLIConfiguration -Scope User -InvalidCertificateAction Ignore -Confirm:$false


###############################################################################
# Make some of properties more accessable.
###############################################################################

# viproperty to get tools info
New-VIProperty -Name ToolsVersion       -ObjectType VirtualMachine -ValueFromExtensionProperty 'Config.tools.ToolsVersion' -Force
New-VIProperty -Name ToolsVersionStatus -ObjectType VirtualMachine -ValueFromExtensionProperty 'Guest.ToolsVersionStatus' -Force
New-VIProperty -Name ToolsRunningStatus -ObjectType VirtualMachine -ValueFromExtensionProperty 'Guest.ToolsRunningStatus' -Force
New-VIProperty -Name ToolsStatus        -ObjectType VirtualMachine -ValueFromExtensionProperty 'Guest.ToolsStatus' -Force
New-VIProperty -Name BootTime           -ObjectType VirtualMachine -ValueFromExtensionProperty 'Runtime.BootTime' -Force
New-VIProperty -Name hostname           -ObjectType VirtualMachine -ValueFromExtensionProperty 'Guest.HostName' -Force
New-VIProperty -name MemReserveMB       -ObjectType VirtualMachine -ValueFromExtensionProperty 'ResourceConfig.MemoryAllocation.Reservation' -Force
New-VIProperty -name MemLimit           -ObjectType VirtualMachine -ValueFromExtensionProperty 'ResourceConfig.MemoryAllocation.Limit' -Force
New-VIProperty -name cpuReserve         -ObjectType VirtualMachine -ValueFromExtensionProperty 'ResourceConfig.CpuAllocation.Reservation' -Force
New-VIProperty -name cpuLimit           -ObjectType VirtualMachine -ValueFromExtensionProperty 'ResourceConfig.CpuAllocation.Limit' -Force
New-VIProperty -name ip                 -ObjectType VirtualMachine -Value { $vm = $args[0];($vm.Guest.IPAddress | Select-String -NotMatch ":") -join ", " } -Force


###############################################################################
# Connect Function
###############################################################################

Function Connect-VMwareServer {
  Param ([Parameter(Mandatory = $true)][string]$VMServer)

  Try {
    $oCred = Get-Credential -Message 'Enter vCenter or ESXi credentials'
    Connect-VIServer -Server $VMServer -Credential $oCred
  }

  Catch {
    Break
  }
}

$Server = Read-Host 'Specify the vCenter Server or ESXi Host to connect to (IP or FQDN)?'
Connect-VMwareServer -VMServer $Server


###############################################################################
# Main Functions
###############################################################################


function get-vmB([Parameter(Mandatory = $true)][string]$VM_NAME) {
    <# 
    .SYNOPSIS
     better get-vm (single VM) 
     
    .PARAMETER s
        vmname
     
    .EXAMPLE
     $v = get-vmB "nameOfVM"
    #>

    $VMNAME = get-vm $VM_NAME

    if ($VMNAME.count -eq 1) { # this is required because get-vm may return multiple VMs if connected to multiple vCenters.
        $ds_name= $VMNAME | get-datastore | select name # lazy way of getting datastore. Should use $_.harddisks.
        $NetworkName= ($VMNAME | Get-NetworkAdapter).NetworkName
        $VMNAME | select Name, ip, hostname,version, ToolsStatus, ToolsVersion, ToolsVersionStatus, PowerState, BootTime, numcpu, MemoryMB, VMHost, Notes, Folder,`
        @{n="UsedSpaceGB";e={"{0:N2}" -f $_.UsedSpaceGB}},`
        @{n="ProvisionedSpaceGB";e={"{0:N2}" -f $_.ProvisionedSpaceGB}},`
        @{n="cluster";e={$_.vmhost.parent.name}},`
        @{n="datastore";e={$ds_name.name}},`
        @{n="vcenter";e={($_.Client.ServerUri.Split("@"))[1]}},`
        @{n="NetworkName";e={$NetworkName}},`
        @{n="GuestFullName";e={$_.ExtensionData.Config.GuestFullName}}
    }
    else {
        $out = @()
        foreach ($vm in $VMNAME){
            $ds_name= $vm | get-datastore | select name
            $NetworkName= ($VMNAME | Get-NetworkAdapter).NetworkName
            $out += $vm| select Name, ip, hostname,version, ToolsStatus, ToolsVersion, ToolsVersionStatus, PowerState, BootTime, numcpu, MemoryMB, VMHost, Notes, Folder,`
            @{n="UsedSpaceGB";e={"{0:N2}" -f $_.UsedSpaceGB}},`
            @{n="ProvisionedSpaceGB";e={"{0:N2}" -f $_.ProvisionedSpaceGB}},`
            @{n="cluster";e={$_.vmhost.parent.name}},`
            @{n="datastore";e={$ds_name.name}},`
            @{n="vcenter";e={($_.Client.ServerUri.Split("@"))[1]}},`
            @{n="NetworkName";e={$NetworkName}},`
            @{n="GuestFullName";e={$_.ExtensionData.Config.GuestFullName}}
        }
        $out
    }
}


function get-vmBall {
    <# 
    .SYNOPSIS
      better get-vm (all powered on vms in currently connected vcenter)

    .DESCRIPTION
     
     
    .PARAMETER 
     
     
    .EXAMPLE
     $allvms = get-vmBall
     
    #>
    get-vm | where {$_.powerstate -eq "poweredOn"} | select Name, ip, hostname, ToolsStatus, PowerState, BootTime, numcpu, MemoryMB, VMHost, Notes, Folder, `
        @{n="UsedSpaceGB";e={"{0:N2}" -f $_.UsedSpaceGB}},`
        @{n="ProvisionedSpaceGB";e={"{0:N2}" -f $_.ProvisionedSpaceGB}},`
        @{n="cluster";e={$_.vmhost.parent.name}},`
        @{n="datastore";e={$_.ExtensionData.Config.DatastoreUrl.name}},`
        @{n="vcenter";e={($_.Client.ServerUri.Split("@"))[1]}},`
        @{n="GuestFullName";e={$_.ExtensionData.Config.GuestFullName}},`
        @{n="GuestFamily";e={$_.Guest.GuestFamily}}
}


function get-vmBds([Parameter(Mandatory = $true)][string]$DATASTORE_NAME) {
    <# 
    .SYNOPSIS
      better get-vm (all vms in specific datastore)

    .DESCRIPTION
     
    .PARAMETER s
      datastore name
     
    .EXAMPLE
     $vms = get-vmBds "datastore1"

     $vms = @()
     $(get-datastore | ? type -eq "NFS") | % {$vms += get-vmBds $_.name}

    #>

    #foreach ($ds in $(get-datastore | ? type -eq "NFS")) {

    $sd= Get-Datastore -Name $DATASTORE_NAME
    $s = $sd | get-vm
    $s | select Name, ip, hostname, ToolsStatus, PowerState, BootTime, numcpu, MemoryMB, VMHost, `
    @{n="UsedSpaceGB";e={"{0:N2}" -f $_.UsedSpaceGB}},`
    @{n="ProvisionedSpaceGB";e={"{0:N2}" -f $_.ProvisionedSpaceGB}},`
    @{n="cluster";e={$_.vmhost.parent.name}},`
    @{n="datastore";e={$sd.Name}},`
    @{n="vcenter";e={($_.Client.ServerUri.Split("@"))[1]}},`
    @{n="datastore_ip";e={$sd.RemoteHost}},`
    @{n="datastore_path";e={$sd.RemotePath}},`
    @{n="GuestFullName";e={$_.ExtensionData.Config.GuestFullName}},`
    @{n="GuestFamily";e={$_.Guest.GuestFamily}}
}


function get-vmBhot ([Parameter(Mandatory = $true)][string]$VM_NAME) {
    <# 
    .SYNOPSIS
      better get-vm (+is hotadd cpu/mem enabled?)

    .DESCRIPTION
      Similar to get-vmB but checks for hotadd capabilities.
     
    .PARAMETER s
       vmname
     
    .EXAMPLE
      $vm = get-vmBhot "vmname"
     
    #>
    $s = get-vm $VM_NAME
    $sd= $s | get-datastore
    $s | select Name, ip, hostname, ToolsStatus, version, PowerState, BootTime, numcpu, MemoryMB, VMHost, Notes, Folder,`
    @{n="UsedSpaceGB";e={"{0:N2}" -f $_.UsedSpaceGB}},`
    @{n="ProvisionedSpaceGB";e={"{0:N2}" -f $_.ProvisionedSpaceGB}},`
    @{n="cluster";e={$_.vmhost.parent.name}},`
    @{n="datastore";e={$sd.Name}},`
    @{n="vcenter";e={($_.Client.ServerUri.Split("@"))[1]}},`
    @{n="GuestFullName";e={$_.ExtensionData.Config.GuestFullName}},`
    @{n="CpuHotAddEnabled";e={$_.ExtensionData.config.CpuHotAddEnabled}},`
    @{n="MemoryHotAddEnabled";e={$_.ExtensionData.config.MemoryHotAddEnabled}}
}


function get-vmBhost ([Parameter(Mandatory = $true)][string]$ESX_HOST) {
    <# 
    .SYNOPSIS
      better get-vmhost | get-vm

    .DESCRIPTION
      all VMs running on specific host.
     
    .PARAMETER s
      esx hostname
     
    .EXAMPLE
      $hst = get-vmBhost esxhostname
    #>
    
    # $s = $(get-view -ViewType HostSystem -Filter @{"Name" = "$ESX_HOST"} -Property vm).vm | Get-VIObjectByVIView
    # ^^^ thought this would be faster but apparently not.
    $s = Get-VMHost $ESX_HOST | get-vm
    if ($s.count -eq 1) {
        $sd= $s | get-datastore | select name
        $s | select Name, ip, hostname,version, ToolsStatus, ToolsVersion, ToolsVersionStatus, PowerState, BootTime, numcpu, MemoryMB, VMHost, Notes, Folder,`
        @{n="UsedSpaceGB";e={"{0:N2}" -f $_.UsedSpaceGB}},`
        @{n="ProvisionedSpaceGB";e={"{0:N2}" -f $_.ProvisionedSpaceGB}},`
        @{n="cluster";e={$_.vmhost.parent.name}},`
        @{n="datastore";e={$sd.name}},`
        @{n="vcenter";e={($_.Client.ServerUri.Split("@"))[1]}},`
        @{n="GuestFullName";e={$_.ExtensionData.Config.GuestFullName}}
    }
    else {
        $out = @()
        foreach ($vm in $s){
            $sd= $vm | get-datastore | select name
            $out += $vm| select Name, ip, hostname,version, ToolsStatus, ToolsVersion, ToolsVersionStatus, PowerState, BootTime, numcpu, MemoryMB, VMHost, Notes, Folder,`
            @{n="UsedSpaceGB";e={"{0:N2}" -f $_.UsedSpaceGB}},`
            @{n="ProvisionedSpaceGB";e={"{0:N2}" -f $_.ProvisionedSpaceGB}},`
            @{n="cluster";e={$_.vmhost.parent.name}},`
            @{n="datastore";e={$sd.name}},`
            @{n="vcenter";e={($_.Client.ServerUri.Split("@"))[1]}},`
            @{n="GuestFullName";e={$_.ExtensionData.Config.GuestFullName}}
        }
        $out
    }
        
}


function get-vmBresourceAll {
    <# 
    .SYNOPSIS
      better get-vm with cpu+memory resources - All VMs

    .DESCRIPTION
     
     
    .PARAMETER
     
     
    .EXAMPLE
     $vmall = get-vmBresourceAll
     
    #>
    get-vm | where {$_.powerstate -eq "poweredOn"} | select Name, ip, hostname, ToolsStatus, version, PowerState, BootTime, numcpu, MemoryMB, VMHost, Notes, Folder,`
    @{n="UsedSpaceGB";e={"{0:N2}" -f $_.UsedSpaceGB}},`
    @{n="ProvisionedSpaceGB";e={"{0:N2}" -f $_.ProvisionedSpaceGB}},`
    @{n="cluster";e={$_.vmhost.parent.name}},`
    @{n="vcenter";e={($_.Client.ServerUri.Split("@"))[1]}},`
    @{n="GuestFullName";e={$_.ExtensionData.Config.GuestFullName}},`
    @{n="CpuHotAddEnabled";e={$_.ExtensionData.config.CpuHotAddEnabled}},`
    @{n="MemoryHotAddEnabled";e={$_.ExtensionData.config.MemoryHotAddEnabled}},`
    MemReserveMB,MemLimit,cpuReserve,cpuLimit
}
