$ErrorActionPreference = 'Stop'

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

Write-Output 'Ferramentas de publicacao: geracao v2, schema fechado e rejeicao de placeholders aprovadas.'

Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
