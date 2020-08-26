
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
    $enable_faststartup,
    [Parameter()]
    [switch]
    $disable_faststartup,
    [Parameter()]
    [string] $logFileNamePrefix="WakeOnLan" #Default value is WakeOnLan - prefix to the log file
)
# This makes all non terminating errors stop
$ErrorActionPreference = 'Stop'

<#
currentFolderPath - Name of the path where the executable reside relative to path of the console.
#>
$currentFolderPath = Split-Path $script:MyInvocation.MyCommand.Path
$currentFolderPath += '\'

<#
compname - Current local computer name where the script is executed.
#>
$compName = $env:COMPUTERNAME

<#
Array to store the property objects
#>
$propertyArray = @()

<#
Delete any text files in the current folder
#>
if (Get-ChildItem -Path $currentFolderPath*.txt) {
    remove-item $currentFolderPath*.txt
}

<#
Log function to output to verbose stream as well as log into file
#>
function Submit-Log {
    [cmdletbinding()]
    param (
        [string]$text,
        $errorRecord
    )

    try {
        Write-Verbose "STARTFUNCTION: Submit-Log"
         # Prepend time with text using get-date and .tostring method
        $Entry = (Get-Date).ToString( 'M/d/yyyy HH:mm:ss - ' ) + $text

        #  Write entry to log file
        $Entry | Out-File -FilePath $logFilePath -Encoding UTF8 -Append

        #  Write entry to screen
        Write-Verbose -Message $Entry -Verbose

        #  If error record included
        #   Recurse to capture exception details
        If ( $errorRecord -is [System.Management.Automation.ErrorRecord] )
        {
            Submit-Log -Text "Exception.Message [$($errorRecord.Exception.Message)]"
            Submit-Log -Text "Exception.GetType() [$($errorRecord.Exception.GetType())]"
            Submit-Log -Text "Exception.InnerException.Message [$($errorRecord.Exception.InnerException.Message)]"
        }
    }
    catch {
        <#
        Exeption Handling - Catch block for the function Submit-Log
        #>
        if ($logFilePath) {
            $outputFilename = "$($logFileNamePrefix)_$($compName)_ERROR.txt"
            $logFilePath_new = $currentFolderPath + $outputFilename
            Rename-Item -Path "$($logFilePath)" -NewName "$($logFilePath_new)" -Force
        }
        $outputFilename = "$($logFileNamePrefix)_$($compName)_ERROR.txt"
        $script:logFilePath = $currentFolderPath + $outputFilename
        Submit-Log -text "New LogFilePath : $($logFilePath)"
        Submit-Log -text "Error: Function - Submit-Log. Possible Error in creation of file." -errorRecord $_
        exit
        # TODO: Rethink this catch block.
    }
    finally{
        Write-Verbose "ENDFUNCTION: Submit-Log"
    }
}

<#
Initialize the logfile name and have option to retrive errorfile path , errorfile name, successfile path and successfile name.
Also verify if logFileNamePrefix is available or not.
Handle other errors.
#>
function LogFileName {
    [cmdletbinding()]
    param (
        [switch] $errorFlag,
        [switch] $successFlag
        )
    try {
        Write-Verbose "LogFileName function started" -Verbose

        $fileNamePathObject = New-Object -TypeName psobject
        if ($errorFlag) {
            $outputFilename = "$($logFileNamePrefix)_$($compName)_ERROR.txt"
            $logFilePath = $currentFolderPath + $outputFilename
        }
        elseif ($successFlag) {
            $outputFilename = "$($logFileNamePrefix)_$($compName)_SUCCESS.txt"
            $logFilePath = $currentFolderPath + $outputFilename
        }
        else {
            $outputFilename = "$($logFileNamePrefix)_$($compName).txt"
            $logFilePath = $currentFolderPath + $outputFilename
        }

        $fileNamePathObject | Add-Member -MemberType NoteProperty -Name Name -Value $outputFilename
        $fileNamePathObject | Add-Member -MemberType NoteProperty -Name Path -Value $logFilePath
        return $fileNamePathObject
    }
    catch {
        <#
        Exeption Handling - Catch block for the function LogFileName
        #>
        if ($logFilePath) {
            $outputFilename = "$($logFileNamePrefix)_$($compName)_ERROR.txt"
            $logFilePath_new = $currentFolderPath + $outputFilename
            Rename-Item -Path "$($logFilePath)" -NewName "$($logFilePath_new)" -Force
        }
        $outputFilename = "$($logFileNamePrefix)_$($compName)_ERROR.txt"
        $script:logFilePath = $currentFolderPath + $outputFilename
        Submit-Log -text "New LogFilePath : $($logFilePath)"
        Submit-Log -text "ERROR: Function - logfilename" -errorRecord $_
        exit
    }
}

<#
Submit-Error Function aggregates the step when an error is encountered.
#>
function Submit-Error {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String] $text,
        $errorRecord
    )
    try {
        <#
        Change the logFilePath even if the logFilePath is empty.
        #>
        $fileObject = logFileName  -errorFlag
        if ($logFilePath) {
            Rename-Item -Path "$($logFilePath)" -NewName "$($fileObject.Name)" -Force
        }

        $script:logFilePath = $fileObject.Path

        if ($text) {
            Submit-Log -text "$($text)"
        }
        If ( $errorRecord -is [System.Management.Automation.ErrorRecord] )
        {
            Submit-Log -Text "Exception.Message [$($errorRecord.Exception.Message)]"
            Submit-Log -Text "Exception.GetType() [$($errorRecord.Exception.GetType())]"
            Submit-Log -Text "Exception.InnerException.Message [$($errorRecord.Exception.InnerException.Message)]"
        }

        Submit-Log -text "New LogFilePath : $($logFilePath)"
    }
    catch {
        Submit-Log -text "ERROR - execution of Submit-Error Function" -errorRecord $_
        # Submit-Error
        # TODO: Create an alternative of Submit-Error in this catch block.
        exit
    }
}

function Set-Property {
    [CmdletBinding()]
    param (
        [Parameter()]
        $property,
        $previousValue,
        $currentValue
    )
    $propertyItem = [PSCustomObject]@{
        "Property" = $property
        "Previous Value" = $previousValue
        "Current Value" = $currentValue
    }
    $script:propertyArray += $propertyItem
}
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
        Submit-Log -text "STARTFUNCTION: enableWakeOnMagicPacket"
        # $wakeonmagicpacket_status = Get-NetAdapterPowerManagement -Name $adapter.Name | Select-Object -ExpandProperty "wakeonmagicpacket"
        $wakeonmagicpacket_object = Get-NetAdapterPowerManagement -Name $adapter.Name
        $wakeonmagicpacket_status = $wakeonmagicpacket_object.WakeOnMagicPacket
        Submit-Log -text "STATUS: wakeonmagicpacket - $($wakeonmagicpacket_status)"

        if ($wakeonmagicpacket_status -ne "Enabled") {
            Enable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnMagicPacket
            Submit-Log -text "WakeOnMagicPacket Setting was set"
        }
        else {
            Submit-Log -text "WakeOnMagicPacket Setting was already set."
        }

        # create a new object to get the updated value.
        $wakeonmagicpacket_object = Get-NetAdapterPowerManagement -Name $adapter.Name
        Set-Property -property "WakeOnMagicPacket" -previousValue "$($wakeonmagicpacket_status)" -currentValue "$($wakeonmagicpacket_object.WakeOnMagicPacket)"

    }
    catch {
        Submit-Error -text "ERROR: Function - enableWakeOnMagicPacket" -errorRecord $PSItem
    }
    finally{
        Submit-Log -text "ENDFUNCTION: enableWakeOnMagicPacket"
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
        Submit-Log "STARTFUNCTION: enableWakeOnPattern"
        # $wakeonpattern_status = Get-NetAdapterPowerManagement -Name $adapter.Name | Select-Object -ExpandProperty "wakeonpattern"
        $wakeonpattern_object = Get-NetAdapterPowerManagement -Name $adapter.Name
        $wakeonpattern_status = $wakeonpattern_object.WakeOnPattern
        Submit-Log "STATUS: wakeonpattern - $($wakeonpattern_status)"

        if ($wakeonpattern_status -ne "Enabled") {
            Enable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnPattern
            Submit-Log "WakeOnPattern Setting was set"
        }
        else {
            Submit-Log "WakeOnPattern Setting was already set."
        }
        # create a new object to get the updated value.
        $wakeonpattern_object = Get-NetAdapterPowerManagement -Name $adapter.Name
        Set-Property -property "WakeOnPattern" -previousValue "$($wakeonpattern_status)" -currentValue "$($wakeonpattern_object.WakeOnPattern)"
    }
    catch {
        Submit-Error "ERROR Function - enableWakeOnPattern" -errorRecord $PSItem
    }
    finally{
        Submit-Log "ENDFUNCTION: enableWakeOnPattern"
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
        Submit-Log "STARTFUNCTION: enablePowerManagement"
        <# Note: When you use Get-CimInstance to get instance of the class MSNdis_DeviceWakeOnMagicPacketOnly we are unable to call Put method on the base class as it does not exist. Using Get-WMIObject we are able to call the put method and therfore making the change persistant. #>
        # $pnp_deviceid = $adapter | Select-Object -ExpandProperty "PnPDeviceID"
        $pnp_deviceid = $adapter.PnPDeviceID
        $set_value = ""

        #-----> Allow the computer to turn off this device to save power

        Submit-Log "Enable `"Allow the computer to turn off this device to save power`""
        $deviceenable_object = Get-WmiObject -class MSPower_DeviceEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        $deviceenable_status = $deviceenable_object.Enable
        Submit-Log "STATUS: deviceenable status - $($deviceenable_status)"
        if (-not ($deviceenable_object.PSObject.Properties.Match("Enable").count)) {
            Submit-Log "`"Allow the computer to turn off this device to save power`" option is not available"
            $set_value = "Unavailable"
        }
        elseif ($deviceenable_object.Enable -ne $true) {
            $deviceenable_object.Enable = $true
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            # void is used to eliminate the output from the statement
            [void] $deviceenable_object.psbase.Put()
            Submit-Log "Allow the computer to turn off this device to save power is now enabled"
            $set_value = $deviceenable_object.Enable
        }
        else {
            Submit-Log "Allow the computer to turn off this device to save power was already enabled"
            $set_value = $deviceenable_object.Enable
        }

        Set-Property -property "Turn Off Device To Save Power" -previousValue "$($deviceenable_status)" -currentValue "$($set_value)"

        #-----> Allow this device to wake the computer
        Submit-Log "Enable `"Allow this device to wake the computer`""
        $devicewakeenable_object = Get-WmiObject -class MSPower_DeviceWakeEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        $devicewakeenable_status = $devicewakeenable_object.Enable
        Submit-Log "STATUS: devicewakeenable status - $($devicewakeenable_status)"
        # if (-not ([bool]($devicewakeenable_object -match "Enable"))) {
        if (-not ($devicewakeenable_object.PSObject.Properties.Match("Enable").count)) {
            Submit-Log "`"Allow this device to wake the computer`" option is not available"
            $set_value = "Unavailable"
        }
        elseif ($devicewakeenable_object.Enable -ne $true) {
            $devicewakeenable_object.Enable = $true
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            [void] $devicewakeenable_object.psbase.Put()
            Submit-Log "Allow this device to wake the computer is now enabled"
            $set_value = $devicewakeenable_object.Enable
        }
        else {
            Submit-Log "Allow this device to wake the computer was already enabled"
            $set_value = $devicewakeenable_object.Enable
        }

        Set-Property -property "Wake up the computer" -previousValue "$($devicewakeenable_status)" -currentValue "$($set_value)"

        #-----> Only allow a magic packet to wake the computer

        $devicewakeonmagicpacketonly_object = Get-WmiObject -class MSNdis_DeviceWakeOnMagicPacketOnly -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        $devicewakeonmagicpacketonly_status = $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly
        Submit-Log "STATUS: devicewakeonmagicpacketonly status - $($devicewakeonmagicpacketonly_status)"
        if (-not ($devicewakeonmagicpacketonly_object.PSObject.Properties.Match("EnableWakeOnMagicPacketOnly").count)) {
            Submit-Log "`"Only allow a magic packet to wake the computer`" option is not available"
            $set_value = "Unavailable"
        }
        elseif ($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly -ne $true) {
            $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly = $true
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            [void] $devicewakeonmagicpacketonly_object.psbase.Put()
            Submit-Log "Only allow a magic packet to wake the computer is now enabled"
            $set_value = $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly
        }
        else {
            Submit-Log "Only allow a magic packet to wake the computer was already enabled"
            $set_value = $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly
        }

        Set-Property -property "Only allow magic packect" -previousValue "$($devicewakeonmagicpacketonly_status)" -currentValue "$($set_value)"
    }
    catch {
        Submit-Error "ERROR: Function - enablePowerManagement" -errorRecord $PSItem
    }
    finally{
        Submit-Log "ENDFUNCTION: enablePowerManagement"
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
        Submit-Log "STARTFUNCTION: disableWakeOnMagicPacket"
        $wakeonmagicpacket_object = Get-NetAdapterPowerManagement -Name $adapter.Name
        $wakeonmagicpacket_status = $wakeonmagicpacket_object.WakeOnMagicPacket
        Submit-Log "STATUS: Current wakeonmagicpacket - $($wakeonmagicpacket_status)"

        if ($wakeonmagicpacket_status -eq "Enabled") {
            Disable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnMagicPacket
            Submit-Log "WakeOnMagicPacket Setting was disabled"
        }
        else {
            Submit-Log "WakeOnMagicPacket Setting was already disabled."
        }

        # create a new object to get the updated value.
        $wakeonmagicpacket_object = Get-NetAdapterPowerManagement -Name $adapter.Name
        Set-Property -property "WakeOnMagicPacket" -previousValue "$($wakeonmagicpacket_status)" -currentValue "$($wakeonmagicpacket_object.WakeOnMagicPacket)"
    }
    catch {
        Submit-Error -text "ERROR: Function - disableWakeOnMagicPacket" -errorRecord $PSItem
    }
    finally{
        Submit-Log "ENDFUNCTION: disableWakeOnMagicPacket"
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
        Submit-Log "STARTFUNCTION: disableWakeOnPattern"
        $wakeonpattern_object = Get-NetAdapterPowerManagement -Name $adapter.Name
        $wakeonpattern_status = $wakeonpattern_object.WakeOnPattern
        Submit-Log "STATUS: wakeonpattern - $($wakeonpattern_status)"

        if ($wakeonpattern_status -eq "Enabled") {
            Disable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnPattern
            Submit-Log "WakeOnPattern Setting was disabled"
        }
        else {
            Submit-Log "WakeOnPattern Setting was already disabled."
        }

        # create a new object to get the updated value.
        $wakeonpattern_object = Get-NetAdapterPowerManagement -Name $adapter.Name
        Set-Property -property "WakeOnPattern" -previousValue "$($wakeonpattern_status)" -currentValue "$($wakeonpattern_object.WakeOnPattern)"
    }
    catch {
        Submit-Error -text "ERROR: Function - disableWakeOnPattern" -errorRecord $PSItem
    }
    finally{
        Submit-Log "ENDFUNCTION: disableWakeOnPattern"
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
        Submit-Log "STARTFUNCTION: disablePowerManagement"
        <# Note: When you use Get-CimInstance to get instance of the class MSNdis_DeviceWakeOnMagicPacketOnly we are unable to call Put method on the base class as it does not exist. Using Get-WMIObject we are able to call the put method and therfore making the change persistant. #>
        # $pnp_deviceid = $adapter | Select-Object -ExpandProperty "PnPDeviceID"
        $pnp_deviceid = $adapter.PnPDeviceID

        #-----> Allow the computer to turn off this device to save power

        Submit-Log "Disable `"Allow the computer to turn off this device to save power`""
        $deviceenable_object = Get-WmiObject -class MSPower_DeviceEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        $deviceenable_status = $deviceenable_object.Enable
        Submit-Log "STATUS: deviceenable - $($deviceenable_status)"

        if (-not ($deviceenable_object.PSObject.Properties.Match("Enable").count)) {
            Submit-Log "`"Allow the computer to turn off this device to save power`" option is not available"
            $set_value = "Unavailable"
        }
        elseif ($deviceenable_object.Enable -eq $true) {
            $deviceenable_object.Enable = $false
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            # void is used to eliminate the output from the statement
            [void] $deviceenable_object.psbase.Put()
            Submit-Log "Allow the computer to turn off this device to save power is now disabled"
            $set_value = $deviceenable_object.Enable
        }
        else {
            Submit-Log "Allow the computer to turn off this device to save power was already disabled"
            $set_value = $deviceenable_object.Enable
        }

        Set-Property -property "Turn Off Device To Save Power" -previousValue "$($deviceenable_status)" -currentValue "$($set_value)"

        #-----> Allow this device to wake the computer

        Submit-Log "Disable `"Allow this device to wake the computer`""
        $devicewakeenable_object = Get-WmiObject -class MSPower_DeviceWakeEnable -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        $devicewakeenable_status = $devicewakeenable_object.Enable
        Submit-Log "STATUS: devicewakeenable - $($devicewakeenable_status)"
        if (-not ($devicewakeenable_object.PSObject.Properties.Match("Enable").count)) {
            Submit-Log "`"Only allow a magic packet to wake the computer`" option is not available"
            $set_value = "Unavailable"
        }
        elseif ($devicewakeenable_object.Enable -eq $true) {
            $devicewakeenable_object.Enable = $false
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            [void] $devicewakeenable_object.psbase.Put()
            Submit-Log "Allow this device to wake the computer is now disabled"
            $set_value = $devicewakeenable_object.Enable
        }
        else {
            Submit-Log "Allow this device to wake the computer was already disabled"
            $set_value = $devicewakeenable_object.Enable
        }

        Set-Property -property "Wake up the computer" -previousValue "$($devicewakeenable_status)" -currentValue "$($set_value)"

        #-----> Only allow a magic packet to wake the computer

        Submit-Log "Disable `"Only allow a magic packet to wake the computer`""
        $devicewakeonmagicpacketonly_object = Get-WmiObject -class MSNdis_DeviceWakeOnMagicPacketOnly -Namespace root/wmi | where-object instancename -like "*$($pnp_deviceid)*"
        $devicewakeonmagicpacketonly_status = $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly
        Submit-Log "STATUS: devicewakeonmagicpacketonly - $($devicewakeonmagicpacketonly_status)"
        if (-not ($devicewakeonmagicpacketonly_object.PSObject.Properties.Match("EnableWakeOnMagicPacketOnly").count)) {
            Submit-Log "`"Only allow a magic packet to wake the computer`" option is not available"
            $set_value = "Unavailable"
        }
        elseif ($devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly -eq $true) {
            $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly = $false
            #call the Put method from the base WMI object so to write the changes back to the WMI database and thereby fixing the change.
            [void] $devicewakeonmagicpacketonly_object.psbase.Put()
            Submit-Log "Only allow a magic packet to wake the computer is now disabled"
            $set_value = $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly
        }
        else {
            Submit-Log "Only allow a magic packet to wake the computer was already disabled"
            $set_value = $devicewakeonmagicpacketonly_object.EnableWakeOnMagicPacketOnly
        }

        Set-Property -property "Only allow magic packect" -previousValue "$($devicewakeonmagicpacketonly_status)" -currentValue "$($set_value)"
    }
    catch {
        Submit-Error -text "ERROR Function - disablePowerManagement" -errorRecord $PSItem
    }
    finally{
        Submit-Log "ENDFUNCTION: disablePowerManagement"
    }
}

function enableHiberbootEnabledRegistry {
    try {
        # When the registry key HiberbootEnabled is set to 0 (disabled) Fast startup gets disabled.
        Submit-Log "STARTFUNCTION: enableHiberbootEnabledRegistry"

        # local variables
        $registry_path = "hklm:\SYSTEM\CurrentControlSet\Control\Session?Manager\Power"
        $name = "HiberbootEnabled"
        $value = 1

        # Check whether registry path exists.
        if (!(Test-Path $registry_path)) {
            throw "ERROR: Registry Path doesn't exist"
        }
        $FindHiberbootEnabled = Get-ItemProperty $registry_path
        $FindHiberbootEnabled_status = $FindHiberbootEnabled.HiberbootEnabled
        # This checks if HiberbootEnabled is equal to 1.
        If ($FindHiberbootEnabled.HiberbootEnabled -eq 0)
        {
            Submit-Log "HiberbootEnabled is DISABLED. Setting to ENABLED..."
            Set-ItemProperty -Path $FindHiberbootEnabled.PSPath -Name $name -Value $value -Type DWORD -Force
        }
        Else
        {
            Submit-Log "HiberbootEnabled is already ENABLED"
        }

        $FindHiberbootEnabled = Get-ItemProperty $registry_path
        Set-Property -property "HiberbootEnabled" -previousValue "$($FindHiberbootEnabled_status)" -currentValue "$($FindHiberbootEnabled.HiberbootEnabled)"
    }
    catch {
        Submit-Error -text "ERROR: Function - enableHiberbootEnabledRegistry" -errorRecord $PSItem
    }
    finally{
        Submit-Log "ENDFUNCTION: enableHiberbootEnabledRegistry"
    }
}

function disableHiberbootEnabledRegistry {
    try {
        # When the registry key HiberbootEnabled is set to 0 (disabled) Fast startup gets disabled.
        Submit-Log "STARTFUNCTION: disableHiberbootEnabledRegistry"

        # local variables
        $registry_path = "hklm:\SYSTEM\CurrentControlSet\Control\Session?Manager\Power"
        $name = "HiberbootEnabled"
        $value = 0

        # Check whether registry path exists.
        if (!(Test-Path $registry_path)) {
            throw "ERROR: Registry Path doesn't exist"
        }
        $FindHiberbootEnabled = Get-ItemProperty "hklm:\SYSTEM\CurrentControlSet\Control\Session?Manager\Power"
        $FindHiberbootEnabled_status = $FindHiberbootEnabled.HiberbootEnabled
        # This checks if HiberbootEnabled is equal to 1.
        If ($FindHiberbootEnabled.HiberbootEnabled -eq 1)
        {
            Submit-Log "HiberbootEnabled is Enabled. Setting to DISABLED..."
            Set-ItemProperty -Path $FindHiberbootEnabled.PSPath -Name $name -Value $value -Type DWORD -Force
        }
        Else
        {
            Submit-Log "HiberbootEnabled is already DISABLED"
        }

        $FindHiberbootEnabled = Get-ItemProperty $registry_path
        Set-Property -property "HiberbootEnabled" -previousValue "$($FindHiberbootEnabled_status)" -currentValue "$($FindHiberbootEnabled.HiberbootEnabled)"
    }
    catch {
        Submit-Error -text "ERROR: Function - disableHiberbootEnabledRegistry" -errorRecord $PSItem
    }
    finally{
        Submit-Log "ENDFUNCTION: disableHiberbootEnabledRegistry"
    }
}

function successProcess {

    try {
        Submit-Log -text "STARTFUNCTION: successProcess"
        $logContents = "`n------------------------- Log Details -----------------------------------------`n`n"
        $logContents += Get-Content $logFilePath -Encoding UTF8 -Raw
        $fileObject = logFileName -successFlag
        $output = "`n------------------------------ Output -------------------------------------------`n"
        $output += $propertyArray | Out-String
        # $output | Out-File -FilePath $logFilePath -Encoding UTF8 -Append | Out-Null
        Set-Content $logFilePath -value $output
        Add-Content $logFilePath $logContents -NoNewline
        # $logContents | Out-File -FilePath $logFilePath -Encoding UTF8 -Append | Out-Null

        Rename-Item -Path "$($logFilePath)" -NewName "$($fileObject.Name)" -Force

        $script:logFilePath = $fileObject.Path
    }
    catch {
        Submit-Error -text "ERROR: Function - successProcess" -errorRecord $PSItem
    }
    finally{
        Submit-Log -text "ENDFUNCTION: successProcess"
    }
}

try {
    # Script variables
    $logFilePath = (LogFileName).Path
    parameterValidation $adapter_name
    $net_adapters = get-netadapter -name $adapter_name*

    $adapter = selectAdapter $net_adapters
    Submit-Log -text "Selected Adapter:$($adapter.InterfaceDescription)"

    # Main procedure for the script
    if ($enable_wakeonlan -and $disable_wakeonlan) {
        Submit-Log -text "You cannot enable and disable wakeonlan at the same time. Please provide one argument"
        exit
    }
    elseif ($enable_wakeonlan) {
        enableWakeOnMagicPacket -adapter $adapter
        enableWakeOnPattern -adapter $adapter
        enablePowerManagement -adapter $adapter
        Submit-Log -text "SUCCESS: Wake on lan settings were set."
    }
    elseif ($disable_wakeonlan) {
        disableWakeOnMagicPacket -adapter $adapter
        disableWakeOnPattern -adapter $adapter
        disablePowerManagement -adapter $adapter
        Submit-Log -text "SUCCESS: Wake on lan settings were disabled."
    }
    else {
        Submit-Log -text "No Argument for enable or disable wake on lan"
    }

    # Check if disablefaststartup switch is present and if present execute accourdingly.
    if ($disable_faststartup) {
        disableHiberbootEnabledRegistry
    }
    elseif ($enable_faststartup) {
        enableHiberbootEnabledRegistry
    }
    else {
        Submit-Log -text "No Argument for enable or disable for Fast Startup"
    }

    successProcess

}
catch {
    Submit-Error -text "ERROR: Main Block" -errorRecord $_
    exit
}