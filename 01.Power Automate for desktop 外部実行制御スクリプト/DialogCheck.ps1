# Power Automate for desktop
# 外部実行時の確認ダイアログ設定確認スクリプト

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$registryPath = 'SOFTWARE\Microsoft\Power Automate Desktop'

function Get-PadRegistryValue {
    param(
        [Parameter(Mandatory)]
        [Microsoft.Win32.RegistryHive]$Hive,

        [Parameter(Mandatory)]
        [Microsoft.Win32.RegistryView]$View,

        [Parameter(Mandatory)]
        [string]$ValueName
    )

    $baseKey = $null
    $subKey  = $null

    try {
        $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey($Hive, $View)
        $subKey = $baseKey.OpenSubKey($registryPath)

        if ($null -eq $subKey) {
            return [PSCustomObject]@{
                Scope      = $Hive.ToString()
                View       = $View.ToString()
                ValueName  = $ValueName
                ReadSucceeded = $true
                Exists     = $false
                Value      = $null
                ValueType  = $null
                Path       = "$Hive\$registryPath"
                Error      = $null
            }
        }

        $valueNames = $subKey.GetValueNames()

        if ($valueNames -notcontains $ValueName) {
            return [PSCustomObject]@{
                Scope      = $Hive.ToString()
                View       = $View.ToString()
                ValueName  = $ValueName
                ReadSucceeded = $true
                Exists     = $false
                Value      = $null
                ValueType  = $null
                Path       = "$Hive\$registryPath"
                Error      = $null
            }
        }

        [PSCustomObject]@{
            Scope      = $Hive.ToString()
            View       = $View.ToString()
            ValueName  = $ValueName
            ReadSucceeded = $true
            Exists     = $true
            Value      = $subKey.GetValue($ValueName)
            ValueType  = $subKey.GetValueKind($ValueName).ToString()
            Path       = "$Hive\$registryPath"
            Error      = $null
        }
    }
    catch {
        [PSCustomObject]@{
            Scope      = $Hive.ToString()
            View       = $View.ToString()
            ValueName  = $ValueName
            ReadSucceeded = $false
            Exists     = $false
            Value      = $null
            ValueType  = $null
            Path       = "$Hive\$registryPath"
            Error      = $_.Exception.Message
        }
    }
    finally {
        if ($null -ne $subKey) {
            $subKey.Dispose()
        }

        if ($null -ne $baseKey) {
            $baseKey.Dispose()
        }
    }
}

function Select-PadRegistryResult {
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    # 64bit OSでは64bitビューを優先。
    # 値がなければ32bitビューも確認する。
    $viewOrder = if ([Environment]::Is64BitOperatingSystem) {
        @('Registry64', 'Registry32')
    }
    else {
        @('Registry32')
    }

    foreach ($view in $viewOrder) {
        $found = $Results |
            Where-Object {
                $_.View -eq $view -and $_.Exists
            } |
            Select-Object -First 1

        if ($null -ne $found) {
            return $found
        }
    }

    return $null
}

$views = if ([Environment]::Is64BitOperatingSystem) {
    @(
        [Microsoft.Win32.RegistryView]::Registry64
        [Microsoft.Win32.RegistryView]::Registry32
    )
}
else {
    @([Microsoft.Win32.RegistryView]::Registry32)
}

$results = foreach ($view in $views) {
    # 管理者による強制設定
    Get-PadRegistryValue `
        -Hive LocalMachine `
        -View $view `
        -ValueName 'ConfigureExternalRuns'

    # 現在のWindowsユーザーの設定
    Get-PadRegistryValue `
        -Hive CurrentUser `
        -View $view `
        -ValueName 'EnableAskBeforeRunningAFlowExternally'
}

Write-Host ''
Write-Host '=== レジストリ設定 ==='

$results |
    Select-Object Scope, View, ValueName, ReadSucceeded, Exists, Value, ValueType, Path, Error |
    Format-Table -AutoSize

$readErrors = @(
    $results | Where-Object { -not $_.ReadSucceeded }
)

if ($readErrors.Count -gt 0) {
    Write-Host ''
    Write-Host '=== 判定結果 ==='
    Write-Error 'レジストリの読取りに失敗したため、現在の設定を判定できません。' -ErrorAction Continue

    foreach ($readError in $readErrors) {
        Write-Error (
            '{0} / {1} / {2}: {3}' -f
            $readError.Scope,
            $readError.View,
            $readError.ValueName,
            $readError.Error
        ) -ErrorAction Continue
    }

    exit 1
}

$machineSetting = Select-PadRegistryResult -Results @(
    $results | Where-Object {
        $_.Scope -eq 'LocalMachine' -and
        $_.ValueName -eq 'ConfigureExternalRuns'
    }
)

$userSetting = Select-PadRegistryResult -Results @(
    $results | Where-Object {
        $_.Scope -eq 'CurrentUser' -and
        $_.ValueName -eq 'EnableAskBeforeRunningAFlowExternally'
    }
)

Write-Host ''
Write-Host '=== 判定結果 ==='

if ($null -ne $machineSetting) {
    switch ([int]$machineSetting.Value) {
        1 {
            Write-Host '確認ダイアログ：表示されます'
            Write-Host '理由：HKLMのConfigureExternalRuns=1により、管理者設定で表示が強制されています。'
            Write-Host 'ユーザー側の設定では変更できません。'
            break
        }

        2 {
            Write-Host '外部からのフロー実行：禁止されています'
            Write-Host '理由：HKLMのConfigureExternalRuns=2が設定されています。'
            Write-Host 'ショートカットや実行URLからフローを起動できません。'
            break
        }

        0 {
            Write-Host 'HKLMによる確認ダイアログの強制はありません。'
            # 続けてHKCUを判定
        }

        default {
            Write-Warning "ConfigureExternalRunsに未定義の値「$($machineSetting.Value)」が設定されています。"
        }
    }

    if ([int]$machineSetting.Value -in @(1, 2)) {
        return
    }
}

if ($null -ne $userSetting) {
    switch ([int]$userSetting.Value) {
        0 {
            Write-Host '確認ダイアログ：表示されない設定です'
            Write-Host '理由：HKCUのEnableAskBeforeRunningAFlowExternally=0です。'
        }

        1 {
            Write-Warning 'Confirmation dialog: likely enabled, but verify in the product UI.'
            Write-Warning 'Reason: HKCU EnableAskBeforeRunningAFlowExternally=1.'
            Write-Warning 'Microsoft Learn explicitly documents only 0 for this HKCU value: do not show the confirmation dialog.'
            Write-Warning 'Confirm this value behavior in your Power Automate for desktop version and settings UI.'
        }

        default {
            Write-Warning "EnableAskBeforeRunningAFlowExternallyに未定義の値「$($userSetting.Value)」が設定されています。"
        }
    }
}
else {
    Write-Host '確認ダイアログのユーザー設定は、レジストリに明示されていません。'
    Write-Host 'Power Automate for desktopの設定画面または製品の既定値に従います。'
    Write-Host ''
    Write-Host 'PADコンソールで次の項目を確認してください：'
    Write-Host '設定 → フローの実行制御 → フローを外部から呼び出すときに確認ダイアログを表示する'
}

Write-Host ''
Write-Host "確認対象ユーザー：$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
