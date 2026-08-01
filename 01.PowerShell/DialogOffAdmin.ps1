# Power Automate for desktop
# Remove the machine-wide forced confirmation dialog setting.
# Administrator rights are required.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$registryPath = 'SOFTWARE\Microsoft\Power Automate Desktop'
$valueName = 'ConfigureExternalRuns'

function Get-PadRegistryView {
    if ([Environment]::Is64BitOperatingSystem) {
        return [Microsoft.Win32.RegistryView]::Registry64
    }

    return [Microsoft.Win32.RegistryView]::Registry32
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Write-Error 'Run PowerShell as Administrator.'
    exit 1
}

$baseKey = $null
$subKey = $null

try {
    $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine,
        (Get-PadRegistryView)
    )
    $subKey = $baseKey.OpenSubKey($registryPath, $true)

    $currentValue = if ($null -ne $subKey -and ($subKey.GetValueNames() -contains $valueName)) {
        $subKey.GetValue($valueName)
    }
    else {
        $null
    }

    if ($null -eq $currentValue) {
        Write-Host 'ConfigureExternalRuns is not set.'
        Write-Host 'No machine-wide forced confirmation dialog setting was found.'
        return
    }

    if ([int]$currentValue -ne 1) {
        Write-Warning "ConfigureExternalRuns is currently $currentValue, not 1."
        Write-Warning 'This script only removes the forced confirmation dialog setting.'
        Write-Warning 'Use DisableExternalRunsOff.ps1 to remove ConfigureExternalRuns=2.'
        return
    }

    $subKey.DeleteValue($valueName, $false)

    $remainingValue = if ($null -ne $subKey -and ($subKey.GetValueNames() -contains $valueName)) {
        $subKey.GetValue($valueName)
    }
    else {
        $null
    }

    if ($null -ne $remainingValue) {
        throw "Value still exists after removal: $remainingValue"
    }

    Write-Host 'ConfigureExternalRuns after removal: not set'
    Write-Host 'Done: removed the machine-wide forced confirmation dialog setting.'
    Write-Host 'Restart Power Automate for desktop before checking the result.'
}
catch {
    Write-Error "Failed to update setting: $($_.Exception.Message)"
    exit 1
}
finally {
    if ($null -ne $subKey) {
        $subKey.Dispose()
    }

    if ($null -ne $baseKey) {
        $baseKey.Dispose()
    }
}
