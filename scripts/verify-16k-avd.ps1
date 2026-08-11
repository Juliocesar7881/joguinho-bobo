[CmdletBinding()]
param(
    [string]$Name = 'LexiNexo_API_36_16K',
    [ValidateRange(5556, 5680)]
    [int]$Port = 5564,
    [switch]$WipeData,
    [switch]$KeepRunning
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lexinexo-env.ps1')

if (($Port % 2) -ne 0) {
    throw 'Android emulator console ports must be even.'
}

$emulator = Join-Path $env:ANDROID_HOME 'emulator\emulator.exe'
$adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
$serial = "emulator-$Port"
$avdDirectory = Join-Path $env:ANDROID_AVD_HOME "$Name.avd"
if (!(Test-Path -LiteralPath $avdDirectory -PathType Container)) {
    throw "AVD does not exist: $Name. Run scripts/create-16k-avd.ps1 first."
}

$alreadyRunning = [bool](@(& $adb devices) -match "^$([regex]::Escape($serial))\s+")
$launchedHere = !$alreadyRunning
if ($launchedHere) {
    $emulatorArguments = @(
        '-avd', $Name,
        '-port', $Port,
        '-no-snapshot',
        '-no-boot-anim',
        '-no-audio',
        '-no-window',
        '-gpu', 'swiftshader',
        '-feature', '-Vulkan'
    )
    if ($WipeData) {
        $emulatorArguments += '-wipe-data'
    }
    $logSuffix = Get-Date -Format 'yyyyMMdd-HHmmss'
    $stdoutLog = Join-Path $env:TEMP "lexinexo-16k-$logSuffix.stdout.log"
    $stderrLog = Join-Path $env:TEMP "lexinexo-16k-$logSuffix.stderr.log"
    Start-Process `
        -FilePath $emulator `
        -ArgumentList $emulatorArguments `
        -RedirectStandardOutput $stdoutLog `
        -RedirectStandardError $stderrLog `
        -WindowStyle Hidden | Out-Null
}

try {
    $deadline = (Get-Date).AddMinutes(12)
    do {
        Start-Sleep -Seconds 2
        $savedErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $stateOutput = @(& $adb -s $serial get-state 2>$null)
        $stateExitCode = $LASTEXITCODE
        $bootOutput = @(& $adb -s $serial shell getprop sys.boot_completed 2>$null)
        $bootExitCode = $LASTEXITCODE
        $ErrorActionPreference = $savedErrorActionPreference
        $state = if ($stateExitCode -eq 0) { (($stateOutput | Select-Object -Last 1) -join '').Trim() } else { '' }
        $bootCompleted = if ($bootExitCode -eq 0) { (($bootOutput | Select-Object -Last 1) -join '').Trim() } else { '' }
        if ($state -eq 'device' -and $bootCompleted -eq '1') {
            break
        }
    } while ((Get-Date) -lt $deadline)

    if ($state -ne 'device' -or $bootCompleted -ne '1') {
        $diagnosticSuffix = if ($launchedHere) { " Logs: $stdoutLog ; $stderrLog" } else { '' }
        throw "AVD $Name did not finish booting within twelve minutes.$diagnosticSuffix"
    }

    & $adb -s $serial shell svc wifi disable | Out-Null
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $adb -s $serial shell svc data disable 2>$null | Out-Null
    $ErrorActionPreference = $savedErrorActionPreference
    & $adb -s $serial shell settings put global mobile_data 0 | Out-Null

    $wifiStatus = (@(& $adb -s $serial shell cmd wifi status) -join "`n").Trim()
    if ($wifiStatus -notmatch '(?m)^Wifi is disabled$') {
        throw "Wi-Fi was not disabled on $serial. Status: $wifiStatus"
    }
    $mobileData = (& $adb -s $serial shell settings get global mobile_data).Trim()
    if ($mobileData -ne '0') {
        throw "Mobile data was not disabled on $serial. mobile_data=$mobileData"
    }

    $pageSize = (& $adb -s $serial shell getconf PAGE_SIZE).Trim()
    if ($pageSize -ne '16384') {
        throw "Expected PAGE_SIZE=16384, got PAGE_SIZE=$pageSize."
    }

    Write-Host "Verified $Name on ${serial}: PAGE_SIZE=16384, Wi-Fi/data disabled."
} finally {
    if ($launchedHere -and !$KeepRunning) {
        $savedErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $adb -s $serial emu kill | Out-Null
        $ErrorActionPreference = $savedErrorActionPreference
    }
}
