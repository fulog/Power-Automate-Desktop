# Power Automate for desktop
# Re-enable the confirmation dialog for URL/desktop shortcut runs.
# Scope: current Windows user.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$registryPath = 'SOFTWARE\Microsoft\Power Automate Desktop'
$valueName = 'EnableAskBeforeRunningAFlowExternally'
$machineValueName = 'ConfigureExternalRuns'

function Get-PadRegistryView {
    if ([Environment]::Is64BitOperatingSystem) {
        return [Microsoft.Win32.RegistryView]::Registry64
    }

    return [Microsoft.Win32.RegistryView]::Registry32
}

$userBaseKey = $null
$userSubKey = $null
$machineBaseKey = $null
$machineSubKey = $null

try {
    $registryView = Get-PadRegistryView

    $userBaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::CurrentUser,
        $registryView
    )
    $userSubKey = $userBaseKey.OpenSubKey($registryPath, $true)

    if ($null -ne $userSubKey -and ($userSubKey.GetValueNames() -contains $valueName)) {
        $userSubKey.DeleteValue($valueName, $false)
        Write-Host 'Returned to the default state where the confirmation dialog is shown.'
        Write-Host "Removed setting: HKCU\$registryPath\$valueName"
    }
    else {
        Write-Host 'No user setting that disables the confirmation dialog was found.'
        Write-Host 'The current state is already the default confirmation-dialog behavior.'
    }

    $remainingValue = if ($null -ne $userSubKey -and ($userSubKey.GetValueNames() -contains $valueName)) {
        $userSubKey.GetValue($valueName)
    }
    else {
        $null
    }

    if ($null -ne $remainingValue) {
        throw "Value still exists after removal: $remainingValue"
    }

    $machineBaseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine,
        $registryView
    )
    $machineSubKey = $machineBaseKey.OpenSubKey($registryPath)

    $machineValue = if ($null -ne $machineSubKey -and ($machineSubKey.GetValueNames() -contains $machineValueName)) {
        $machineSubKey.GetValue($machineValueName)
    }
    else {
        $null
    }

    Write-Host ''

    if ($machineValue -eq 1) {
        Write-Host 'Machine setting: the confirmation dialog is forced on.'
    }
    elseif ($machineValue -eq 2) {
        Write-Warning 'Machine setting: URL/desktop shortcut runs are disabled.'
        Write-Warning 'Changing the user setting does not allow external runs.'
    }
    else {
        Write-Host 'Machine setting: no machine-wide external run policy is set.'
    }

    Write-Host ''
    Write-Host 'Restart Power Automate for desktop before checking the result.'
}
catch {
    Write-Error "Failed to update setting: $($_.Exception.Message)"
    exit 1
}
finally {
    if ($null -ne $machineSubKey) {
        $machineSubKey.Dispose()
    }

    if ($null -ne $machineBaseKey) {
        $machineBaseKey.Dispose()
    }

    if ($null -ne $userSubKey) {
        $userSubKey.Dispose()
    }

    if ($null -ne $userBaseKey) {
        $userBaseKey.Dispose()
    }
}
