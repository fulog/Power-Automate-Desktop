# Power Automate for desktop
# Disable the confirmation dialog for URL/desktop shortcut runs.
# Scope: current Windows user.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$registryPath = 'SOFTWARE\Microsoft\Power Automate Desktop'
$valueName = 'EnableAskBeforeRunningAFlowExternally'

function Get-PadRegistryView {
    if ([Environment]::Is64BitOperatingSystem) {
        return [Microsoft.Win32.RegistryView]::Registry64
    }

    return [Microsoft.Win32.RegistryView]::Registry32
}

$baseKey = $null
$subKey = $null

try {
    $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::CurrentUser,
        (Get-PadRegistryView)
    )
    $subKey = $baseKey.CreateSubKey($registryPath)

    if ($null -eq $subKey) {
        throw "Failed to create registry key: HKCU\$registryPath"
    }

    $subKey.SetValue($valueName, 0, [Microsoft.Win32.RegistryValueKind]::DWord)
    $value = $subKey.GetValue($valueName)

    if ([int]$value -ne 0) {
        throw "Unexpected value after update: $value"
    }

    Write-Host "EnableAskBeforeRunningAFlowExternally = $value"
    Write-Host 'Done: the current user will not see the confirmation dialog for external runs.'
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
