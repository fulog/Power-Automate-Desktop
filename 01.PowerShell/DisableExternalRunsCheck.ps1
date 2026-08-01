# Power Automate for desktop
# Check the machine-wide URL/desktop shortcut run setting.

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

$baseKey = $null
$subKey = $null

try {
    $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine,
        (Get-PadRegistryView)
    )
    $subKey = $baseKey.OpenSubKey($registryPath)

    $value = if ($null -ne $subKey -and ($subKey.GetValueNames() -contains $valueName)) {
        $subKey.GetValue($valueName)
    }
    else {
        $null
    }

    if ($value -eq 2) {
        Write-Host 'Current setting: URL/desktop shortcut runs are disabled.'
    }
    elseif ($value -eq 1) {
        Write-Host 'Current setting: the confirmation dialog is forced on.'
    }
    elseif ($null -eq $value) {
        Write-Host 'Current setting: no machine-wide policy is set.'
    }
    else {
        Write-Warning "Current setting: ConfigureExternalRuns has an undefined value: $value"
    }
}
catch {
    Write-Error "Failed to check setting: $($_.Exception.Message)"
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
