[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lexinexo-env.ps1')

$signingDirectory = Split-Path -Parent $env:LEXINEXO_KEY_PROPERTIES
$keystorePath = Join-Path $signingDirectory 'lexinexo-upload.jks'
$certificatePath = Join-Path $signingDirectory 'lexinexo-upload-certificate.pem'
$fingerprintsPath = Join-Path $signingDirectory 'lexinexo-upload-fingerprints.txt'
$readmePath = Join-Path $signingDirectory 'README.txt'
$alias = 'lexinexo-upload'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name

if ((Test-Path -LiteralPath $keystorePath) -or (Test-Path -LiteralPath $env:LEXINEXO_KEY_PROPERTIES)) {
    throw 'An upload keystore or signing properties file already exists. Refusing to overwrite it.'
}

New-Item -ItemType Directory -Force -Path $signingDirectory | Out-Null
& icacls.exe $signingDirectory '/inheritance:r' | Out-Null
& icacls.exe $signingDirectory '/grant:r' "${identity}:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to restrict the signing directory ACL.'
}

function New-RandomPassword {
    $bytes = [byte[]]::new(48)
    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $random.GetBytes($bytes)
    } finally {
        $random.Dispose()
    }
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

$storePassword = New-RandomPassword
$keyPassword = New-RandomPassword
$env:LEXINEXO_TEMP_STORE_PASSWORD = $storePassword
$env:LEXINEXO_TEMP_KEY_PASSWORD = $keyPassword
$keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
$createdFiles = @(
    $keystorePath,
    $env:LEXINEXO_KEY_PROPERTIES,
    $certificatePath,
    $fingerprintsPath,
    $readmePath
)

try {
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $keytool -genkeypair -v `
        -storetype JKS `
        -keystore $keystorePath `
        -alias $alias `
        -keyalg RSA `
        -keysize 4096 `
        -sigalg SHA256withRSA `
        -validity 10000 `
        -dname 'CN=LexiNexo Upload, OU=Release, O=LexiNexo, L=Sao Paulo, ST=SP, C=BR' `
        -storepass:env LEXINEXO_TEMP_STORE_PASSWORD `
        -keypass:env LEXINEXO_TEMP_KEY_PASSWORD *> $null
    $keytoolExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorActionPreference
    if ($keytoolExitCode -ne 0) {
        throw 'keytool failed to generate the upload key.'
    }

    $properties = @(
        '# LexiNexo release signing. Keep this file and the JKS private.',
        "storeFile=$($keystorePath.Replace('\', '/'))",
        "storePassword=$storePassword",
        "keyAlias=$alias",
        "keyPassword=$keyPassword"
    ) -join [Environment]::NewLine
    [IO.File]::WriteAllText(
        $env:LEXINEXO_KEY_PROPERTIES,
        $properties + [Environment]::NewLine,
        [Text.Encoding]::ASCII
    )

    $ErrorActionPreference = 'Continue'
    & $keytool -exportcert -rfc `
        -keystore $keystorePath `
        -alias $alias `
        -file $certificatePath `
        -storepass:env LEXINEXO_TEMP_STORE_PASSWORD *> $null
    $keytoolExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorActionPreference
    if ($keytoolExitCode -ne 0) {
        throw 'keytool failed to export the public certificate.'
    }

    $ErrorActionPreference = 'Continue'
    $certificateDetails = & $keytool -printcert -v -file $certificatePath 2>&1
    $keytoolExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorActionPreference
    if ($keytoolExitCode -ne 0) {
        throw 'keytool failed to read the public certificate.'
    }
    $selectedDetails =
        $certificateDetails |
        Select-String -Pattern 'Owner:|Issuer:|Serial number:|Valid from:|SHA1:|SHA256:|Signature algorithm name:|Subject Public Key Algorithm:' |
        ForEach-Object { $_.Line.Trim() }
    $metadataLines = @(
        'LexiNexo upload certificate (public information)',
        "Alias: $alias",
        'Keystore type: JKS',
        'Key algorithm: RSA 4096',
        'Signature algorithm: SHA256withRSA',
        "Generated (UTC): $([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))",
        ''
    ) + @($selectedDetails) + @(
        '',
        "JKS SHA-256: $((Get-FileHash -Algorithm SHA256 -LiteralPath $keystorePath).Hash)",
        "PEM SHA-256: $((Get-FileHash -Algorithm SHA256 -LiteralPath $certificatePath).Hash)"
    )
    $metadata = $metadataLines -join [Environment]::NewLine
    [IO.File]::WriteAllText(
        $fingerprintsPath,
        $metadata + [Environment]::NewLine,
        [Text.Encoding]::UTF8
    )

    $readme = @(
        'LEXINEXO UPLOAD KEY - PRIVATE RELEASE MATERIAL',
        '',
        'Back up lexinexo-upload.jks and keystore.properties in an encrypted password manager or offline encrypted volume.',
        'Never commit, email, or publish either private file.',
        'The PEM and fingerprints files contain public certificate information and may be supplied to Google Play.',
        'The project reads keystore.properties only through the LEXINEXO_KEY_PROPERTIES environment variable.',
        'Google Play App Signing should generate and protect the app-signing key; this JKS is the separate upload key.'
    ) -join [Environment]::NewLine
    [IO.File]::WriteAllText($readmePath, $readme + [Environment]::NewLine, [Text.Encoding]::UTF8)

    & icacls.exe $signingDirectory '/inheritance:r' | Out-Null
    & icacls.exe $signingDirectory '/grant:r' "${identity}:(OI)(CI)F" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to reapply the signing directory ACL.'
    }
} catch {
    foreach ($path in $createdFiles) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }
    throw
} finally {
    if ($null -ne $savedErrorActionPreference) {
        $ErrorActionPreference = $savedErrorActionPreference
    }
    Remove-Item Env:LEXINEXO_TEMP_STORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:LEXINEXO_TEMP_KEY_PASSWORD -ErrorAction SilentlyContinue
    $storePassword = $null
    $keyPassword = $null
}

Write-Host "Created upload key: $keystorePath"
Write-Host "Created public certificate: $certificatePath"
Write-Host "Created public fingerprints: $fingerprintsPath"
Write-Host 'Private passwords were not printed.'
