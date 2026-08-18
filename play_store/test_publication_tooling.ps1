$ErrorActionPreference = 'Stop'

$scriptsUnderTest = @(
  (Join-Path $PSScriptRoot 'validate_publication.ps1'),
  (Join-Path $PSScriptRoot 'build_submission_package.ps1'),
  (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\verify-release-artifacts.ps1'),
  $PSCommandPath
)
foreach ($scriptUnderTest in $scriptsUnderTest) {
  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    $scriptUnderTest,
    [ref]$tokens,
    [ref]$parseErrors
  )
  if (@($parseErrors).Count -gt 0) {
    throw "Erro de sintaxe em $scriptUnderTest`: $($parseErrors[0].Message)"
  }
}

$releaseVerifierPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\verify-release-artifacts.ps1'
$releaseTokens = $null
$releaseParseErrors = $null
$releaseAst = [System.Management.Automation.Language.Parser]::ParseFile(
  $releaseVerifierPath,
  [ref]$releaseTokens,
  [ref]$releaseParseErrors
)
foreach ($functionName in @('Assert-Condition', 'Assert-ProductionAdMobConfiguration')) {
  $functionAst = $releaseAst.FindAll({
      param($node)
      $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -ceq $functionName
    }, $true) | Select-Object -First 1
  if ($null -eq $functionAst) {
    throw "Funcao obrigatoria ausente no verificador de release: $functionName"
  }
  Invoke-Expression $functionAst.Extent.Text
}
$adMobAppIdPattern = '^ca-app-pub-[0-9]{16}~[0-9]{10}$'
$adMobInterstitialIdPattern = '^ca-app-pub-[0-9]{16}/[0-9]{10}$'
$googleTestAdMobAppId = 'ca-app-pub-3940256099942544~3347511713'
$googleTestInterstitialId = 'ca-app-pub-3940256099942544/1033173712'
$savedAdMobAppId = $env:WORDE_ADMOB_APP_ID
$savedInterstitialId = $env:WORDE_ADMOB_INTERSTITIAL_ID
Remove-Item Env:WORDE_ADMOB_APP_ID -ErrorAction SilentlyContinue
Remove-Item Env:WORDE_ADMOB_INTERSTITIAL_ID -ErrorAction SilentlyContinue
try {
  Assert-ProductionAdMobConfiguration `
    'ca-app-pub-1234567890123456~1234567890' `
    'ca-app-pub-1234567890123456/0987654321' `
    'fixture valida'

  foreach ($invalidFixture in @(
      [pscustomobject]@{ AppId = $googleTestAdMobAppId; UnitId = $googleTestInterstitialId; Error = 'test' },
      [pscustomobject]@{ AppId = 'missing-admob-app-id'; UnitId = 'missing-admob-interstitial-id'; Error = 'malformed' },
      [pscustomobject]@{ AppId = 'ca-app-pub-1234567890123456~1234567890'; UnitId = 'ca-app-pub-9999999999999999/0987654321'; Error = 'different publisher' }
    )) {
    $fixtureRejected = $false
    try {
      Assert-ProductionAdMobConfiguration $invalidFixture.AppId $invalidFixture.UnitId 'fixture invalida'
    } catch {
      $fixtureRejected = $_.Exception.Message -match [regex]::Escape($invalidFixture.Error)
    }
    if (-not $fixtureRejected) {
      throw "O verificador nao rejeitou corretamente a fixture AdMob: $($invalidFixture.Error)"
    }
  }
} finally {
  if ($null -ne $savedAdMobAppId) {
    $env:WORDE_ADMOB_APP_ID = $savedAdMobAppId
  }
  if ($null -ne $savedInterstitialId) {
    $env:WORDE_ADMOB_INTERSTITIAL_ID = $savedInterstitialId
  }
}

$temporaryRoot = Join-Path $env:TEMP 'worde-publication-tooling-test'
if (Test-Path -LiteralPath $temporaryRoot) {
  $resolvedTemp = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
  $resolvedTest = [IO.Path]::GetFullPath($temporaryRoot)
  if (-not $resolvedTest.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Diretorio de teste ficou fora do TEMP.'
  }
  Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
}
[void](New-Item -ItemType Directory -Path $temporaryRoot)

$metadataPath = Join-Path $temporaryRoot 'metadata.json'
$outputDirectory = Join-Path $temporaryRoot 'generated'
$metadata = [ordered]@{
  schemaVersion = 2
  packageName = 'worde.com'
  developerDisplayName = 'Estudio de Teste da Ferramenta'
  accountType = 'personal'
  supportContactEmail = 'suporte@validacao.invalid'
  privacyContactEmail = 'privacidade@validacao.invalid'
  developerWebsiteUrl = 'https://validacao.invalid/worde'
  supportPageUrl = 'https://validacao.invalid/worde/suporte'
  privacyPolicyUrl = 'https://validacao.invalid/worde/privacidade'
  supportPhone = $null
  primaryLocale = 'pt-BR'
  distributionCountries = @('BR')
  targetAudience = '13+'
}
[IO.File]::WriteAllText(
  $metadataPath,
  ($metadata | ConvertTo-Json -Depth 10),
  [Text.UTF8Encoding]::new($false)
)

& (Join-Path $PSScriptRoot 'prepare_publication.ps1') `
  -MetadataPath $metadataPath `
  -OutputDirectory $outputDirectory

$expectedNames = @(
  'privacy_policy.html',
  'privacy_policy.md',
  'support_page.html',
  'support_page.md'
)
$actualNames = @(
  Get-ChildItem -LiteralPath $outputDirectory -File |
    Select-Object -ExpandProperty Name |
    Sort-Object
)
if (($actualNames -join '|') -cne (($expectedNames | Sort-Object) -join '|')) {
  throw 'A ferramenta nao gerou exatamente as quatro paginas esperadas.'
}
foreach ($page in Get-ChildItem -LiteralPath $outputDirectory -File) {
  $contents = Get-Content -Raw -Encoding utf8 $page.FullName
  if ($contents -match '\{\{[^}]+\}\}') {
    throw "Placeholder restante em $($page.Name)."
  }
}

$placeholderRejected = $false
try {
  & (Join-Path $PSScriptRoot 'prepare_publication.ps1') `
    -MetadataPath (Join-Path $PSScriptRoot 'publication_metadata.template.json') `
    -OutputDirectory (Join-Path $temporaryRoot 'must-not-generate')
} catch {
  if ($_.Exception.Message -match 'valores de exemplo') {
    $placeholderRejected = $true
  } else {
    throw
  }
}
if (-not $placeholderRejected) {
  throw 'O template com placeholders nao foi rejeitado.'
}

$unknownFieldMetadata = $metadata | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$unknownFieldMetadata | Add-Member -NotePropertyName unexpectedField -NotePropertyValue 'nao permitido'
$unknownFieldMetadataPath = Join-Path $temporaryRoot 'metadata-unknown-field.json'
$unknownFieldOutput = Join-Path $temporaryRoot 'must-remain-empty'
[IO.File]::WriteAllText(
  $unknownFieldMetadataPath,
  ($unknownFieldMetadata | ConvertTo-Json -Depth 10),
  [Text.UTF8Encoding]::new($false)
)
$unknownFieldRejected = $false
try {
  & (Join-Path $PSScriptRoot 'prepare_publication.ps1') `
    -MetadataPath $unknownFieldMetadataPath `
    -OutputDirectory $unknownFieldOutput
} catch {
  if ($_.Exception.Message -match 'deve conter exatamente estas chaves') {
    $unknownFieldRejected = $true
  } else {
    throw
  }
}
if (-not $unknownFieldRejected) {
  throw 'Metadados com campo desconhecido nao foram rejeitados.'
}
if (Test-Path -LiteralPath $unknownFieldOutput) {
  $partialOutputs = @(Get-ChildItem -LiteralPath $unknownFieldOutput -File -Recurse)
  if ($partialOutputs.Count -gt 0) {
    throw 'Metadados invalidos deixaram paginas parciais no disco.'
  }
}

& (Join-Path $PSScriptRoot 'validate_publication.ps1') -StaticOnly

Write-Output 'Ferramentas de publicacao: sintaxe, geracao v2, schema fechado, rejeicao de placeholders e kit AdMob aprovados.'

Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
