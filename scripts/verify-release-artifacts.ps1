[CmdletBinding()]
param(
    [string]$AabPath = 'build\app\outputs\bundle\release\app-release.aab',
    [string]$ApkPath = 'build\app\outputs\flutter-apk\app-release.apk'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lexinexo-env.ps1')

$projectRoot = Split-Path -Parent $PSScriptRoot
function Resolve-ArtifactPath {
    param([string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

$aab = Resolve-ArtifactPath $AabPath
$apk = Resolve-ArtifactPath $ApkPath
$buildTools = Join-Path $env:ANDROID_HOME 'build-tools\36.0.0'
$apksigner = Join-Path $buildTools 'apksigner.bat'
$aapt = Join-Path $buildTools 'aapt.exe'
$zipalign = Join-Path $buildTools 'zipalign.exe'
$java = Join-Path $env:JAVA_HOME 'bin\java.exe'
$jarsigner = Join-Path $env:JAVA_HOME 'bin\jarsigner.exe'
$keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
$bundletool = $env:BUNDLETOOL_JAR
$readelf = Join-Path $env:ANDROID_HOME 'ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readelf.exe'
$expectedCertificateSha256 = '5954661688063D35EF3392B7502F4622D1ED6F0A74FD638E466888CBC4787996'
$expectedAabSignatureBase = 'LEXINEXO'
$expectedInternalPermission = 'com.lexinexo.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'
$expectedApplicationLabel = 'PalavraX'
$androidNamespace = 'http://schemas.android.com/apk/res/android'
$expectedAbis = @('armeabi-v7a', 'arm64-v8a', 'x86_64')
$expectedElfMachines = @{
    'armeabi-v7a' = 'ARM'
    'arm64-v8a' = 'AArch64'
    'x86_64' = 'Advanced Micro Devices X86-64'
}

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (!$Condition) { throw $Message }
}

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    $savedErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $Program @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "Command failed ($exitCode): $Program $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)"
    }
    return $output
}

function Get-XmlPayload {
    param([object[]]$Output, [string]$RootElement)
    $text = ($Output | ForEach-Object { $_.ToString() }) -join "`n"
    $startToken = "<$RootElement"
    $endToken = "</$RootElement>"
    $start = $text.IndexOf($startToken, [StringComparison]::Ordinal)
    $end = $text.LastIndexOf($endToken, [StringComparison]::Ordinal)
    Assert-Condition ($start -ge 0 -and $end -ge $start) "Could not find $RootElement XML in command output."
    $length = $end + $endToken.Length - $start
    return $text.Substring($start, $length)
}

function Get-AndroidAttribute {
    param([System.Xml.XmlElement]$Element, [string]$Name)
    if ($null -eq $Element) { return '' }
    return $Element.GetAttribute($Name, $androidNamespace)
}

function Assert-FalseOrAbsentAndroidAttribute {
    param([System.Xml.XmlElement]$Element, [string]$Name, [string]$Message)
    $value = Get-AndroidAttribute $Element $Name
    Assert-Condition ($value -eq '' -or $value -eq 'false' -or $value -eq '0') $Message
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-ZipEntryNames {
    param([string]$Path)
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        return @($archive.Entries | ForEach-Object { $_.FullName })
    } finally {
        $archive.Dispose()
    }
}

foreach ($file in @($aab, $apk, $apksigner, $aapt, $zipalign, $java, $jarsigner, $keytool, $bundletool, $readelf)) {
    Assert-Condition (Test-Path -LiteralPath $file -PathType Leaf) "Required file not found: $file"
}

$aabEntries = Get-ZipEntryNames $aab
$aabSignatureFiles = @(
    foreach ($entryName in $aabEntries) {
        $signatureMatch = [regex]::Match(
            $entryName,
            '^(?i:META-INF)/(?<base>[^/]+)\.(?<extension>(?i:SF|RSA|DSA|EC))$'
        )
        if ($signatureMatch.Success) {
            [PSCustomObject]@{
                Entry = $entryName
                Base = $signatureMatch.Groups['base'].Value
                Extension = $signatureMatch.Groups['extension'].Value.ToUpperInvariant()
            }
        }
    }
)
$aabSignatureFilesSf = @($aabSignatureFiles | Where-Object { $_.Extension -eq 'SF' })
$aabSignatureFilesBlock = @($aabSignatureFiles | Where-Object { $_.Extension -ne 'SF' })
Assert-Condition ($aabSignatureFilesSf.Count -eq 1) 'AAB must contain exactly one META-INF signature .SF file.'
Assert-Condition ($aabSignatureFilesBlock.Count -eq 1) 'AAB must contain exactly one META-INF signature block.'
Assert-Condition ($aabSignatureFilesBlock[0].Extension -eq 'RSA') 'AAB upload-key signature block is not RSA.'
Assert-Condition ($aabSignatureFilesSf[0].Base -ieq $aabSignatureFilesBlock[0].Base) 'AAB META-INF signature files do not form one matching pair.'
Assert-Condition ($aabSignatureFilesSf[0].Base -ieq $expectedAabSignatureBase) 'AAB META-INF signature pair is not named for the LexiNexo upload key.'

$jarVerification = Invoke-Checked $jarsigner @('-J-Duser.language=en', '-verify', '-verbose', '-certs', $aab)
$jarVerificationText = $jarVerification -join "`n"
Assert-Condition ($jarVerificationText -match '(?i)jar verified') 'jarsigner did not verify the AAB.'
Assert-Condition ($jarVerificationText -notmatch '(?i)\bunsigned entries\b') 'jarsigner reported unsigned AAB entries.'
$aabCertificate = (Invoke-Checked $keytool @('-J-Duser.language=en', '-printcert', '-jarfile', $aab)) -join "`n"
$aabCertificateMatch = [regex]::Match($aabCertificate, 'SHA256:\s*([0-9A-Fa-f:]+)')
Assert-Condition $aabCertificateMatch.Success 'Could not read the AAB signing certificate SHA-256.'
$aabCertificateSha256 = $aabCertificateMatch.Groups[1].Value.Replace(':', '').ToUpperInvariant()
Assert-Condition ($aabCertificateSha256 -eq $expectedCertificateSha256) 'AAB is not signed by the LexiNexo upload key.'

$bundleValidation = Invoke-Checked $java @(
    '-jar', $bundletool, 'validate', "--bundle=$aab"
)
$bundleConfig = Invoke-Checked $java @(
    '-jar', $bundletool, 'dump', 'config', "--bundle=$aab"
)
$bundleConfigText = $bundleConfig -join "`n"
$bundleConfigStart = $bundleConfigText.IndexOf('{', [StringComparison]::Ordinal)
$bundleConfigEnd = $bundleConfigText.LastIndexOf('}', [StringComparison]::Ordinal)
Assert-Condition (
    $bundleConfigStart -ge 0 -and $bundleConfigEnd -ge $bundleConfigStart
) 'Could not find config JSON in bundletool output.'
$bundleConfigPayload = $bundleConfigText.Substring(
    $bundleConfigStart,
    $bundleConfigEnd - $bundleConfigStart + 1
)
try {
    $bundleConfigJson = $bundleConfigPayload | ConvertFrom-Json
} catch {
    throw "bundletool returned invalid config JSON: $($_.Exception.Message)"
}
$pageAlignment =
    $bundleConfigJson.optimizations.uncompressNativeLibraries.alignment
Assert-Condition (
    $pageAlignment -is [string] -and $pageAlignment -ceq 'PAGE_ALIGNMENT_16K'
) 'AAB native-library alignment is not exactly PAGE_ALIGNMENT_16K.'

$bundleManifestOutput = Invoke-Checked $java @(
    '-jar', $bundletool, 'dump', 'manifest', "--bundle=$aab", '--module=base'
)
$bundleManifestPayload = Get-XmlPayload $bundleManifestOutput 'manifest'
try {
    [xml]$bundleManifestXml = $bundleManifestPayload
} catch {
    throw "bundletool returned invalid manifest XML: $($_.Exception.Message)"
}
$bundleManifest = $bundleManifestXml.DocumentElement
Assert-Condition ($bundleManifest.GetAttribute('package') -eq 'com.lexinexo.app') 'AAB package name is incorrect.'
Assert-Condition ((Get-AndroidAttribute $bundleManifest 'versionCode') -eq '1') 'AAB versionCode is not 1.'
Assert-Condition ((Get-AndroidAttribute $bundleManifest 'versionName') -eq '1.0.0') 'AAB versionName is not 1.0.0.'
Assert-Condition ((Get-AndroidAttribute $bundleManifest 'compileSdkVersion') -eq '36') 'AAB compileSdk is not 36.'

$bundleUsesSdk = $bundleManifest.SelectSingleNode('./uses-sdk')
Assert-Condition ($null -ne $bundleUsesSdk) 'AAB manifest does not declare uses-sdk.'
Assert-Condition ((Get-AndroidAttribute $bundleUsesSdk 'minSdkVersion') -eq '24') 'AAB minSdk is not 24.'
Assert-Condition ((Get-AndroidAttribute $bundleUsesSdk 'targetSdkVersion') -eq '36') 'AAB targetSdk is not 36.'

$bundleApplication = $bundleManifest.SelectSingleNode('./application')
Assert-Condition ($null -ne $bundleApplication) 'AAB manifest does not declare application.'
Assert-Condition ((Get-AndroidAttribute $bundleApplication 'label') -eq $expectedApplicationLabel) 'AAB application label is not PalavraX.'
$allowBackup = Get-AndroidAttribute $bundleApplication 'allowBackup'
Assert-Condition ($allowBackup -eq 'false' -or $allowBackup -eq '0') 'AAB application does not explicitly set allowBackup=false.'
Assert-FalseOrAbsentAndroidAttribute $bundleApplication 'debuggable' 'AAB application is debuggable.'
Assert-FalseOrAbsentAndroidAttribute $bundleApplication 'testOnly' 'AAB application is testOnly.'
Assert-FalseOrAbsentAndroidAttribute $bundleManifest 'testOnly' 'AAB manifest is testOnly.'

$bundleMainActivity = @(
    $bundleApplication.SelectNodes('./activity') |
        Where-Object {
            $activityName = Get-AndroidAttribute $_ 'name'
            $activityName -eq '.MainActivity' -or $activityName -eq 'com.lexinexo.app.MainActivity'
        }
) | Select-Object -First 1
Assert-Condition ($null -ne $bundleMainActivity) 'AAB does not contain the LexiNexo MainActivity.'
$bundleOrientation = Get-AndroidAttribute $bundleMainActivity 'screenOrientation'
Assert-Condition ($bundleOrientation -eq 'portrait' -or $bundleOrientation -eq '1') 'AAB MainActivity is not locked to portrait.'

$bundleUsesPermissions = @($bundleManifest.SelectNodes("./*[starts-with(local-name(), 'uses-permission')]"))
Assert-Condition ($bundleUsesPermissions.Count -eq 1) 'AAB must request exactly the allowlisted AndroidX internal permission.'
$bundleUsesPermissionName = Get-AndroidAttribute $bundleUsesPermissions[0] 'name'
Assert-Condition ($bundleUsesPermissionName -eq $expectedInternalPermission) "AAB requests a non-allowlisted permission: $bundleUsesPermissionName"
$bundleDeclaredPermissions = @($bundleManifest.SelectNodes('./permission'))
Assert-Condition ($bundleDeclaredPermissions.Count -eq 1) 'AAB must declare exactly one internal signature permission.'
$bundleDeclaredPermissionName = Get-AndroidAttribute $bundleDeclaredPermissions[0] 'name'
$bundleProtectionLevel = Get-AndroidAttribute $bundleDeclaredPermissions[0] 'protectionLevel'
Assert-Condition ($bundleDeclaredPermissionName -eq $expectedInternalPermission) "AAB declares an unexpected permission: $bundleDeclaredPermissionName"
Assert-Condition ($bundleProtectionLevel -match '^(?i:signature|2|0x0*2)$') 'AAB internal permission is not protected at signature level.'

$signerOutput = Invoke-Checked $apksigner @('verify', '--verbose', '--print-certs', $apk)
$signerText = $signerOutput -join "`n"
$apkCertificateMatches = [regex]::Matches(
    $signerText,
    '(?im)^Signer #(?<number>\d+) certificate SHA-256 digest:\s*(?<digest>[0-9a-f]+)\s*$'
)
Assert-Condition ($apkCertificateMatches.Count -eq 1) 'APK must contain exactly one signer certificate SHA-256 digest.'
Assert-Condition ($apkCertificateMatches[0].Groups['number'].Value -eq '1') 'APK signer numbering is invalid.'
$actualCertificateSha256 = $apkCertificateMatches[0].Groups['digest'].Value.ToUpperInvariant()
Assert-Condition ($actualCertificateSha256 -eq $expectedCertificateSha256) 'APK is not signed by the LexiNexo upload key.'
Assert-Condition ($signerText -match 'Verified using v2 scheme.*true') 'APK v2 signature is missing.'

$badging = (Invoke-Checked $aapt @('dump', 'badging', $apk)) -join "`n"
Assert-Condition ($badging -match "package: name='com\.lexinexo\.app' versionCode='1' versionName='1\.0\.0'") 'Package name or version is incorrect.'
Assert-Condition ($badging -match "sdkVersion:'24'") 'minSdk is not 24.'
Assert-Condition ($badging -match "targetSdkVersion:'36'") 'targetSdk is not 36.'
Assert-Condition ($badging -match "compileSdkVersion='36'") 'APK compileSdk is not 36.'
Assert-Condition ($badging -match "(?m)^application-label:'PalavraX'") 'APK application label is not PalavraX.'
Assert-Condition ($badging -notmatch '(?m)^application-debuggable') 'APK is debuggable.'

$apkManifestTree = (Invoke-Checked $aapt @('dump', 'xmltree', $apk, 'AndroidManifest.xml')) -join "`n"
Assert-Condition ($apkManifestTree -match 'A: package="com\.lexinexo\.app"') 'APK manifest package name is incorrect.'
Assert-Condition ($apkManifestTree -match 'android:versionCode[^\r\n]*0x1(?:\s|$)') 'APK manifest versionCode is not 1.'
Assert-Condition ($apkManifestTree -match 'android:versionName[^\r\n]*"1\.0\.0"') 'APK manifest versionName is not 1.0.0.'
Assert-Condition ($apkManifestTree -match 'android:compileSdkVersion[^\r\n]*0x24(?:\s|$)') 'APK manifest compileSdk is not 36.'
Assert-Condition ($apkManifestTree -match 'android:minSdkVersion[^\r\n]*0x18(?:\s|$)') 'APK manifest minSdk is not 24.'
Assert-Condition ($apkManifestTree -match 'android:targetSdkVersion[^\r\n]*0x24(?:\s|$)') 'APK manifest targetSdk is not 36.'
Assert-Condition ($apkManifestTree -match 'android:allowBackup[^\r\n]*0x0(?:\s|$)') 'APK application does not explicitly set allowBackup=false.'

$apkActivityBlocks = [regex]::Matches(
    $apkManifestTree,
    '(?ms)^[ ]{6}E: activity(?:[ \t]|\().*?(?=^[ ]{6}E: |\z)'
)
$apkMainActivityBlocks = @(
    $apkActivityBlocks |
        Where-Object {
            $_.Value -match 'android:name[^\r\n]*"(?:com\.lexinexo\.app\.)?MainActivity"'
        }
)
Assert-Condition ($apkMainActivityBlocks.Count -eq 1) 'APK does not contain exactly one LexiNexo MainActivity.'
Assert-Condition ($apkMainActivityBlocks[0].Value -match 'android:screenOrientation[^\r\n]*0x1(?:\s|$)') 'APK MainActivity is not locked to portrait.'

foreach ($attributeName in @('debuggable', 'testOnly')) {
    $attributeMatches = [regex]::Matches($apkManifestTree, "(?m)^\s+A: android:$attributeName[^\r\n]*$")
    foreach ($attributeMatch in $attributeMatches) {
        Assert-Condition ($attributeMatch.Value -match '0x0(?:\s|$)') "APK manifest sets android:$attributeName to true."
    }
}

$permissions = (Invoke-Checked $aapt @('dump', 'permissions', $apk)) -join "`n"
$apkUsesPermissionLines = [regex]::Matches($permissions, '(?m)^uses-permission(?:-[^:\r\n]+)?:[^\r\n]*$')
Assert-Condition ($apkUsesPermissionLines.Count -eq 1) 'APK must request exactly the allowlisted AndroidX internal permission.'
$apkUsesPermissionMatch = [regex]::Match(
    $apkUsesPermissionLines[0].Value,
    "^uses-permission(?:-sdk-\d+)?: name='([^']+)'\s*$"
)
Assert-Condition $apkUsesPermissionMatch.Success 'APK uses an unsupported uses-permission declaration.'
$apkUsesPermissionName = $apkUsesPermissionMatch.Groups[1].Value
Assert-Condition ($apkUsesPermissionName -eq $expectedInternalPermission) "APK requests a non-allowlisted permission: $apkUsesPermissionName"
Assert-Condition ($permissions -notmatch 'android\.permission\.INTERNET') 'Release APK requests INTERNET.'

$apkPermissionBlocks = [regex]::Matches(
    $apkManifestTree,
    '(?ms)^[ ]{4}E: permission(?:[ \t]|\().*?(?=^[ ]{4}E: |\z)'
)
Assert-Condition ($apkPermissionBlocks.Count -eq 1) 'APK must declare exactly one internal signature permission.'
$apkPermissionBlock = $apkPermissionBlocks[0].Value
Assert-Condition ($apkPermissionBlock -match [regex]::Escape($expectedInternalPermission)) 'APK declares an unexpected internal permission.'
Assert-Condition ($apkPermissionBlock -match 'android:protectionLevel[^\r\n]*0x2(?:\s|$)') 'APK internal permission is not protected at signature level.'

Invoke-Checked $zipalign @('-c', '-P', '16', '-v', '4', $apk) | Out-Null

$apkEntries = Get-ZipEntryNames $apk
foreach ($abi in $expectedAbis) {
    foreach ($library in @('libapp.so', 'libflutter.so')) {
        $apkEntry = "lib/$abi/$library"
        $aabEntry = "base/lib/$abi/$library"
        Assert-Condition ($apkEntries -contains $apkEntry) "Universal APK is missing $apkEntry."
        Assert-Condition ($aabEntries -contains $aabEntry) "AAB is missing $aabEntry."
    }
}

$tempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$elfRoot = Join-Path $tempRoot ("lexinexo-elf-" + [Guid]::NewGuid().ToString('N'))
Assert-Condition ([IO.Path]::GetFullPath($elfRoot).StartsWith($tempRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Unsafe ELF temporary path.'
New-Item -ItemType Directory -Path $elfRoot | Out-Null
try {
    $elfCounts = [ordered]@{}
    foreach ($archiveSpec in @(
        [PSCustomObject]@{
            Label = 'APK'
            Path = $apk
            AbiPattern = '^lib/(?<abi>[^/]+)(?:/|$)'
            AdditionalAbiPattern = $null
            NativePrefix = 'lib'
        },
        [PSCustomObject]@{
            Label = 'AAB'
            Path = $aab
            AbiPattern = '^[^/]+/lib/(?<abi>[^/]+)(?:/|$)'
            AdditionalAbiPattern = '^BUNDLE-METADATA/com\.android\.tools\.build\.debugsymbols/(?<abi>[^/]+)(?:/|$)'
            NativePrefix = 'base/lib'
        }
    )) {
        $archive = [IO.Compression.ZipFile]::OpenRead($archiveSpec.Path)
        try {
            $elfEntryNames = @()
            $elfIndex = 0
            foreach ($entry in $archive.Entries) {
                $abiPathMatch = [regex]::Match($entry.FullName, $archiveSpec.AbiPattern)
                if (!$abiPathMatch.Success -and $null -ne $archiveSpec.AdditionalAbiPattern) {
                    $abiPathMatch = [regex]::Match(
                        $entry.FullName,
                        $archiveSpec.AdditionalAbiPattern
                    )
                }
                if ($abiPathMatch.Success) {
                    $pathAbi = $abiPathMatch.Groups['abi'].Value
                    Assert-Condition ($expectedAbis -contains $pathAbi) "$($archiveSpec.Label) contains unexpected ABI directory: $pathAbi"
                }

                if ($entry.FullName.EndsWith('/') -or $entry.Length -lt 4) {
                    continue
                }

                $input = $entry.Open()
                $magic = New-Object byte[] 4
                try {
                    $magicBytesRead = 0
                    while ($magicBytesRead -lt 4) {
                        $bytesRead = $input.Read($magic, $magicBytesRead, 4 - $magicBytesRead)
                        if ($bytesRead -eq 0) { break }
                        $magicBytesRead += $bytesRead
                    }
                    $isElf =
                        $magicBytesRead -eq 4 -and
                        $magic[0] -eq 0x7F -and
                        $magic[1] -eq 0x45 -and
                        $magic[2] -eq 0x4C -and
                        $magic[3] -eq 0x46
                    if (!$isElf) {
                        continue
                    }

                    Assert-Condition $abiPathMatch.Success "ELF entry is outside an ABI-native path in $($archiveSpec.Label): $($entry.FullName)"
                    $abi = $abiPathMatch.Groups['abi'].Value
                    Assert-Condition ($expectedAbis -contains $abi) "$($archiveSpec.Label) ELF uses unexpected ABI: $abi ($($entry.FullName))"

                    $elfIndex++
                    $elfEntryNames += $entry.FullName
                    $safeEntryName = $entry.FullName -replace '[^A-Za-z0-9._-]', '_'
                    $destination = Join-Path $elfRoot "$($archiveSpec.Label)-$elfIndex-$safeEntryName"
                    $output = [IO.File]::Create($destination)
                    try {
                        $output.Write($magic, 0, 4)
                        $input.CopyTo($output)
                    } finally {
                        $output.Dispose()
                    }
                } finally {
                    $input.Dispose()
                }

                $elfDetails = Invoke-Checked $readelf @('-hW', '-lW', $destination)
                $elfDetailsText = $elfDetails -join "`n"
                $machineMatches = [regex]::Matches($elfDetailsText, '(?im)^\s*Machine:\s*(?<machine>.+?)\s*$')
                Assert-Condition ($machineMatches.Count -eq 1) "Could not read exactly one ELF Machine in $($archiveSpec.Label) $($entry.FullName)."
                $actualMachine = $machineMatches[0].Groups['machine'].Value
                $expectedMachine = $expectedElfMachines[$abi]
                Assert-Condition ($actualMachine -ceq $expectedMachine) "ELF Machine/path mismatch in $($archiveSpec.Label) $($entry.FullName): ABI $abi requires $expectedMachine, found $actualMachine."

                $loadLines = @($elfDetails | Where-Object { $_ -match '^\s*LOAD\s' })
                Assert-Condition ($loadLines.Count -gt 0) "No LOAD segments found in $($archiveSpec.Label) $($entry.FullName)."
                foreach ($line in $loadLines) {
                    $alignmentMatch = [regex]::Match($line, '0x([0-9a-fA-F]+)\s*$')
                    Assert-Condition $alignmentMatch.Success "Could not read ELF alignment in $($archiveSpec.Label) $($entry.FullName)."
                    $alignment = [Convert]::ToInt64($alignmentMatch.Groups[1].Value, 16)
                    Assert-Condition ($alignment -ge 16384) "ELF LOAD alignment below 16 KiB in $($archiveSpec.Label) $($entry.FullName): $line"
                }
            }

            Assert-Condition ($elfEntryNames.Count -gt 0) "No ELF entries found by magic bytes in $($archiveSpec.Label)."
            foreach ($abi in $expectedAbis) {
                foreach ($library in @('libapp.so', 'libflutter.so')) {
                    $requiredElfEntry = "$($archiveSpec.NativePrefix)/$abi/$library"
                    Assert-Condition ($elfEntryNames -contains $requiredElfEntry) "$($archiveSpec.Label) required library is not an ELF file: $requiredElfEntry"
                }
            }
            $elfCounts[$archiveSpec.Label] = $elfEntryNames.Count
        } finally {
            $archive.Dispose()
        }
    }
} finally {
    $resolvedElfRoot = [IO.Path]::GetFullPath($elfRoot)
    if ($resolvedElfRoot.StartsWith($tempRoot + '\', [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedElfRoot)) {
        Remove-Item -LiteralPath $resolvedElfRoot -Recurse -Force
    }
}

$aabItem = Get-Item -LiteralPath $aab
$apkItem = Get-Item -LiteralPath $apk
$aabHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $aab).Hash
$apkHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $apk).Hash

Write-Output 'PalavraX release artifacts verified.'
Write-Output "AAB bytes: $($aabItem.Length)"
Write-Output "AAB SHA-256: $aabHash"
Write-Output "APK bytes: $($apkItem.Length)"
Write-Output "APK SHA-256: $apkHash"
Write-Output "Upload certificate SHA-256: $actualCertificateSha256"
Write-Output "Allowlisted internal signature permission: $expectedInternalPermission"
Write-Output "ELF files checked in APK: $($elfCounts['APK'])"
Write-Output "ELF files checked in AAB: $($elfCounts['AAB'])"
