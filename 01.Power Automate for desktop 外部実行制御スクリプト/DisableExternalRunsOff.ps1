# Power Automate for desktop
# Remove the machine-wide URL/desktop shortcut run disable setting.
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
        Write-Host 'No machine-wide URL/desktop shortcut run disable setting was found.'
        return
    }

    if ([int]$currentValue -ne 2) {
        Write-Warning "ConfigureExternalRuns is currently $currentValue, not 2."
        Write-Warning 'This script only removes the URL/desktop shortcut run disable setting.'
        Write-Warning 'Use DialogOffAdmin.ps1 to remove ConfigureExternalRuns=1.'
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

    Write-Host 'Done: removed the URL/desktop shortcut run disable setting.'
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
