# Power Automate for desktop
# Force the confirmation dialog machine-wide.
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

    $subKey.SetValue($valueName, 1, [Microsoft.Win32.RegistryValueKind]::DWord)
    $configuredValue = $subKey.GetValue($valueName)

    if ([int]$configuredValue -eq 1) {
        Write-Host 'Done: setting was updated.'
        Write-Host 'A confirmation dialog will always be shown for URL/desktop shortcut runs.'
        Write-Host "Path: HKLM\$registryPath\$valueName"
        Write-Host 'Value: 1'
        Write-Host ''
        Write-Host 'Restart Power Automate for desktop before checking the result.'
    }
    else {
        throw "Unexpected value after update: $configuredValue"
    }
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
