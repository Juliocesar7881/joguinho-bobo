[CmdletBinding()]
param(
  [string]$OutputRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'dist'),
  [switch]$IncludeFinalHostedPages
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$packageName = 'Worde-1.0.0-google-play'
$destination = Join-Path $OutputRoot $packageName
$zipPath = Join-Path $OutputRoot "$packageName.zip"

function Assert-File {
  param([string]$Path, [string]$Description)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "$Description ausente: $Path"
  }
}

function Assert-Condition {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) {
    throw $Message
  }
}

function Assert-ExactProperties {
  param(
    [object]$Value,
    [string[]]$Expected,
    [string]$Description
  )
  Assert-Condition ($null -ne $Value) "$Description ausente."
  $actual = @($Value.PSObject.Properties.Name)
  $missing = @($Expected | Where-Object { $actual -cnotcontains $_ })
  $unknown = @($actual | Where-Object { $Expected -cnotcontains $_ })
  if ($missing.Count -gt 0 -or $unknown.Count -gt 0) {
    throw "$Description possui campos invalidos. Ausentes: $($missing -join ', '); desconhecidos: $($unknown -join ', ')."
  }
}

function Assert-Sha256 {
  param([object]$Value, [string]$Description)
  Assert-Condition (
    $Value -is [string] -and $Value -cmatch '^[0-9A-F]{64}$'
  ) "$Description deve ser um SHA-256 hexadecimal maiusculo."
}

function Resolve-ProjectFile {
  param([string]$RelativePath)
  Join-Path $projectRoot ($RelativePath.Replace('/', '\'))
}

function Copy-OneFile {
  param([string]$Source, [string]$RelativeDestination)
  Assert-File $Source $RelativeDestination
  $target = Join-Path $destination ($RelativeDestination.Replace('/', '\'))
  $targetDirectory = Split-Path $target -Parent
  [void](New-Item -ItemType Directory -Force -Path $targetDirectory)
  Copy-Item -LiteralPath $Source -Destination $target -Force
}

$artifactManifestPath = Join-Path $PSScriptRoot 'RELEASE_ARTIFACTS.json'
Assert-File $artifactManifestPath 'Manifesto de artefatos'
try {
  $artifactManifest = Get-Content -Raw -Encoding utf8 $artifactManifestPath |
    ConvertFrom-Json
} catch {
  throw "Manifesto de artefatos nao e JSON valido: $($_.Exception.Message)"
}

Assert-ExactProperties $artifactManifest @(
  'schemaVersion',
  'packageName',
  'versionName',
  'versionCode',
  'artifacts',
  'uploadCertificate',
  'publicFingerprintFile'
) 'Manifesto de artefatos'
Assert-Condition ($artifactManifest.schemaVersion -is [int] -and
  $artifactManifest.schemaVersion -eq 1) 'schemaVersion do manifesto deve ser exatamente 1.'
Assert-Condition ($artifactManifest.packageName -ceq 'worde.com') 'packageName do manifesto e invalido.'
Assert-Condition ($artifactManifest.versionName -ceq '1.0.0') 'versionName do manifesto e invalido.'
Assert-Condition ($artifactManifest.versionCode -is [int] -and
  $artifactManifest.versionCode -eq 1) 'versionCode do manifesto deve ser exatamente 1.'

$expectedArtifacts = [ordered]@{
  google_play_upload = [ordered]@{
    path = 'build/app/outputs/bundle/release/app-release.aab'
    packagePath = 'release/app-release.aab'
    fileName = 'app-release.aab'
  }
  direct_install_and_qa = [ordered]@{
    path = 'build/app/outputs/flutter-apk/app-release.apk'
    packagePath = 'qa/app-release.apk'
    fileName = 'app-release.apk'
  }
}
$manifestArtifacts = @($artifactManifest.artifacts)
Assert-Condition ($manifestArtifacts.Count -eq 2) 'O manifesto deve conter exatamente AAB e APK.'
$artifactsByPurpose = @{}

foreach ($artifact in $manifestArtifacts) {
  Assert-ExactProperties $artifact @(
    'purpose', 'path', 'packagePath', 'fileName', 'bytes', 'sha256'
  ) 'Registro de artefato'
  Assert-Condition ($artifact.purpose -is [string] -and
    $expectedArtifacts.Contains([string]$artifact.purpose)) "Finalidade de artefato desconhecida: $($artifact.purpose)"
  Assert-Condition (-not $artifactsByPurpose.ContainsKey([string]$artifact.purpose)) "Finalidade de artefato duplicada: $($artifact.purpose)"
  $expectedArtifact = $expectedArtifacts[[string]$artifact.purpose]
  Assert-Condition ($artifact.path -ceq $expectedArtifact.path) "Caminho-fonte incorreto para $($artifact.purpose)."
  Assert-Condition ($artifact.packagePath -ceq $expectedArtifact.packagePath) "Caminho interno incorreto para $($artifact.purpose)."
  Assert-Condition ($artifact.fileName -ceq $expectedArtifact.fileName) "Nome de arquivo incorreto para $($artifact.purpose)."
  Assert-Condition ($artifact.bytes -is [long] -or $artifact.bytes -is [int]) "bytes invalido para $($artifact.purpose)."
  Assert-Condition ([int64]$artifact.bytes -gt 0) "bytes deve ser positivo para $($artifact.purpose)."
  Assert-Sha256 $artifact.sha256 "Hash de $($artifact.purpose)"
  $artifactsByPurpose[[string]$artifact.purpose] = $artifact
}

foreach ($purpose in $expectedArtifacts.Keys) {
  Assert-Condition $artifactsByPurpose.ContainsKey($purpose) "Artefato obrigatorio ausente: $purpose"
}

foreach ($artifact in $manifestArtifacts) {
  $artifactPath = Resolve-ProjectFile $artifact.path
  Assert-File $artifactPath $artifact.purpose
  $item = Get-Item -LiteralPath $artifactPath
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifactPath).Hash
  if ($item.Length -ne [int64]$artifact.bytes -or $hash -cne [string]$artifact.sha256) {
    throw "Artefato divergente do manifesto: $artifactPath"
  }
}

Assert-ExactProperties $artifactManifest.uploadCertificate @(
  'sourcePath',
  'packagePath',
  'fileName',
  'bytes',
  'sha256',
  'sha1Fingerprint',
  'sha256Fingerprint'
) 'Certificado da upload key'
Assert-Condition ($artifactManifest.uploadCertificate.packagePath -ceq
  'signing-public/upload-certificate.pem') 'Caminho interno do certificado e invalido.'
Assert-Condition ($artifactManifest.uploadCertificate.fileName -ceq
  'upload-certificate.pem') 'Nome interno do certificado e invalido.'
Assert-Condition ($artifactManifest.uploadCertificate.bytes -is [long] -or
  $artifactManifest.uploadCertificate.bytes -is [int]) 'bytes do certificado e invalido.'
Assert-Condition ([int64]$artifactManifest.uploadCertificate.bytes -gt 0) 'bytes do certificado deve ser positivo.'
Assert-Sha256 $artifactManifest.uploadCertificate.sha256 'Hash do certificado'
Assert-Condition ($artifactManifest.uploadCertificate.sha1Fingerprint -is [string] -and
  $artifactManifest.uploadCertificate.sha1Fingerprint -cmatch '^([0-9A-F]{2}:){19}[0-9A-F]{2}$') 'Fingerprint SHA-1 do certificado e invalido.'
Assert-Condition ($artifactManifest.uploadCertificate.sha256Fingerprint -is [string] -and
  $artifactManifest.uploadCertificate.sha256Fingerprint -cmatch '^([0-9A-F]{2}:){31}[0-9A-F]{2}$') 'Fingerprint SHA-256 do certificado e invalido.'

$certificatePath = [string]$artifactManifest.uploadCertificate.sourcePath
Assert-File $certificatePath 'Certificado publico da upload key'
if ((Get-Item -LiteralPath $certificatePath).Length -ne
    [int64]$artifactManifest.uploadCertificate.bytes -or
    (Get-FileHash -Algorithm SHA256 -LiteralPath $certificatePath).Hash -cne
    [string]$artifactManifest.uploadCertificate.sha256) {
  throw 'O certificado publico nao corresponde ao hash aprovado.'
}

Assert-ExactProperties $artifactManifest.publicFingerprintFile @(
  'sourcePath', 'packagePath', 'fileName', 'bytes', 'sha256'
) 'Arquivo publico de fingerprints'
Assert-Condition ($artifactManifest.publicFingerprintFile.packagePath -ceq
  'signing-public/upload-key-fingerprints.txt') 'Caminho interno do arquivo de fingerprints e invalido.'
Assert-Condition ($artifactManifest.publicFingerprintFile.fileName -ceq
  'upload-key-fingerprints.txt') 'Nome interno do arquivo de fingerprints e invalido.'
Assert-Condition ($artifactManifest.publicFingerprintFile.bytes -is [long] -or
  $artifactManifest.publicFingerprintFile.bytes -is [int]) 'bytes do arquivo de fingerprints e invalido.'
Assert-Condition ([int64]$artifactManifest.publicFingerprintFile.bytes -gt 0) 'bytes do arquivo de fingerprints deve ser positivo.'
Assert-Sha256 $artifactManifest.publicFingerprintFile.sha256 'Hash do arquivo de fingerprints'
$fingerprintsPath = [string]$artifactManifest.publicFingerprintFile.sourcePath
Assert-File $fingerprintsPath 'Fingerprints publicos da upload key'
if ((Get-Item -LiteralPath $fingerprintsPath).Length -ne
    [int64]$artifactManifest.publicFingerprintFile.bytes -or
    (Get-FileHash -Algorithm SHA256 -LiteralPath $fingerprintsPath).Hash -cne
    [string]$artifactManifest.publicFingerprintFile.sha256) {
  throw 'O arquivo de fingerprints nao corresponde ao hash aprovado.'
}

$aabArtifact = $artifactsByPurpose['google_play_upload']
$apkArtifact = $artifactsByPurpose['direct_install_and_qa']
$aabPath = Resolve-ProjectFile $aabArtifact.path
$apkPath = Resolve-ProjectFile $apkArtifact.path
$releaseVerifier = Resolve-ProjectFile 'scripts/verify-release-artifacts.ps1'
Assert-File $releaseVerifier 'Verificador de release'
& $releaseVerifier -AabPath $aabPath -ApkPath $apkPath

$keytoolPath = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
Assert-File $keytoolPath 'keytool do JDK fixado'
$savedErrorActionPreference = $ErrorActionPreference
try {
  $ErrorActionPreference = 'Continue'
  $certificateDetails = @(
    & $keytoolPath '-J-Duser.language=en' '-printcert' '-file' $certificatePath 2>&1
  ) -join "`n"
  $keytoolExitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $savedErrorActionPreference
}
Assert-Condition ($keytoolExitCode -eq 0) "keytool nao conseguiu validar o certificado publico:`n$certificateDetails"
$sha1Match = [regex]::Match($certificateDetails, '(?im)^\s*SHA1:\s*([0-9A-F:]+)\s*$')
$sha256Match = [regex]::Match($certificateDetails, '(?im)^\s*SHA256:\s*([0-9A-F:]+)\s*$')
Assert-Condition $sha1Match.Success 'keytool nao retornou o fingerprint SHA-1 do certificado.'
Assert-Condition $sha256Match.Success 'keytool nao retornou o fingerprint SHA-256 do certificado.'
Assert-Condition ($sha1Match.Groups[1].Value -ceq
  [string]$artifactManifest.uploadCertificate.sha1Fingerprint) 'Fingerprint SHA-1 nao pertence ao certificado publico.'
Assert-Condition ($sha256Match.Groups[1].Value -ceq
  [string]$artifactManifest.uploadCertificate.sha256Fingerprint) 'Fingerprint SHA-256 nao pertence ao certificado publico.'

$fingerprintContents = Get-Content -Raw -Encoding utf8 $fingerprintsPath
Assert-Condition ($fingerprintContents -match "(?m)^SHA1:\s*$([regex]::Escape([string]$artifactManifest.uploadCertificate.sha1Fingerprint))\s*$") 'Arquivo de fingerprints nao contem o SHA-1 aprovado.'
Assert-Condition ($fingerprintContents -match "(?m)^SHA256:\s*$([regex]::Escape([string]$artifactManifest.uploadCertificate.sha256Fingerprint))\s*$") 'Arquivo de fingerprints nao contem o SHA-256 aprovado.'
Assert-Condition ($fingerprintContents -match "(?m)^PEM SHA-256:\s*$([regex]::Escape([string]$artifactManifest.uploadCertificate.sha256))\s*$") 'Arquivo de fingerprints nao contem o hash do PEM aprovado.'

& (Join-Path $PSScriptRoot 'validate_static_kit.ps1')

if ($IncludeFinalHostedPages) {
  $metadataPath = Join-Path $PSScriptRoot 'publication_metadata.json'
  $generatedPagesPath = Join-Path $PSScriptRoot 'generated_publication'
  Assert-File $metadataPath 'Metadados publicos finais'
  & (Join-Path $PSScriptRoot 'prepare_publication.ps1') `
    -MetadataPath $metadataPath `
    -OutputDirectory $generatedPagesPath
  & (Join-Path $PSScriptRoot 'validate_publication.ps1') `
    -MetadataPath $metadataPath `
    -GeneratedPagesDirectory $generatedPagesPath
}

if (Test-Path -LiteralPath $destination) {
  $resolvedOutput = [IO.Path]::GetFullPath($OutputRoot)
  $resolvedDestination = [IO.Path]::GetFullPath($destination)
  if (-not $resolvedDestination.StartsWith(
      ($resolvedOutput.TrimEnd('\') + '\'),
      [StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'Destino do pacote ficou fora de OutputRoot.'
  }
  Remove-Item -LiteralPath $destination -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
  $resolvedOutput = [IO.Path]::GetFullPath($OutputRoot)
  $resolvedZip = [IO.Path]::GetFullPath($zipPath)
  if (-not $resolvedZip.StartsWith(
      ($resolvedOutput.TrimEnd('\') + '\'),
      [StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'ZIP do pacote ficou fora de OutputRoot.'
  }
  Remove-Item -LiteralPath $zipPath -Force
}
[void](New-Item -ItemType Directory -Force -Path $destination)

$copyMap = @(
  @{ Source = (Join-Path $PSScriptRoot 'PACKAGE_README.md'); Destination = '00-LEIA-ME.md' },
  @{ Source = (Join-Path $PSScriptRoot 'APP_IDENTITY.json'); Destination = 'identity/APP_IDENTITY.json' },
  @{ Source = (Join-Path $PSScriptRoot 'publication_metadata.template.json'); Destination = 'owner-action/publication_metadata.template.json' },
  @{ Source = (Join-Path $PSScriptRoot 'PREENCHA_COM_SEUS_DADOS.md'); Destination = 'owner-action/PREENCHA_COM_SEUS_DADOS.md' },
  @{ Source = (Resolve-ProjectFile 'build/app/outputs/bundle/release/app-release.aab'); Destination = 'release/app-release.aab' },
  @{ Source = (Resolve-ProjectFile 'build/app/outputs/flutter-apk/app-release.apk'); Destination = 'qa/app-release.apk' },
  @{ Source = $certificatePath; Destination = 'signing-public/upload-certificate.pem' },
  @{ Source = $fingerprintsPath; Destination = 'signing-public/upload-key-fingerprints.txt' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\listing.json'); Destination = 'store/pt-BR/listing.json' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\STORE_LISTING_COPY.md'); Destination = 'store/pt-BR/STORE_LISTING_COPY.md' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\release_notes_1.0.0.txt'); Destination = 'store/pt-BR/release-notes-1.0.0.txt' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\upload_guide.md'); Destination = 'store/pt-BR/upload_guide.md' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\ASSET_UPLOAD_MAP.md'); Destination = 'store/pt-BR/ASSET_UPLOAD_MAP.md' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\screenshot_copy.md'); Destination = 'store/pt-BR/screenshot_copy.md' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\STORE_ASSETS_SHA256.txt'); Destination = 'store/pt-BR/STORE_ASSETS_SHA256.txt' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\PLAY_CONSOLE_ANSWERS.md'); Destination = 'compliance/PLAY_CONSOLE_ANSWERS.md' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\PLAY_CONSOLE_ANSWERS.json'); Destination = 'compliance/PLAY_CONSOLE_ANSWERS.json' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\data_safety.md'); Destination = 'compliance/data_safety.md' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\iarc_and_declarations.md'); Destination = 'compliance/iarc_and_declarations.md' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\privacy_policy.md'); Destination = 'legal/privacy_policy-preparation.md' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\privacy_policy.template.html'); Destination = 'legal/privacy_policy.template.html' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\privacy_policy.template.md'); Destination = 'legal/privacy_policy.template.md' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\support_page.template.html'); Destination = 'legal/support_page.template.html' },
  @{ Source = (Join-Path $PSScriptRoot 'pt-BR\support_page.template.md'); Destination = 'legal/support_page.template.md' },
  @{ Source = (Resolve-ProjectFile 'THIRD_PARTY_NOTICES.md'); Destination = 'legal/THIRD_PARTY_NOTICES.md' },
  @{ Source = (Resolve-ProjectFile 'RELEASE_1.0.0.md'); Destination = 'reports/RELEASE_1.0.0.md' },
  @{ Source = (Resolve-ProjectFile 'assets/branding/worde-icon-source.png'); Destination = 'mobile-branding/worde-icon-source.png' },
  @{ Source = (Resolve-ProjectFile 'assets/branding/worde-icon.png'); Destination = 'mobile-branding/worde-icon-1024.png' },
  @{ Source = (Resolve-ProjectFile 'assets/branding/worde-adaptive-foreground.png'); Destination = 'mobile-branding/worde-adaptive-foreground.png' },
  @{ Source = (Resolve-ProjectFile 'assets/branding/worde-adaptive-monochrome.png'); Destination = 'mobile-branding/worde-adaptive-monochrome.png' },
  @{ Source = (Resolve-ProjectFile 'assets/branding/worde-splash.png'); Destination = 'mobile-branding/worde-splash.png' },
  @{ Source = (Resolve-ProjectFile 'assets/branding/render_branding.ps1'); Destination = 'mobile-branding/render_branding.ps1' }
)

foreach ($mapping in $copyMap) {
  Copy-OneFile $mapping.Source $mapping.Destination
}

$approvedStoreAssets = @(
  'graphics/app-icon-512.png',
  'graphics/feature-graphic-1024x500.jpg',
  'screenshots/phone/01-inicio.png',
  'screenshots/phone/02-tamanhos.png',
  'screenshots/phone/03-niveis-4-letras.png',
  'screenshots/phone/04-jogo-dicas-bilingues.png',
  'screenshots/phone/05-vitoria.png',
  'screenshots/phone/06-privacidade.png',
  'screenshots/tablet/01-tamanhos.png',
  'screenshots/tablet/02-niveis-5-letras.png',
  'screenshots/tablet/03-jogo-dicas-bilingues.png',
  'screenshots/tablet/04-vitoria.png'
)
foreach ($relativeAssetPath in $approvedStoreAssets) {
  $sourceAsset = Join-Path $PSScriptRoot ('pt-BR\' + $relativeAssetPath.Replace('/', '\'))
  Copy-OneFile $sourceAsset ('store/pt-BR/' + $relativeAssetPath)
}

# O manifesto entregue usa apenas caminhos relativos ao pacote extraído. Os
# caminhos do host permanecem exclusivamente no manifesto-fonte do projeto.
$packageArtifactManifest = [ordered]@{
  schemaVersion = 1
  packageName = [string]$artifactManifest.packageName
  versionName = [string]$artifactManifest.versionName
  versionCode = [int]$artifactManifest.versionCode
  pathScope = 'submission_package_root'
  artifacts = @(
    $manifestArtifacts | ForEach-Object {
      [ordered]@{
        purpose = [string]$_.purpose
        path = [string]$_.packagePath
        bytes = [int64]$_.bytes
        sha256 = [string]$_.sha256
      }
    }
  )
  uploadCertificate = [ordered]@{
    path = [string]$artifactManifest.uploadCertificate.packagePath
    bytes = [int64]$artifactManifest.uploadCertificate.bytes
    sha256 = [string]$artifactManifest.uploadCertificate.sha256
    sha1Fingerprint = [string]$artifactManifest.uploadCertificate.sha1Fingerprint
    sha256Fingerprint = [string]$artifactManifest.uploadCertificate.sha256Fingerprint
  }
  publicFingerprintFile = [ordered]@{
    path = [string]$artifactManifest.publicFingerprintFile.packagePath
    bytes = [int64]$artifactManifest.publicFingerprintFile.bytes
    sha256 = [string]$artifactManifest.publicFingerprintFile.sha256
  }
}
$packageArtifactManifestPath = Join-Path $destination 'identity\RELEASE_ARTIFACTS.json'
[void](New-Item -ItemType Directory -Force -Path (Split-Path $packageArtifactManifestPath -Parent))
[IO.File]::WriteAllText(
  $packageArtifactManifestPath,
  ($packageArtifactManifest | ConvertTo-Json -Depth 10),
  [Text.UTF8Encoding]::new($false)
)

if ($IncludeFinalHostedPages) {
  foreach ($page in @('privacy_policy.html', 'privacy_policy.md', 'support_page.html', 'support_page.md')) {
    $source = Join-Path $PSScriptRoot "generated_publication\$page"
    Copy-OneFile $source "legal/final/$page"
  }
}

$forbidden = @(
  Get-ChildItem -LiteralPath $destination -File -Recurse | Where-Object {
    $_.Name -match '(?i)(\.jks$|\.keystore$|key\.properties$|keystore\.properties$|^\.env($|\.))'
  }
)
if ($forbidden.Count -gt 0) {
  throw "Material privado encontrado no pacote: $($forbidden.FullName -join ', ')"
}

$secretPatterns = @(
  '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
  '(?im)^\s*(?:storePassword|keyPassword)\s*[:=]\s*\S+',
  '(?im)^\s*(?:privateKey|clientSecret|accessToken)\s*[:=]\s*\S+'
)
$textExtensions = @('.json', '.md', '.txt', '.html', '.xml', '.svg')
foreach ($textFile in Get-ChildItem -LiteralPath $destination -File -Recurse) {
  if ($textExtensions -cnotcontains $textFile.Extension.ToLowerInvariant()) {
    continue
  }
  $contents = Get-Content -Raw -Encoding utf8 -LiteralPath $textFile.FullName
  foreach ($secretPattern in $secretPatterns) {
    if ($contents -match $secretPattern) {
      throw "Possivel segredo encontrado no pacote: $($textFile.FullName)"
    }
  }
}

$hashRows = @(
  $destinationPrefix = [IO.Path]::GetFullPath($destination).TrimEnd('\') + '\'
  Get-ChildItem -LiteralPath $destination -File -Recurse |
    Where-Object { $_.Name -ne 'SHA256SUMS.txt' } |
    ForEach-Object {
      $fullPath = [IO.Path]::GetFullPath($_.FullName)
      if (-not $fullPath.StartsWith($destinationPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Arquivo ficou fora do pacote: $fullPath"
      }
      $relative = $fullPath.Substring($destinationPrefix.Length).Replace('\', '/')
      $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
      "$hash`t$($_.Length)`t$relative"
    } |
    Sort-Object
)
$hashPath = Join-Path $destination 'SHA256SUMS.txt'
[IO.File]::WriteAllLines($hashPath, $hashRows, [Text.UTF8Encoding]::new($false))

Compress-Archive -LiteralPath $destination -DestinationPath $zipPath -CompressionLevel Optimal
$zipItem = Get-Item -LiteralPath $zipPath
$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash

Write-Output "Pacote criado: $destination"
Write-Output "ZIP criado: $zipPath"
Write-Output "ZIP bytes: $($zipItem.Length)"
Write-Output "ZIP SHA-256: $zipHash"
