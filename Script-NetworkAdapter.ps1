
[CmdletBinding()]
param (
    # Parameter help description
    [Parameter()]
    [string]
    $adapter_name,
    # Parameter help description
    [Parameter()]
    [switch]
    $wake_up
)

$net_adapters = get-netadapter -name $adapter_name*

function parameterValidation {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $adapter_name
    )
    Write-Output "Start of parameterValidation Function"
    try {
        if (-not $adapter_name) {
            throw "ERROR - adapter_name is Empty and is a required parameter for this script"
        }
    }
    catch {
        Write-Output $_.tostring()
        exit
    }
    finally{
        Write-Output "End of parameterValidation Function"
    }
}

function selectAdapter {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $net_adapters
    )
    try {
        $interfacedescription_possible_array = ("Intel","Killer")
        foreach($adapter in $net_adapters){
            foreach($name in $interfacedescription_possible_array ){
                if (($adapter.InterfaceDescription -like "*$($name)*") -and ($adapter.Status -eq "Up") ) {
                    return $adapter
                }
            }
        }
        throw "Could Not find the proper adapter."
    }
    catch {
        Write-Output $PSItem.tostring()
    }
}
function setWakeOnMagicPacket {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $adapter,
        # Parameter help description
        [Parameter()]
        [switch]
        $wake_up
    )
    $wakeonmagicpacket_status = Get-NetAdapterPowerManagement -Name $adapter.Name | Select-Object -ExpandProperty "wakeonmagicpacket"
    Write-Output "wakeonmagicpacket_status: " $wakeonmagicpacket_status
    if (($wakeonmagicpacket_status -ne "Enabled") -and ($wake_up) ) {
        Enable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnMagicPacket
        Write-Output "WakeOnMagicPacket Setting was set"
    }
    else {
        Write-Output "WakeOnMagicPacket Setting was not set."
    }
}

function setWakeOnPattern {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $adapter,
        # Parameter help description
        [Parameter()]
        [switch]
        $wake_up
    )
    $wakeonpattern_status = Get-NetAdapterPowerManagement -Name $adapter.Name | Select-Object -ExpandProperty "wakeonpattern"
    Write-Output "wakeonpattern_status: " $wakeonpattern_status
    if (($wakeonpattern_status -ne "Enabled") -and ($wake_up) ) {
        Enable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnPattern
        Write-Output "WakeOnPattern Setting was set"
    }
    else {
        Write-Output "WakeOnPattern Setting was not set."
    }
}

function enablePowerManagement {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $adapter,
        # Parameter help description
        [Parameter()]
        [switch]
        $wake_up
    )

    try {
        #Enable Allow this device to wake the computer
        # Write-Host "Enable `"Allow this device to wake the computer`""
        $pnp_deviceid = $adapter | Select-Object -ExpandProperty "PNPDeviceID"
        <# When you use Get-CimInstance to get instance of the class MSNdis_DeviceWakeOnMagicPacketOnly we are unable to call Put method on the base class as it does not exist. Using Get-WMIObject we are able to call the put method and therfore making the change persistant. #>
        $devicewakeonmagicpacketonly_object = Get-WmiObject -class MSNdis_DeviceWakeOnMagicPacketOnly -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "devicewakeonmagicpacketonly status: $($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly)"
        if ($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly -ne $true -and $wake_up) {
            $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly = $true
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            $devicewakeonmagicpacketonly_object.psbase.Put()
            Write-Output "devicewakeonmagicpacketonly is set"
        }
        else {
            Write-Output "devicewakeonmagicpacketonly is already enabled"
        }
    }
    catch {
        Write-Output $PSItem.tostring()
    }
}

parameterValidation $adapter_name
$adapter = selectAdapter $net_adapters
Write-Output "Adapter:" $adapter
setWakeOnMagicPacket -adapter $adapter -wake_up
setWakeOnPattern -adapter $adapter -wake_up
enablePowerManagement -adapter $adapter -wake_up

