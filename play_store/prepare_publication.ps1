param(
  [string]$MetadataPath = (Join-Path $PSScriptRoot 'publication_metadata.json'),
  [string]$OutputDirectory = (Join-Path $PSScriptRoot 'generated_publication')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $MetadataPath)) {
  throw "Metadados reais ausentes. Copie publication_metadata.template.json para publication_metadata.json e substitua todos os exemplos por dados publicos validos."
}

# Valide o contrato completo antes de criar ou substituir qualquer pagina.
# Assim, um JSON com campo desconhecido ou valor incompatível não deixa uma
# saída parcial que possa ser hospedada por engano.
& (Join-Path $PSScriptRoot 'validate_publication.ps1') `
  -MetadataPath $MetadataPath `
  -MetadataOnly

$metadata = Get-Content -Raw -Encoding utf8 $MetadataPath | ConvertFrom-Json
$serialized = $metadata | ConvertTo-Json -Depth 10
if ($serialized -match '(?i)EXEMPLO|EXAMPLE|SUBSTITUA|CHANGEME|PLACEHOLDER|TODO|seu-dominio|your[-_ ]?(name|domain|email)|\.example\b|\bexample\.(com|org|net)\b') {
  throw 'Os metadados ainda contem valores de exemplo.'
}
if ([string]::IsNullOrWhiteSpace($metadata.developerDisplayName)) {
  throw 'developerDisplayName e obrigatorio.'
}
if ($metadata.accountType -notin @('personal', 'organization')) {
  throw 'accountType deve ser personal ou organization.'
}
if ($metadata.supportContactEmail -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
  throw 'supportContactEmail nao e um e-mail valido.'
}
if ($metadata.privacyContactEmail -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
  throw 'privacyContactEmail nao e um e-mail valido.'
}
foreach ($urlField in @('developerWebsiteUrl', 'supportPageUrl', 'privacyPolicyUrl')) {
  $uri = $null
  $urlValue = [string]$metadata.$urlField
  if (-not [Uri]::TryCreate($urlValue, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
    throw "$urlField deve ser uma URL HTTPS absoluta."
  }
}
if ($null -ne $metadata.supportPhone -and (
    $metadata.supportPhone -isnot [string] -or
    $metadata.supportPhone -notmatch '^\+[1-9][0-9]{7,14}$'
  )) {
  throw 'supportPhone deve ser null ou um numero internacional E.164, como +5511999999999.'
}

$templatePath = Join-Path $PSScriptRoot 'pt-BR\privacy_policy.template.html'
$outputPath = Join-Path $OutputDirectory 'privacy_policy.html'
[void](New-Item -ItemType Directory -Force -Path $OutputDirectory)
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
$markdownOutputPath = Join-Path $OutputDirectory 'privacy_policy.md'
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

$supportTemplates = @(
  @{
    Source = (Join-Path $PSScriptRoot 'pt-BR\support_page.template.html')
    Output = (Join-Path $OutputDirectory 'support_page.html')
    Html = $true
  },
  @{
    Source = (Join-Path $PSScriptRoot 'pt-BR\support_page.template.md')
    Output = (Join-Path $OutputDirectory 'support_page.md')
    Html = $false
  }
)
foreach ($supportTemplate in $supportTemplates) {
  $supportContent = Get-Content -Raw -Encoding utf8 $supportTemplate.Source
  $replacementValues = @{
    '{{developerDisplayName}}' = [string]$metadata.developerDisplayName
    '{{supportContactEmail}}' = [string]$metadata.supportContactEmail
    '{{supportPageUrl}}' = [string]$metadata.supportPageUrl
    '{{privacyPolicyUrl}}' = [string]$metadata.privacyPolicyUrl
  }
  foreach ($placeholder in $replacementValues.Keys) {
    $value = $replacementValues[$placeholder]
    if ($supportTemplate.Html) {
      $value = [System.Net.WebUtility]::HtmlEncode($value)
    }
    $supportContent = $supportContent.Replace($placeholder, $value)
  }
  [System.IO.File]::WriteAllText(
    $supportTemplate.Output,
    $supportContent,
    [System.Text.UTF8Encoding]::new($false)
  )
}

& (Join-Path $PSScriptRoot 'validate_publication.ps1') `
  -MetadataPath $MetadataPath `
  -GeneratedPagesDirectory $OutputDirectory
