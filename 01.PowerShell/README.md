# Power Automate for desktop 外部実行制御スクリプト

Power Automate for desktop（PAD）のデスクトップ フローを、**実行 URL**または**デスクトップ ショートカット**から起動するときの動作を制御する PowerShell スクリプト集です。

Windows レジストリを変更し、次の設定を切り替えます。

- 外部実行時の確認ダイアログを、現在のユーザーだけ非表示にする
- 現在のユーザーの確認ダイアログ設定を既定状態へ戻す
- 確認ダイアログを端末全体で強制表示する
- 実行 URL／デスクトップ ショートカットからの起動を端末全体で禁止する
- ユーザー設定と端末全体の設定を確認する

## 特徴

- PowerShellだけで設定・解除・確認ができる
- `HKCU` のユーザー設定と `HKLM` の管理者設定を分けて扱う
- 64ビットOSでは64ビットのレジストリ ビューを明示的に使用する
- `DialogCheck.ps1` は64ビットOS上で64ビット／32ビットの両方のレジストリ ビューを確認する
- 管理者権限が必要なスクリプトでは、実行前に権限を確認する
- `Set-StrictMode`、例外処理、レジストリ ハンドルの解放を実装している
- 設定後の値を再取得し、変更が反映されたことを確認する
- 解除スクリプトは対象の値だけを削除し、異なる管理者設定を誤って解除しない

## 設定の仕組み

使用するレジストリ設定は次のとおりです。

| 適用範囲 | レジストリ パス | 値の名前 | 値 | 動作 |
|---|---|---|---:|---|
| 現在のユーザー | `HKCU\SOFTWARE\Microsoft\Power Automate Desktop` | `EnableAskBeforeRunningAFlowExternally` | `0` | 確認ダイアログを表示しない |
| 端末全体 | `HKLM\SOFTWARE\Microsoft\Power Automate Desktop` | `ConfigureExternalRuns` | `1` | 確認ダイアログを常に表示し、ユーザーによる変更を禁止する |
| 端末全体 | `HKLM\SOFTWARE\Microsoft\Power Automate Desktop` | `ConfigureExternalRuns` | `2` | 実行 URL／デスクトップ ショートカットからのフロー起動を禁止する |

`EnableAskBeforeRunningAFlowExternally` について、Microsoft Learnで確認ダイアログを非表示にする値として明示されているのは `0` です。

そのため、本リポジトリでは確認ダイアログを再表示するときに `1` を設定せず、`EnableAskBeforeRunningAFlowExternally` を削除してPADの既定動作へ戻します。

## 設定の優先順位

管理者設定である `HKLM\...\ConfigureExternalRuns` が、ユーザー設定より優先されます。

1. `ConfigureExternalRuns = 2`  
   外部実行そのものが禁止されます。
2. `ConfigureExternalRuns = 1`  
   確認ダイアログが強制表示されます。ユーザー側では解除できません。
3. `ConfigureExternalRuns` が未設定  
   現在のユーザーの `EnableAskBeforeRunningAFlowExternally` またはPADの既定値に従います。

## ファイル一覧

| ファイル | 権限 | 処理内容 |
|---|---|---|
| [`DialogCheck.ps1`](DialogCheck.ps1) | 通常 | `HKCU` と `HKLM` の設定を確認し、優先順位を考慮して最終的な動作を判定する |
| [`DialogOff.ps1`](DialogOff.ps1) | 通常 | `EnableAskBeforeRunningAFlowExternally = 0` を設定し、現在のユーザーの確認ダイアログを非表示にする |
| [`DialogOn.ps1`](DialogOn.ps1) | 通常 | 現在のユーザーのダイアログ非表示設定を削除して既定状態へ戻し、管理者設定の状態も表示する |
| [`DialogOnAdmin.ps1`](DialogOnAdmin.ps1) | 管理者 | `ConfigureExternalRuns = 1` を設定し、確認ダイアログを端末全体で強制表示する |
| [`DialogOffAdmin.ps1`](DialogOffAdmin.ps1) | 管理者 | 現在値が `1` の場合だけ値を削除し、端末全体の確認ダイアログ強制設定を解除する |
| [`DisableExternalRunsCheck.ps1`](DisableExternalRunsCheck.ps1) | 通常 | `ConfigureExternalRuns` を確認し、未設定／強制表示／外部実行禁止を判定する |
| [`DisableExternalRunsOn.ps1`](DisableExternalRunsOn.ps1) | 管理者 | `ConfigureExternalRuns = 2` を設定し、外部からのフロー起動を端末全体で禁止する |
| [`DisableExternalRunsOff.ps1`](DisableExternalRunsOff.ps1) | 管理者 | 現在値が `2` の場合だけ値を削除し、端末全体の外部実行禁止設定を解除する |

## 解除スクリプトの保護動作

`DialogOffAdmin.ps1` と `DisableExternalRunsOff.ps1` は、同じレジストリ値 `ConfigureExternalRuns` を扱いますが、削除対象を明確に分けています。

| 現在値 | `DialogOffAdmin.ps1` | `DisableExternalRunsOff.ps1` |
|---:|---|---|
| 未設定 | 変更せず終了 | 変更せず終了 |
| `1` | 値を削除 | 警告を表示し、変更しない |
| `2` | 警告を表示し、変更しない | 値を削除 |
| その他 | 警告を表示し、変更しない | 警告を表示し、変更しない |

このため、確認ダイアログの強制表示を解除するときは `DialogOffAdmin.ps1`、外部実行禁止を解除するときは `DisableExternalRunsOff.ps1` を使用してください。

## 動作環境

- Windows
- Power Automate for desktop
- Windows PowerShell 5.1 または PowerShell 7

次のスクリプトは、PowerShellを**管理者として実行**する必要があります。

- `DialogOnAdmin.ps1`
- `DialogOffAdmin.ps1`
- `DisableExternalRunsOn.ps1`
- `DisableExternalRunsOff.ps1`

## 使い方

### 1. ファイルを取得する

リポジトリをクローンするか、必要な `.ps1` ファイルをダウンロードします。

```powershell
git clone <repository-url>
cd <repository-folder>
```

### 2. 現在の設定を確認する

ユーザー設定と端末全体の設定をまとめて確認します。

```powershell
.\DialogCheck.ps1
```

端末全体の `ConfigureExternalRuns` だけを簡易確認する場合は、次を実行します。

```powershell
.\DisableExternalRunsCheck.ps1
```

### 3. 現在のユーザーの確認ダイアログを非表示にする

```powershell
.\DialogOff.ps1
```

この設定は、スクリプトを実行したWindowsユーザーにだけ適用されます。

設定内容：

```text
HKCU\SOFTWARE\Microsoft\Power Automate Desktop
EnableAskBeforeRunningAFlowExternally = 0
```

### 4. 現在のユーザーの確認ダイアログを既定状態へ戻す

```powershell
.\DialogOn.ps1
```

`EnableAskBeforeRunningAFlowExternally` を削除し、PADの既定動作へ戻します。

実行後、`ConfigureExternalRuns` の状態も確認し、次のいずれかを表示します。

- 管理者設定によって確認ダイアログが強制されている
- 管理者設定によって外部実行が禁止されている
- 端末全体の管理者設定は存在しない

### 5. 確認ダイアログを端末全体で強制表示する

管理者としてPowerShellを開いて実行します。

```powershell
.\DialogOnAdmin.ps1
```

設定内容：

```text
HKLM\SOFTWARE\Microsoft\Power Automate Desktop
ConfigureExternalRuns = 1
```

解除する場合は、管理者として次を実行します。

```powershell
.\DialogOffAdmin.ps1
```

`DialogOffAdmin.ps1` は、現在値が `1` の場合だけ削除します。現在値が `2` の場合は変更せず、`DisableExternalRunsOff.ps1` の使用を案内します。

### 6. 外部実行を端末全体で禁止する

管理者としてPowerShellを開いて実行します。

```powershell
.\DisableExternalRunsOn.ps1
```

設定内容：

```text
HKLM\SOFTWARE\Microsoft\Power Automate Desktop
ConfigureExternalRuns = 2
```

解除する場合は、管理者として次を実行します。

```powershell
.\DisableExternalRunsOff.ps1
```

`DisableExternalRunsOff.ps1` は、現在値が `2` の場合だけ削除します。現在値が `1` の場合は変更せず、`DialogOffAdmin.ps1` の使用を案内します。

## 使用例

### 現在のユーザーだけ確認ダイアログを非表示にする

```powershell
.\DialogCheck.ps1
.\DialogOff.ps1
.\DialogCheck.ps1
```

### 確認ダイアログを端末全体で強制表示する

```powershell
# 管理者として実行
.\DialogCheck.ps1
.\DialogOnAdmin.ps1
.\DialogCheck.ps1
```

### 端末全体の強制表示を解除する

```powershell
# 管理者として実行
.\DialogCheck.ps1
.\DialogOffAdmin.ps1
.\DialogCheck.ps1
```

### 外部実行を端末全体で禁止する

```powershell
# 管理者として実行
.\DisableExternalRunsCheck.ps1
.\DisableExternalRunsOn.ps1
.\DisableExternalRunsCheck.ps1
```

### 端末全体の外部実行禁止を解除する

```powershell
# 管理者として実行
.\DisableExternalRunsCheck.ps1
.\DisableExternalRunsOff.ps1
.\DisableExternalRunsCheck.ps1
```

## 推奨する操作手順

設定を変更するときは、変更前後に現在値を確認してください。

```powershell
# 変更前
.\DialogCheck.ps1

# 目的に合うスクリプトを実行
.\DialogOff.ps1

# 変更後
.\DialogCheck.ps1
```

管理者設定を解除するときは、現在の `ConfigureExternalRuns` の値に応じてスクリプトを選びます。

```text
ConfigureExternalRuns = 1 → DialogOffAdmin.ps1
ConfigureExternalRuns = 2 → DisableExternalRunsOff.ps1
```

## 実行ポリシーでブロックされる場合

最初にスクリプトの内容を確認してください。そのうえで、現在のPowerShellプロセスだけ実行ポリシーを変更して実行できます。

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\DialogCheck.ps1
```

PowerShellを閉じると、`Process` スコープの変更は失われます。

## 設定後の確認

設定変更後は、Power Automate for desktopを終了してから再起動してください。

確認対象は、PADコンソールの次の設定です。

```text
設定
└─ フローの実行制御
   └─ フローを外部から呼び出すときに確認ダイアログを表示する
```

## `DialogCheck.ps1` の判定内容

`DialogCheck.ps1` は、64ビットOSでは64ビットと32ビットの両方のレジストリ ビューを確認し、64ビット側の明示的な設定を優先して判定します。

判定順序は次のとおりです。

1. `HKLM` の `ConfigureExternalRuns = 1` または `2`
2. `HKCU` の `EnableAskBeforeRunningAFlowExternally`
3. レジストリに明示されていない場合はPADの設定画面または既定値

`EnableAskBeforeRunningAFlowExternally = 1` が見つかった場合は、確認ダイアログが有効である可能性を表示します。ただし、Microsoft Learnでは `0` の動作が明示されているため、実際のPAD設定画面でも確認するよう警告します。

## トラブルシューティング

### `Run PowerShell as Administrator.` と表示される

管理者設定を変更するスクリプトを、通常権限のPowerShellで実行しています。PowerShellを右クリックし、**管理者として実行**してください。

### `DialogOff.ps1` を実行しても確認ダイアログが表示される

`HKLM` の `ConfigureExternalRuns = 1` が設定されている可能性があります。

```powershell
.\DialogCheck.ps1
```

管理者設定が強制されている場合、ユーザー設定では変更できません。

### 実行 URLやショートカットからフローを起動できない

`HKLM` の `ConfigureExternalRuns = 2` が設定されている可能性があります。

```powershell
.\DisableExternalRunsCheck.ps1
```

解除する場合は、管理者として次を実行します。

```powershell
.\DisableExternalRunsOff.ps1
```

### 解除スクリプトを実行しても値が削除されない

解除対象と現在値が一致していない場合、スクリプトは安全のため値を削除しません。

```text
現在値が1 → DialogOffAdmin.ps1
現在値が2 → DisableExternalRunsOff.ps1
```

現在値は次のスクリプトで確認できます。

```powershell
.\DialogCheck.ps1
```

### 別のユーザーでは設定が反映されない

`DialogOff.ps1` と `DialogOn.ps1` は `HKCU` を変更するため、実行したWindowsユーザーだけが対象です。ユーザーごとに設定してください。

### 32ビット側に古い値が残っている

`DialogCheck.ps1` は、64ビットOSでは64ビット／32ビットの両方を一覧表示します。ただし、設定・解除用スクリプトは64ビットOSでは64ビットのレジストリ ビューを操作します。

過去に32ビットPowerShellや別の方法で設定した値が残っている場合は、一覧表示されたパスとビューを確認してください。

## セキュリティ上の注意

確認ダイアログを無効にすると、実行 URLやショートカットを開いた際に、ユーザーの追加確認なしでデスクトップ フローが実行される可能性があります。

- 信頼できないリンクやショートカットを開かないでください。
- 共有されたフローの作成者と処理内容を確認してください。
- 組織端末では、管理者による強制表示または外部実行禁止を検討してください。
- レジストリを変更する前に、必要に応じてバックアップを取得してください。

本スクリプトの利用によって発生した問題については、利用者の責任で対応してください。

## 参考資料

- [URL またはデスクトップ ショートカットでデスクトップ フローを実行する - Microsoft Learn](https://learn.microsoft.com/ja-jp/power-automate/desktop-flows/run-desktop-flows-url-shortcuts)
- [デスクトップ用 Power Automate のガバナンス - Microsoft Learn](https://learn.microsoft.com/ja-jp/power-automate/desktop-flows/governance)

## Author

- GitHub: [fulog](https://github.com/fulog)
- Blog: [fulog](https://www.fulogabc.net/)
