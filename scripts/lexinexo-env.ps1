[CmdletBinding()]
param(
    [switch]$PersistUser
)

$ErrorActionPreference = 'Stop'

$toolchainRoot = 'D:\LexiNexoToolchain'
$releaseRoot = 'D:\LexiNexoRelease'
$projectRoot = Split-Path -Parent $PSScriptRoot
$environmentValues = [ordered]@{
    FLUTTER_ROOT              = "$toolchainRoot\flutter"
    JAVA_HOME                 = "$toolchainRoot\jdk-17"
    ANDROID_HOME              = "$toolchainRoot\android-sdk"
    ANDROID_SDK_ROOT          = "$toolchainRoot\android-sdk"
    ANDROID_USER_HOME         = "$toolchainRoot\android-user"
    ANDROID_AVD_HOME          = "$toolchainRoot\android-user\avd"
    GRADLE_USER_HOME          = "$toolchainRoot\gradle-cache"
    PUB_CACHE                 = "$toolchainRoot\pub-cache"
    GIT_CONFIG_GLOBAL         = "$toolchainRoot\gitconfig"
    JAVA_TOOL_OPTIONS         = '-Djava.io.tmpdir=D:/LexiNexoToolchain/temp'
    TEMP                      = "$toolchainRoot\temp"
    TMP                       = "$toolchainRoot\temp"
    LEXINEXO_KEY_PROPERTIES   = "$releaseRoot\signing\keystore.properties"
    BUNDLETOOL_JAR            = "$toolchainRoot\bundletool\bundletool-all-1.18.3.jar"
}

$requiredDirectories = @(
    $environmentValues.ANDROID_USER_HOME,
    $environmentValues.ANDROID_AVD_HOME,
    $environmentValues.GRADLE_USER_HOME,
    $environmentValues.PUB_CACHE,
    "$toolchainRoot\kotlin-project-cache",
    $environmentValues.TEMP,
    "$releaseRoot\signing"
)
foreach ($directory in $requiredDirectories) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

if (!(Test-Path -LiteralPath $environmentValues.GIT_CONFIG_GLOBAL -PathType Leaf)) {
    New-Item -ItemType File -Force -Path $environmentValues.GIT_CONFIG_GLOBAL | Out-Null
}

foreach ($entry in $environmentValues.GetEnumerator()) {
    Set-Item -Path "Env:$($entry.Key)" -Value $entry.Value
    if ($PersistUser) {
        $persistedValue = [Environment]::GetEnvironmentVariable($entry.Key, 'User')
        if ($persistedValue -ne $entry.Value) {
            [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'User')
        }
    }
}

$toolPaths = @(
    "$($environmentValues.FLUTTER_ROOT)\bin",
    "$($environmentValues.ANDROID_HOME)\platform-tools",
    "$($environmentValues.ANDROID_HOME)\emulator",
    "$($environmentValues.ANDROID_HOME)\cmdline-tools\latest\bin",
    "$($environmentValues.JAVA_HOME)\bin"
)
$currentPathParts = @($env:Path -split ';' | Where-Object { $_ })
$env:Path = (@($toolPaths) + @($currentPathParts | Where-Object { $_ -notin $toolPaths })) -join ';'

if ($PersistUser) {
    $userPathParts = @(
        [Environment]::GetEnvironmentVariable('Path', 'User') -split ';' |
            Where-Object { $_ }
    )
    $newUserPath = (@($toolPaths) + @($userPathParts | Where-Object { $_ -notin $toolPaths })) -join ';'
    if ([Environment]::GetEnvironmentVariable('Path', 'User') -ne $newUserPath) {
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
    }

}

$flutterSafeDirectory = 'D:/LexiNexoToolchain/flutter'
$configuredSafeDirectories = @(
    git config --file $environmentValues.GIT_CONFIG_GLOBAL --get-all safe.directory 2>$null
)
if ($configuredSafeDirectories -notcontains $flutterSafeDirectory) {
    git config --file $environmentValues.GIT_CONFIG_GLOBAL --add safe.directory $flutterSafeDirectory
}

$expectedLocalProperties = @(
    'sdk.dir=D:\\LexiNexoToolchain\\android-sdk',
    'flutter.sdk=D:\\LexiNexoToolchain\\flutter'
)
$localPropertiesPath = Join-Path $projectRoot 'android\local.properties'
$localProperties = Get-Content -LiteralPath $localPropertiesPath
foreach ($expectedLine in $expectedLocalProperties) {
    if ($localProperties -notcontains $expectedLine) {
        throw "Unexpected android/local.properties. Missing: $expectedLine"
    }
}

Write-Host 'LexiNexo environment loaded from D:.'
Write-Host "Project: $projectRoot"
Write-Host "Flutter: $($environmentValues.FLUTTER_ROOT)"
Write-Host "Android SDK: $($environmentValues.ANDROID_HOME)"
Write-Host "JDK: $($environmentValues.JAVA_HOME)"
Write-Host "Release signing properties: $($environmentValues.LEXINEXO_KEY_PROPERTIES)"
Write-Host "Bundletool: $($environmentValues.BUNDLETOOL_JAR)"
