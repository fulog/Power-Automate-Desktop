param(
    [Parameter(Mandatory)]
    [string]$TargetScript,

    [Parameter(Mandatory)]
    [string]$OperationName,

    [switch]$RequireAdministrator,

    [switch]$ElevatedChild,

    [string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$powershellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$allowedScripts = @(
    'DialogCheck.ps1'
    'DialogOff.ps1'
    'DialogOn.ps1'
    'DialogOnAdmin.ps1'
    'DialogOffAdmin.ps1'
    'DisableExternalRunsCheck.ps1'
    'DisableExternalRunsOn.ps1'
    'DisableExternalRunsOff.ps1'
)

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertTo-SafeFileName {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $result = $Value
    foreach ($character in [IO.Path]::GetInvalidFileNameChars()) {
        $result = $result.Replace([string]$character, '_')
    }

    if ([string]::IsNullOrWhiteSpace($result)) {
        return 'PAD操作'
    }

    return $result
}

function New-UniqueLogPath {
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$BaseName
    )

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
    $candidate = Join-Path $Directory ("{0}_{1}_result.txt" -f $BaseName, $timestamp)
    $suffix = 1

    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $Directory ("{0}_{1}_{2}_result.txt" -f $BaseName, $timestamp, $suffix)
        $suffix++
    }

    return $candidate
}

function Write-LogLine {
    param(
        [AllowEmptyString()]
        [string]$Message = ''
    )

    Add-Content -LiteralPath $script:LogPath -Value $Message -Encoding UTF8
}

function Quote-ProcessArgument {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    return '"' + $Value.Replace('"', '\"') + '"'
}

function Show-CompletedLog {
    if (Test-Path -LiteralPath $script:LogPath) {
        Write-Host ''
        Get-Content -LiteralPath $script:LogPath -Encoding UTF8 | ForEach-Object {
            Write-Host $_
        }
    }

    Write-Host ''
    Write-Host "Result file: $script:LogPath"
}

$isAdministrator = Test-IsAdministrator
$targetPath = Join-Path $scriptRoot $TargetScript

try {
    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        $logDirectory = Join-Path $scriptRoot 'logs'
        [IO.Directory]::CreateDirectory($logDirectory) | Out-Null

        $safeOperationName = ConvertTo-SafeFileName -Value $OperationName
        $script:LogPath = New-UniqueLogPath -Directory $logDirectory -BaseName $safeOperationName
        [IO.File]::WriteAllText(
            $script:LogPath,
            '',
            (New-Object Text.UTF8Encoding($true))
        )

        Write-LogLine '=== Power Automate for desktop 外部実行制御 ==='
        Write-LogLine ("開始日時: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz'))
        Write-LogLine ("操作名: {0}" -f $OperationName)
        Write-LogLine ("実行ユーザー: {0}" -f [Security.Principal.WindowsIdentity]::GetCurrent().Name)
        Write-LogLine ("対象スクリプト: {0}" -f $TargetScript)
        Write-LogLine ("管理者権限要求: {0}" -f $RequireAdministrator.IsPresent)
        Write-LogLine ''
    }
    else {
        $script:LogPath = [IO.Path]::GetFullPath($LogPath)
        if (-not (Test-Path -LiteralPath $script:LogPath -PathType Leaf)) {
            throw "Log file was not initialized by the parent process: $script:LogPath"
        }
    }
}
catch {
    Write-Error "ログファイルを作成できないため、処理を中止しました: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}

try {
    if ($allowedScripts -notcontains $TargetScript) {
        throw "Unsupported target script: $TargetScript"
    }

    $targetPath = [IO.Path]::GetFullPath($targetPath)
    if ([IO.Path]::GetDirectoryName($targetPath) -ne [IO.Path]::GetFullPath($scriptRoot)) {
        throw "Target script must be located in the launcher directory: $TargetScript"
    }

    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
        throw "Target script was not found: $targetPath"
    }

    if ($RequireAdministrator -and -not $isAdministrator) {
        if ($ElevatedChild) {
            throw 'Administrator elevation did not succeed.'
        }

        Write-LogLine 'UACによる管理者権限への昇格を要求します。'

        $arguments = @(
            '-NoProfile'
            '-ExecutionPolicy'
            'Bypass'
            '-File'
            (Quote-ProcessArgument -Value $MyInvocation.MyCommand.Path)
            '-TargetScript'
            (Quote-ProcessArgument -Value $TargetScript)
            '-OperationName'
            (Quote-ProcessArgument -Value $OperationName)
            '-RequireAdministrator'
            '-ElevatedChild'
            '-LogPath'
            (Quote-ProcessArgument -Value $script:LogPath)
        )

        try {
            $elevatedProcess = Start-Process `
                -FilePath $powershellExe `
                -ArgumentList ($arguments -join ' ') `
                -Verb RunAs `
                -WindowStyle Hidden `
                -Wait `
                -PassThru

            $exitCode = $elevatedProcess.ExitCode
        }
        catch {
            Write-LogLine ("UAC昇格に失敗またはキャンセルされました: {0}" -f $_.Exception.Message)
            Write-LogLine ("終了日時: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz'))
            Write-LogLine '終了コード: 1'
            Show-CompletedLog
            exit 1
        }

        Show-CompletedLog
        exit $exitCode
    }

    Write-LogLine ("実行時の管理者権限: {0}" -f $isAdministrator)
    Write-LogLine '--- 実行結果 ---'

    & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $targetPath 2>&1 |
        ForEach-Object {
            $line = $_.ToString()
            Write-Host $line
            Write-LogLine $line
        }

    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) {
        $exitCode = 0
    }

    Write-LogLine '--- 実行終了 ---'
    Write-LogLine ("終了日時: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz'))
    Write-LogLine ("終了コード: {0}" -f $exitCode)

    Write-Host ''
    Write-Host "Result file: $script:LogPath"
    exit $exitCode
}
catch {
    $message = "ランチャー処理に失敗しました: $($_.Exception.Message)"
    Write-Error $message -ErrorAction Continue

    try {
        Write-LogLine $message
        Write-LogLine ("終了日時: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz'))
        Write-LogLine '終了コード: 1'
    }
    catch {
        Write-Error "ログへのエラー記録にも失敗しました: $($_.Exception.Message)" -ErrorAction Continue
    }

    Write-Host ''
    Write-Host "Result file: $script:LogPath"
    exit 1
}
