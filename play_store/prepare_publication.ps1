param(
  [string]$MetadataPath = (Join-Path $PSScriptRoot 'publication_metadata.json')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $MetadataPath)) {
  throw "Metadados reais ausentes. Copie publication_metadata.template.json para publication_metadata.json e substitua todos os exemplos por dados publicos validos."
}

$metadata = Get-Content -Raw -Encoding utf8 $MetadataPath | ConvertFrom-Json
$serialized = $metadata | ConvertTo-Json -Depth 10
if ($serialized -match '(?i)EXEMPLO|EXAMPLE|SUBSTITUA|CHANGEME|PLACEHOLDER|TODO|seu-dominio|your[-_ ]?(name|domain|email)|\.example\b|\bexample\.(com|org|net)\b') {
  throw 'Os metadados ainda contem valores de exemplo.'
}
if ([string]::IsNullOrWhiteSpace($metadata.developerDisplayName)) {
  throw 'developerDisplayName e obrigatorio.'
}
if ($metadata.privacyContactEmail -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
  throw 'privacyContactEmail nao e um e-mail valido.'
}
$privacyUri = $null
if (-not [Uri]::TryCreate($metadata.privacyPolicyUrl, [UriKind]::Absolute, [ref]$privacyUri) -or $privacyUri.Scheme -ne 'https') {
  throw 'privacyPolicyUrl deve ser uma URL HTTPS absoluta.'
}

$templatePath = Join-Path $PSScriptRoot 'pt-BR\privacy_policy.template.html'
$outputPath = Join-Path $PSScriptRoot 'pt-BR\privacy_policy.html'
$html = Get-Content -Raw -Encoding utf8 $templatePath
$html = $html.Replace(
  '{{developerDisplayName}}',
  [System.Net.WebUtility]::HtmlEncode([string]$metadata.developerDisplayName)
)
$html = $html.Replace(
  '{{privacyContactEmail}}',
  [System.Net.WebUtility]::HtmlEncode([string]$metadata.privacyContactEmail)
)
$html = $html.Replace(
  '{{privacyPolicyUrl}}',
  [System.Net.WebUtility]::HtmlEncode([string]$metadata.privacyPolicyUrl)
)
[System.IO.File]::WriteAllText(
  $outputPath,
  $html,
  [System.Text.UTF8Encoding]::new($false)
)

$markdownTemplatePath = Join-Path $PSScriptRoot 'pt-BR\privacy_policy.template.md'
$markdownOutputPath = Join-Path $PSScriptRoot 'pt-BR\privacy_policy.md'
$markdown = Get-Content -Raw -Encoding utf8 $markdownTemplatePath
$markdown = $markdown.Replace(
  '{{developerDisplayName}}',
  [string]$metadata.developerDisplayName
)
$markdown = $markdown.Replace(
  '{{privacyContactEmail}}',
  [string]$metadata.privacyContactEmail
)
$markdown = $markdown.Replace(
  '{{privacyPolicyUrl}}',
  [string]$metadata.privacyPolicyUrl
)
[System.IO.File]::WriteAllText(
  $markdownOutputPath,
  $markdown,
  [System.Text.UTF8Encoding]::new($false)
)

& (Join-Path $PSScriptRoot 'validate_publication.ps1') -MetadataPath $MetadataPath
