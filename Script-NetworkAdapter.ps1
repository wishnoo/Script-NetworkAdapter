
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
    $disable_wakeonlan,
    [Parameter()]
    [switch]
    $disablefaststartup
)
# This makes all non terminating errors stop
$ErrorActionPreference = 'Stop'
function parameterValidation {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter()]
        $adapter_name
    )
    try {
        Write-Output "STARTFUNCTION: parameterValidation"
        if ((-not $adapter_name) -or (-not ($enable_wakeonlan -or $disable_wakeonlan))) {
            throw "ERROR - Required Parameter is empty. Required parameters are: adapter and one of the two (enable_wakeonlan and disable_wakeonlan)"
        }
        Write-Output "SUCCESS: Input parameters are validated successfully."
    }
    catch {
        Write-Output "ERROR: Function - parameterValidation"
        Write-Output $_.tostring()
        exit
    }
    finally{
        Write-Output "ENDFUNCTION: parameterValidation"
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
        Write-Output "STARTFUNCTION: selectAdapter"
        <# The interfacedescription_possible_array array is used to identify the keywords within the InterfaceDescription field of the net adapter,in this case we use Brand names to distinguish between them. This helps us in selecting the adapter. #>
        $interfacedescription_possible_array = ("Intel","Killer")
        foreach($adapter in $net_adapters){
            foreach($name in $interfacedescription_possible_array ){
                if (($adapter.InterfaceDescription -like "*$($name)*") -and ($adapter.Status -eq "Up") ) {
                    return $adapter
                }
            }
        }
        throw "ERROR: Could Not find the proper adapter."
    }
    catch {
        Write-Output "ERROR: Function - selectAdapter"
        Write-Output $PSItem.tostring()
        exit
    }
    finally{
        Write-Output "ENDFUNCTION: selectAdapter"
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
        Write-Output "STARTFUNCTION: enableWakeOnMagicPacket"
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
        Write-Output "ERROR: Function - enableWakeOnMagicPacket"
        Write-Output "$PSItem"
    }
    finally{
        Write-Output "ENDFUNCTION: enableWakeOnMagicPacket"
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
        Write-Output "STARTFUNCTION: enableWakeOnPattern"
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
        Write-Output "ERROR Function - enableWakeOnPattern"
        Write-Output "$PSItem"
    }
    finally{
        Write-Output "ENDFUNCTION: enableWakeOnPattern"
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
        Write-Output "STARTFUNCTION: enablePowerManagement"
        <# Note: When you use Get-CimInstance to get instance of the class MSNdis_DeviceWakeOnMagicPacketOnly we are unable to call Put method on the base class as it does not exist. Using Get-WMIObject we are able to call the put method and therfore making the change persistant. #>
        $pnp_deviceid = $adapter | Select-Object -ExpandProperty "PNPDeviceID"

        #-----> Allow the computer to turn off this device to save power

        Write-Host "Enable `"Allow the computer to turn off this device to save power`""
        $deviceenable_object = Get-WmiObject -class MSPower_DeviceEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "deviceenable status: $($deviceenable_object.Enable)"
        if (-not ([bool]($deviceenable_object -match "Enable"))) {
            Write-Output "`"Allow the computer to turn off this device to save power`" option is not available"
        }
        elseif ($deviceenable_object.Enable -ne $true) {
            $deviceenable_object.Enable = $true
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            # void is used to eliminate the output from the statement
            [void] $deviceenable_object.psbase.Put()
            Write-Output "Allow the computer to turn off this device to save power is now enabled"
        }
        else {
            Write-Output "Allow the computer to turn off this device to save power was already enabled"
        }

        #-----> Allow this device to wake the computer

        Write-Host "Enable `"Allow this device to wake the computer`""
        $devicewakeenable_object = Get-WmiObject -class MSPower_DeviceWakeEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "devicewakeenable status: $($devicewakeenable_object.Enable)"
        if (-not ([bool]($devicewakeenable_object -match "Enable"))) {
            Write-Output "`"Allow this device to wake the computer`" option is not available"
        }
        elseif ($devicewakeenable_object.Enable -ne $true) {
            $devicewakeenable_object.Enable = $true
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            [void] $devicewakeenable_object.psbase.Put()
            Write-Output "Allow this device to wake the computer is now enabled"
        }
        else {
            Write-Output "Allow this device to wake the computer was already enabled"
        }

        #-----> Only allow a magic packet to wake the computer

        $devicewakeonmagicpacketonly_object = Get-WmiObject -class MSNdis_DeviceWakeOnMagicPacketOnly -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "devicewakeonmagicpacketonly status: $($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly)"
        if (-not ([bool]($devicewakeonmagicpacketonly_object -match "EnableWakeOnMagicPacketOnly"))) {
            Write-Output "`"Only allow a magic packet to wake the computer`" option is not available"
        }
        elseif ($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly -ne $true) {
            $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly = $true
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            [void] $devicewakeonmagicpacketonly_object.psbase.Put()
            Write-Output "Only allow a magic packet to wake the computer is now enabled"
        }
        else {
            Write-Output "Only allow a magic packet to wake the computer was already enabled"
        }
    }
    catch {
        Write-Output "ERROR: Function - enablePowerManagement"
        Write-Output $PSItem.tostring()
    }
    finally{
        Write-Output "ENDFUNCTION: enablePowerManagement"
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
        Write-Output "STARTFUNCTION: disableWakeOnMagicPacket"
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
        Write-Output "ERROR: Function - disableWakeOnMagicPacket"
        Write-Output "$PSItem"
    }
    finally{
        Write-Output "ENDFUNCTION: disableWakeOnMagicPacket"
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
        Write-Output "STARTFUNCTION: disableWakeOnPattern"
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
        Write-Output "ERROR: Function - disableWakeOnPattern"
        Write-Output "$PSItem"
    }
    finally{
        Write-Output "ENDFUNCTION: disableWakeOnPattern"
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
        Write-Output "STARTFUNCTION: disablePowerManagement"
        <# Note: When you use Get-CimInstance to get instance of the class MSNdis_DeviceWakeOnMagicPacketOnly we are unable to call Put method on the base class as it does not exist. Using Get-WMIObject we are able to call the put method and therfore making the change persistant. #>
        $pnp_deviceid = $adapter | Select-Object -ExpandProperty "PNPDeviceID"

        #-----> Allow the computer to turn off this device to save power

        Write-Host "Disable `"Allow the computer to turn off this device to save power`""
        $deviceenable_object = Get-WmiObject -class MSPower_DeviceEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "deviceenable status: $($deviceenable_object.Enable)"

        if (-not ([bool]($deviceenable_object -match "Enable"))) {
            Write-Output "`"Allow the computer to turn off this device to save power`" option is not available"
        }
        elseif ($deviceenable_object.Enable -eq $true) {
            $deviceenable_object.Enable = $false
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            # void is used to eliminate the output from the statement
            [void] $deviceenable_object.psbase.Put()
            Write-Output "Allow the computer to turn off this device to save power is now disabled"
        }
        else {
            Write-Output "Allow the computer to turn off this device to save power was already disabled"
        }

        #-----> Allow this device to wake the computer

        Write-Host "Disable `"Allow this device to wake the computer`""
        $devicewakeenable_object = Get-WmiObject -class MSPower_DeviceWakeEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "devicewakeenable status: $($devicewakeenable_object.Enable)"
        if (-not ([bool]($devicewakeonmagicpacketonly_object -match "EnableWakeOnMagicPacketOnly"))) {
            Write-Output "`"Only allow a magic packet to wake the computer`" option is not available"
        }
        elseif ($devicewakeenable_object.Enable -eq $true) {
            $devicewakeenable_object.Enable = $false
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            [void] $devicewakeenable_object.psbase.Put()
            Write-Output "Allow this device to wake the computer is now disabled"
        }
        else {
            Write-Output "Allow this device to wake the computer was already disabled"
        }

        #-----> Only allow a magic packet to wake the computer

        $devicewakeonmagicpacketonly_object = Get-WmiObject -class MSNdis_DeviceWakeOnMagicPacketOnly -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        Write-Output "devicewakeonmagicpacketonly status: $($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly)"
        if (-not ([bool]($devicewakeonmagicpacketonly_object -match "EnableWakeOnMagicPacketOnly"))) {
            Write-Output "`"Only allow a magic packet to wake the computer`" option is not available"
        }
        elseif ($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly -eq $true) {
            $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly = $false
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            [void] $devicewakeonmagicpacketonly_object.psbase.Put()
            Write-Output "Only allow a magic packet to wake the computer is now disabled"
        }
        else {
            Write-Output "Only allow a magic packet to wake the computer was already disabled"
        }
    }
    catch {
        Write-Output "ERROR Function - disablePowerManagement"
        Write-Output $PSItem.tostring()
    }
    finally{
        Write-Output "ENDFUNCTION: disablePowerManagement"
    }
}

function disableHiberbootEnabledRegistry {
    try {
        # When the registry key HiberbootEnabled is set to 0 (disabled) Fast startup gets disabled.
        Write-Output "STARTFUNCTION: disableHiberbootEnabledRegistry"

        # local variables
        $registry_path = "hklm:\SYSTEM\CurrentControlSet\Control\Session?Manager\Power"
        $name = "HiberbootEnabled"
        $value = 0

        # Check whether registry path exists.
        if (!(Test-Path $registry_path)) {
            throw "ERROR: Registry Path doesn't exist"
        }
        $FindHiberbootEnabled = Get-ItemProperty "hklm:\SYSTEM\CurrentControlSet\Control\Session?Manager\Power"
        # This checks if HiberbootEnabled is equal to 1.
        If ($FindHiberbootEnabled.HiberbootEnabled -eq 1)
        {
            write-output "HiberbootEnabled is Enabled. Setting to DISABLED..."
            Set-ItemProperty -Path $FindHiberbootEnabled.PSPath -Name $name -Value $value -Type DWORD -Force
        }
        Else
        {
            write-output "HiberbootEnabled is already DISABLED"
        }
    }
    catch {
        Write-Output "ERROR: Function - disableHiberbootEnabledRegistry"
        Write-Output $PSItem.tostring()
    }
    finally{
        Write-Output "ENDFUNCTION: disableHiberbootEnabledRegistry"
    }
}

try {
    # Script variables
    parameterValidation $adapter_name
    $net_adapters = get-netadapter -name $adapter_name*

    $adapter = selectAdapter $net_adapters
    Write-Output "Selected Adapter:" $adapter

    # Main procedure for the script
    if ($enable_wakeonlan -and $disable_wakeonlan) {
        Write-Output "You cannot enable and disable wakeonlan at the same time. Please provide one argument"
        exit
    }
    elseif ($enable_wakeonlan) {
        enableWakeOnMagicPacket -adapter $adapter
        enableWakeOnPattern -adapter $adapter
        enablePowerManagement -adapter $adapter
        Write-Output "SUCCESS: Wake on lan settings were set."
    }
    else {
        disableWakeOnMagicPacket -adapter $adapter
        disableWakeOnPattern -adapter $adapter
        disablePowerManagement -adapter $adapter
        Write-Output "SUCCESS: Wake on lan settings were disabled."
    }

    # Check if disablefaststartup switch is present and if present execute accourdingly.
    if ($disablefaststartup) {
        disableHiberbootEnabledRegistry
    }

}
catch {
    Write-Output "ERROR: Main Block"
}



