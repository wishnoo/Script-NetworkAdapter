
# Parameters for the script
[CmdletBinding()]
param (
    # Parameter help description
    [Parameter()]
    [string]
    $adapter_name,
    # Parameter help description
    [Parameter()]
    [switch]
    $enable_wakeonlan,
    [Parameter()]
    [switch]
    $disable_wakeonlan
)

# Script variables
parameterValidation $adapter_name
$adapter = selectAdapter $net_adapters
Write-Output "Adapter:" $adapter

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
        if ((-not $adapter_name) -and ($enable_wakeonlan -or $disable_wakeonlan)) {
            throw "ERROR - Required Parameter is empty. Required parameters are: adapter and one of the two (enable_wakeonlan and disable_wakeonlan)"
        }
    }
    catch {
        Write-Output "Error Inside parameterValidation Function"
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
        <# The interfacedescription_possible_array array is used to identify the keywords within the InterfaceDescription field of the net adapter,in this case we use Brand names to distinguish between them. This helps us in selecting the adapter. #>
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
function enableWakeOnMagicPacket {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $adapter
    )
    try {
        $wakeonmagicpacket_status = Get-NetAdapterPowerManagement -Name $adapter.Name | Select-Object -ExpandProperty "wakeonmagicpacket"
        Write-Output "Current wakeonmagicpacket status: " $wakeonmagicpacket_status

        if ($wakeonmagicpacket_status -ne "Enabled") {
            Enable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnMagicPacket
            Write-Output "WakeOnMagicPacket Setting was set"
        }
        else {
            Write-Output "WakeOnMagicPacket Setting was already set."
        }
    }
    catch {
        Write-Output "Error Inside enableWakeOnMagicPacket Function"
        Write-Output "$PSItem"
    }
}

function enableWakeOnPattern {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $adapter
    )

    try {
        $wakeonpattern_status = Get-NetAdapterPowerManagement -Name $adapter.Name | Select-Object -ExpandProperty "wakeonpattern"
        Write-Output "wakeonpattern_status: " $wakeonpattern_status

        if ($wakeonpattern_status -ne "Enabled") {
            Enable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnPattern
            Write-Output "WakeOnPattern Setting was set"
        }
        else {
            Write-Output "WakeOnPattern Setting was already set."
        }
    }
    catch {
        Write-Output "Error Inside enableWakeOnPattern Function"
        Write-Output "$PSItem"
    }
}

function enablePowerManagement {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $adapter
    )

    try {
        <# Note: When you use Get-CimInstance to get instance of the class MSNdis_DeviceWakeOnMagicPacketOnly we are unable to call Put method on the base class as it does not exist. Using Get-WMIObject we are able to call the put method and therfore making the change persistant. #>
        $pnp_deviceid = $adapter | Select-Object -ExpandProperty "PNPDeviceID"

        #-----> Allow the computer to turn off this device to save power

        Write-Host "Enable `"Allow the computer to turn off this device to save power`""
        $deviceenable_object = Get-WmiObject -class MSPower_DeviceEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "deviceenable status: $($deviceenable_object.Enable)"

        if ($deviceenable_object.Enable -ne $true) {
            $deviceenable_object.Enable = $true
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            $deviceenable_object.psbase.Put()
            Write-Output "Allow the computer to turn off this device to save power is now enabled"
        }
        else {
            Write-Output "Allow the computer to turn off this device to save power was already enabled"
        }

        #-----> Allow this device to wake the computer

        Write-Host "Enable `"Allow this device to wake the computer`""
        $devicewakeenable_object = Get-WmiObject -class MSPower_DeviceWakeEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "devicewakeenable status: $($devicewakeenable_object.Enable)"
        if ($devicewakeenable_object.Enable -ne $true) {
            $devicewakeenable_object.Enable = $true
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            $devicewakeenable_object.psbase.Put()
            Write-Output "Allow this device to wake the computer is now enabled"
        }
        else {
            Write-Output "Allow this device to wake the computer was already enabled"
        }

        #-----> Only allow a magic packet to wake the computer

        $devicewakeonmagicpacketonly_object = Get-WmiObject -class MSNdis_DeviceWakeOnMagicPacketOnly -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "devicewakeonmagicpacketonly status: $($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly)"
        if ($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly -ne $true) {
            $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly = $true
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            $devicewakeonmagicpacketonly_object.psbase.Put()
            Write-Output "Only allow a magic packet to wake the computer is now enabled"
        }
        else {
            Write-Output "Only allow a magic packet to wake the computer was already enabled"
        }
    }
    catch {
        Write-Output "Error Inside enablePowerManagement Function"
        Write-Output $PSItem.tostring()
    }
}

function disableWakeOnMagicPacket {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $adapter
    )
    try {
        $wakeonmagicpacket_status = Get-NetAdapterPowerManagement -Name $adapter.Name | Select-Object -ExpandProperty "wakeonmagicpacket"
        Write-Output "Current wakeonmagicpacket status: " $wakeonmagicpacket_status

        if ($wakeonmagicpacket_status -eq "Enabled") {
            Disable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnMagicPacket
            Write-Output "WakeOnMagicPacket Setting was disabled"
        }
        else {
            Write-Output "WakeOnMagicPacket Setting was already disabled."
        }
    }
    catch {
        Write-Output "Error Inside disableWakeOnMagicPacket Function"
        Write-Output "$PSItem"
    }
}

function disableWakeOnPattern {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $adapter
    )

    try {
        $wakeonpattern_status = Get-NetAdapterPowerManagement -Name $adapter.Name | Select-Object -ExpandProperty "wakeonpattern"
        Write-Output "wakeonpattern_status: " $wakeonpattern_status

        if ($wakeonpattern_status -eq "Enabled") {
            Disable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnPattern
            Write-Output "WakeOnPattern Setting was disabled"
        }
        else {
            Write-Output "WakeOnPattern Setting was already disabled."
        }
    }
    catch {
        Write-Output "Error Inside disableWakeOnPattern Function"
        Write-Output "$PSItem"
    }
}

function disablePowerManagement {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $adapter
    )

    try {
        <# Note: When you use Get-CimInstance to get instance of the class MSNdis_DeviceWakeOnMagicPacketOnly we are unable to call Put method on the base class as it does not exist. Using Get-WMIObject we are able to call the put method and therfore making the change persistant. #>
        $pnp_deviceid = $adapter | Select-Object -ExpandProperty "PNPDeviceID"

        #-----> Allow the computer to turn off this device to save power

        Write-Host "Disable `"Allow the computer to turn off this device to save power`""
        $deviceenable_object = Get-WmiObject -class MSPower_DeviceEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "deviceenable status: $($deviceenable_object.Enable)"

        if ($deviceenable_object.Enable -eq $true) {
            $deviceenable_object.Enable = $false
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            $deviceenable_object.psbase.Put()
            Write-Output "Allow the computer to turn off this device to save power is now disabled"
        }
        else {
            Write-Output "Allow the computer to turn off this device to save power was already disabled"
        }

        #-----> Allow this device to wake the computer

        Write-Host "Disable `"Allow this device to wake the computer`""
        $devicewakeenable_object = Get-WmiObject -class MSPower_DeviceWakeEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "devicewakeenable status: $($devicewakeenable_object.Enable)"
        if ($devicewakeenable_object.Enable -eq $true) {
            $devicewakeenable_object.Enable = $false
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            $devicewakeenable_object.psbase.Put()
            Write-Output "Allow this device to wake the computer is now disabled"
        }
        else {
            Write-Output "Allow this device to wake the computer was already disabled"
        }

        #-----> Only allow a magic packet to wake the computer

        $devicewakeonmagicpacketonly_object = Get-WmiObject -class MSNdis_DeviceWakeOnMagicPacketOnly -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "devicewakeonmagicpacketonly status: $($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly)"
        if ($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly -eq $true) {
            $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly = $false
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            $devicewakeonmagicpacketonly_object.psbase.Put()
            Write-Output "Only allow a magic packet to wake the computer is now disabled"
        }
        else {
            Write-Output "Only allow a magic packet to wake the computer was already disabled"
        }
    }
    catch {
        Write-Output "Error Inside disablePowerManagement Function"
        Write-Output $PSItem.tostring()
    }
}

if ($enable_wakeonlan -and $disable_wakeonlan) {
    Write-Output "You cannot enable and disable wakeonlan at the same time. Please provide one argument"
    exit
}
elseif ($enable_wakeonlan) {
    enableWakeOnMagicPacket -adapter $adapter
    enableWakeOnPattern -adapter $adapter
    enablePowerManagement -adapter $adapter
    Write-Output "Wake on lan settings were set."
}
else {
    disableWakeOnMagicPacket -adapter $adapter
    disableWakeOnPattern -adapter $adapter
    disablePowerManagement -adapter $adapter
    Write-Output "Wake on lan settings were disabled."
}



