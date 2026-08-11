[CmdletBinding()]
param(
    [string]$Name = 'LexiNexo_API_36_16K',
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lexinexo-env.ps1')

$package = 'system-images;android-36;google_apis_ps16k;x86_64'
$androidCli = Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin\android.exe'
$avdManager = Join-Path $env:ANDROID_HOME 'cmdline-tools\latest\bin\avdmanager.bat'
$avdDirectory = Join-Path $env:ANDROID_AVD_HOME "$Name.avd"

if (!$SkipInstall) {
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $androidCli --no-metrics sdk install $package
    $androidCliExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorActionPreference
    if ($androidCliExitCode -ne 0) {
        throw "Failed to install $package."
    }
}

if (Test-Path -LiteralPath $avdDirectory) {
    Write-Host "AVD already exists: $Name"
} else {
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    'no' | & $avdManager create avd --name $Name --package $package --device pixel_6
    $avdManagerExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorActionPreference
    if ($avdManagerExitCode -ne 0) {
        throw "Failed to create AVD $Name."
    }
}

$configPath = Join-Path $avdDirectory 'config.ini'
$overrides = [ordered]@{
    'hw.gpu.enabled'  = 'yes'
    'hw.gpu.mode'     = 'swiftshader'
    'hw.keyboard'     = 'yes'
    'hw.ramSize'      = '2048'
    'showDeviceFrame' = 'no'
}
$configLines = @(Get-Content -LiteralPath $configPath)
foreach ($entry in $overrides.GetEnumerator()) {
    $keyPattern = '^' + [regex]::Escape($entry.Key) + '='
    $configLines = @($configLines | Where-Object { $_ -notmatch $keyPattern })
    $configLines += "$($entry.Key)=$($entry.Value)"
}
Set-Content -LiteralPath $configPath -Value $configLines -Encoding ASCII

Write-Host "16 KiB AVD ready on D: $Name"
Write-Host 'Launch it with a free explicit port, for example:'
Write-Host "  emulator -avd $Name -port 5564 -no-snapshot -no-boot-anim -no-window -gpu swiftshader -feature -Vulkan"
