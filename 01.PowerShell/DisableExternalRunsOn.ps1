# Power Automate for desktop
# Disable URL/desktop shortcut runs machine-wide.
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
    $subKey = $baseKey.CreateSubKey($registryPath)

    if ($null -eq $subKey) {
        throw "Failed to create registry key: HKLM\$registryPath"
    }

    $subKey.SetValue($valueName, 2, [Microsoft.Win32.RegistryValueKind]::DWord)
    $value = $subKey.GetValue($valueName)

    Write-Host "ConfigureExternalRuns = $value"

    if ([int]$value -eq 2) {
        Write-Host 'Done: URL/desktop shortcut runs are disabled.'
    }
    else {
        throw "Unexpected value after update: $value"
    }

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
