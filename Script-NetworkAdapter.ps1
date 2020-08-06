
[CmdletBinding()]
param (
    # Parameter help description
    [Parameter()]
    [string]
    $adapter_name,
    # Parameter help description
    [Parameter(AttributeValues)]
    [switch]
    $wake_up
)

$net_adapters = get-netadapter -name $adapter_name*

function adapterValidation {
    param (
        # Parameter help description
        [Parameter()]
        $adapter
    )
    try {
        # if ($device_id.count -gt 1) {
        # throw "ERROR - Apdater resulted in multiple elements. Please provide more specific Adapter Name"
        # }
        $status = $adapter | where-object Status -eq up
        if (-not $status) {
            throw "ERROR - The status of Adapter is not Active"
        }
    }
    catch {
        Write-Output $_.tostring()
        exit
    }
}

function selectAdapter {
    param (
        # Parameter help description
        [Parameter()]
        $net_adapters
    )
    try {
        $interfacedescription_possible_map = ("Intel","Killer")
        foreach($adapter in $net_adapters){
            if ($adapter.InterfaceDescription -in $interfacedescription_possible_map) {
                return $adapter
            }
        }
        throw "Could Not find the proper adapter."
    }
    catch {
        Write-Output $PSItem.tostring()
    }
}

$adapter = selectAdapter $net_adapters
adapterValidation $adapter

$wakeonmagicpacket_status = Get-NetAdapterPowerManagement -Name $adapter.Name | Select-Object -ExpandProperty "wakeonmagicpacket"
# $device_wake = Get-CimInstance -ClassName MSPower_DeviceWakeEnable -Namespace root/wmi | where-object instancename -like "*$($device_id)*"

if (($wakeonmagicpacket_status -ne "Enabled") -and ($wake_up) ) {
    Enable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnMagicPacket
}

# $device_wake_enable = $device_wake.Enable

# if (!($device_wake_enable -and $wake_up)){
#     Set-CimInstance $device_wake -Property @{Enable=$wake_up}
# }

#Get-NetAdapterPowerManagement -Name "Ethernet" | select -ExpandProperty "wakeonmagicpacket"
#Enable-NetAdapterPowerManagement -Name "Ethernet" -WakeOnMagicPacket
