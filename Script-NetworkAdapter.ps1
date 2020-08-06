
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
    param (
        # Parameter help description
        [Parameter()]
        $adapter_name
    )
    try {
        if (-not $adapter_name) {
            throw "ERROR - adapter_name is Empty and is a required parameter for this script"
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

adapterValidation $adapter_name
$adapter = selectAdapter $net_adapters


$wakeonmagicpacket_status = Get-NetAdapterPowerManagement -Name $adapter.Name | Select-Object -ExpandProperty "wakeonmagicpacket"

if (($wakeonmagicpacket_status -ne "Enabled") -and ($wake_up) ) {
    Enable-NetAdapterPowerManagement -Name $adapter.Name -WakeOnMagicPacket
}

