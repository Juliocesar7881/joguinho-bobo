[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lexinexo-env.ps1')

if (!(Test-Path -LiteralPath $env:LEXINEXO_KEY_PROPERTIES -PathType Leaf)) {
    throw "Signing properties not found: $env:LEXINEXO_KEY_PROPERTIES"
}

$properties = @{}
foreach ($line in Get-Content -LiteralPath $env:LEXINEXO_KEY_PROPERTIES) {
    if ($line -match '^\s*([^#!][^=]*)=(.*)$') {
        $properties[$Matches[1].Trim()] = $Matches[2].Trim()
    }
}

foreach ($requiredKey in @('storeFile', 'storePassword', 'keyAlias', 'keyPassword')) {
    if (!$properties.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace($properties[$requiredKey])) {
        throw "Missing signing property: $requiredKey"
    }
}

if (!(Test-Path -LiteralPath $properties.storeFile -PathType Leaf)) {
    throw "Keystore not found: $($properties.storeFile)"
}

$env:LEXINEXO_TEMP_STORE_PASSWORD = $properties.storePassword
$env:LEXINEXO_TEMP_KEY_PASSWORD = $properties.keyPassword
try {
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $keytoolOutput = @(
        & (Join-Path $env:JAVA_HOME 'bin\keytool.exe') -list -v `
            -keystore $properties.storeFile `
            -storepass:env LEXINEXO_TEMP_STORE_PASSWORD `
            -alias $properties.keyAlias `
            -keypass:env LEXINEXO_TEMP_KEY_PASSWORD 2>&1
    )
    $keytoolExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorActionPreference
    if ($keytoolExitCode -ne 0) {
        throw 'The release keystore could not be verified.'
    }
    $keytoolOutput |
        Select-String -Pattern 'Alias name:|Creation date:|Entry type:|Certificate fingerprints:|SHA1:|SHA256:|Signature algorithm name:|Subject Public Key Algorithm:'
} finally {
    $ErrorActionPreference = $savedErrorActionPreference
    Remove-Item Env:LEXINEXO_TEMP_STORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:LEXINEXO_TEMP_KEY_PASSWORD -ErrorAction SilentlyContinue
}
