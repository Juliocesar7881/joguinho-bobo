param(
  [string]$MetadataPath = (Join-Path $PSScriptRoot 'publication_metadata.json'),
  [switch]$StaticOnly
)

$ErrorActionPreference = 'Stop'

function Assert-Condition {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Assert-NonEmptyText {
  param([object]$Value, [string]$FieldName)
  Assert-Condition (
    $Value -is [string] -and -not [string]::IsNullOrWhiteSpace($Value)
  ) "$FieldName deve ser um texto nao vazio."
}

function Convert-ToSearchText {
  param([string]$Value)
  $normalized = $Value.Normalize([Text.NormalizationForm]::FormD)
  $builder = [Text.StringBuilder]::new()
  foreach ($character in $normalized.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($character) -ne
        [Globalization.UnicodeCategory]::NonSpacingMark) {
      [void]$builder.Append($character)
    }
  }
  return $builder.ToString().ToLowerInvariant()
}

function Get-PngInfo {
  param([string]$Path)
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  Assert-Condition ($bytes.Length -ge 26) "PNG invalido: $Path"
  $signature = @(137, 80, 78, 71, 13, 10, 26, 10)
  for ($index = 0; $index -lt $signature.Count; $index++) {
    Assert-Condition ($bytes[$index] -eq $signature[$index]) "Assinatura PNG invalida: $Path"
  }
  $width = ([int64]$bytes[16] * 16777216) + ([int64]$bytes[17] * 65536) + ([int64]$bytes[18] * 256) + [int64]$bytes[19]
  $height = ([int64]$bytes[20] * 16777216) + ([int64]$bytes[21] * 65536) + ([int64]$bytes[22] * 256) + [int64]$bytes[23]
  [pscustomobject]@{ Width = $width; Height = $height; BitDepth = $bytes[24]; ColorType = $bytes[25] }
}

if (-not $StaticOnly) {
  Assert-Condition (Test-Path -LiteralPath $MetadataPath) 'publication_metadata.json nao existe; os dados publicos reais sao obrigatorios para liberar a publicacao.'
  $metadata = Get-Content -Raw -Encoding utf8 $MetadataPath | ConvertFrom-Json
  $expectedMetadataKeys = @(
    'accountType',
    'developerDisplayName',
    'distributionCountries',
    'packageName',
    'primaryLocale',
    'privacyContactEmail',
    'privacyPolicyUrl',
    'schemaVersion',
    'targetAudience'
  )
  $actualMetadataKeys = @($metadata.PSObject.Properties.Name | Sort-Object)
  Assert-Condition (
    (($actualMetadataKeys -join '|') -ceq (($expectedMetadataKeys | Sort-Object) -join '|'))
  ) 'publication_metadata.json deve conter exatamente as chaves esperadas.'
  $serializedMetadata = $metadata | ConvertTo-Json -Depth 10
  Assert-Condition (
    $serializedMetadata -notmatch '(?i)EXEMPLO|EXAMPLE|SUBSTITUA|CHANGEME|PLACEHOLDER|TODO|seu-dominio|your[-_ ]?(name|domain|email)|\.example\b|\bexample\.(com|org|net)\b'
  ) 'Os metadados contem placeholders ou valores de exemplo.'
  Assert-Condition ($metadata.schemaVersion -eq 1) 'schemaVersion de publicacao incompativel.'
  Assert-Condition ($metadata.packageName -eq 'com.lexinexo.app') 'packageName deve ser com.lexinexo.app.'
  Assert-NonEmptyText $metadata.developerDisplayName 'developerDisplayName'
  Assert-NonEmptyText $metadata.privacyContactEmail 'privacyContactEmail'
  Assert-NonEmptyText $metadata.privacyPolicyUrl 'privacyPolicyUrl'
  Assert-Condition ($metadata.privacyContactEmail -match '^[^\s@]+@[^\s@]+\.[^\s@]+$') 'privacyContactEmail invalido.'
  $privacyUri = $null
  Assert-Condition ([Uri]::TryCreate($metadata.privacyPolicyUrl, [UriKind]::Absolute, [ref]$privacyUri)) 'privacyPolicyUrl invalida.'
  Assert-Condition ($privacyUri.Scheme -eq 'https') 'privacyPolicyUrl deve usar HTTPS.'
  Assert-Condition ($metadata.primaryLocale -eq 'pt-BR') 'primaryLocale deve ser pt-BR.'
  Assert-Condition ($metadata.accountType -eq 'organization') 'accountType deve ser organization.'
  Assert-Condition ($metadata.targetAudience -eq '13+') 'targetAudience deve ser 13+.'
  $distributionCountries = @($metadata.distributionCountries)
  Assert-Condition (
    $distributionCountries.Count -eq 1 -and $distributionCountries[0] -ceq 'BR'
  ) 'distributionCountries deve conter somente BR, sem duplicatas.'
}

$localeRoot = Join-Path $PSScriptRoot 'pt-BR'
$phoneScreenshotNames = @(
  '01-inicio.png',
  '02-tamanhos.png',
  '03-niveis-4-letras.png',
  '04-jogo-dicas-bilingues.png',
  '05-vitoria.png',
  '06-privacidade.png'
)
$tabletScreenshotNames = @(
  '01-tamanhos.png',
  '02-niveis-5-letras.png',
  '03-jogo-dicas-bilingues.png',
  '04-vitoria.png'
)
$expectedInventoryRelativePaths = @(
  'graphics/app-icon-512.png',
  'graphics/feature-graphic-1024x500.jpg'
)
$expectedInventoryRelativePaths += @(
  $phoneScreenshotNames | ForEach-Object { "screenshots/phone/$_" }
)
$expectedInventoryRelativePaths += @(
  $tabletScreenshotNames | ForEach-Object { "screenshots/tablet/$_" }
)

$listing = Get-Content -Raw -Encoding utf8 (Join-Path $localeRoot 'listing.json') | ConvertFrom-Json
$expectedListingKeys = @('appName', 'fullDescription', 'locale', 'shortDescription')
$actualListingKeys = @($listing.PSObject.Properties.Name | Sort-Object)
Assert-Condition (
  (($actualListingKeys -join '|') -ceq (($expectedListingKeys | Sort-Object) -join '|'))
) 'listing.json deve conter exatamente as chaves esperadas.'
Assert-NonEmptyText $listing.appName 'listing.appName'
Assert-NonEmptyText $listing.shortDescription 'listing.shortDescription'
Assert-NonEmptyText $listing.fullDescription 'listing.fullDescription'
Assert-Condition ($listing.locale -ceq 'pt-BR') 'O locale da ficha deve ser pt-BR.'
Assert-Condition ($listing.appName -ceq 'LexiNexo') 'O titulo da ficha deve ser exatamente LexiNexo.'
$expectedShortDescription = 'Aprenda ingl' + [char]0x00EA + 's em 1.000 desafios de palavras, com dicas opcionais e offline.'
Assert-Condition (
  $listing.shortDescription -ceq $expectedShortDescription
) 'A descricao curta nao corresponde ao texto aprovado.'
Assert-Condition ($listing.appName.Length -le 30) 'O nome do app excede 30 caracteres.'
Assert-Condition ($listing.shortDescription.Length -le 80) 'A descricao curta excede 80 caracteres.'
Assert-Condition ($listing.fullDescription.Length -le 4000) 'A descricao completa excede 4.000 caracteres.'
$listingSearchText = Convert-ToSearchText $listing.fullDescription
$requiredListingPhrases = @(
  'pista em portugues e outra em ingles',
  '3, 4, 5, 6, 7 ou 8 letras',
  'cada tamanho guarda seu proprio progresso',
  'teclado qwerty adaptativo de tres linhas',
  'o som pode ser silenciado',
  'preferencia de som ficam somente no aparelho'
)
foreach ($requiredPhrase in $requiredListingPhrases) {
  Assert-Condition (
    $listingSearchText.Contains($requiredPhrase)
  ) "A descricao completa nao documenta o recurso aprovado: $requiredPhrase"
}
$releaseNotes = (Get-Content -Raw -Encoding utf8 (Join-Path $localeRoot 'release_notes_1.0.0.txt')).Trim()
Assert-NonEmptyText $releaseNotes 'release_notes_1.0.0.txt'
Assert-Condition ($releaseNotes.Length -le 500) 'As notas da versao excedem 500 caracteres.'
$releaseNotesSearchText = Convert-ToSearchText $releaseNotes
$requiredReleasePhrases = @(
  'categorias de 3 a 8 letras',
  'dicas bilingues',
  'teclado adaptativo de tres linhas',
  'som opcional'
)
foreach ($requiredPhrase in $requiredReleasePhrases) {
  Assert-Condition (
    $releaseNotesSearchText.Contains($requiredPhrase)
  ) "As notas da versao nao documentam o recurso aprovado: $requiredPhrase"
}

$privacyMarkdown = Get-Content -Raw -Encoding utf8 (Join-Path $localeRoot 'privacy_policy.md')
$privacyTemplate = Get-Content -Raw -Encoding utf8 (Join-Path $localeRoot 'privacy_policy.template.html')
$privacyMarkdownTemplate = Get-Content -Raw -Encoding utf8 (Join-Path $localeRoot 'privacy_policy.template.md')
$dataSafety = Get-Content -Raw -Encoding utf8 (Join-Path $localeRoot 'data_safety.md')
foreach ($document in @($privacyMarkdown, $privacyTemplate, $privacyMarkdownTemplate, $dataSafety)) {
  $documentSearchText = Convert-ToSearchText $document
  Assert-Condition (
    $documentSearchText.Contains('preferencia de som de acerto')
  ) 'Politica e Data Safety devem documentar a preferencia local de som.'
  Assert-Condition (
    $documentSearchText.Contains('nao usa o microfone')
  ) 'Politica e Data Safety devem declarar a ausencia de uso do microfone.'
}

$screenshotCopyPath = Join-Path $localeRoot 'screenshot_copy.md'
Assert-Condition (Test-Path -LiteralPath $screenshotCopyPath -PathType Leaf) 'screenshot_copy.md ausente.'
$screenshotCopyRecords = @(
  Get-Content -Encoding utf8 -LiteralPath $screenshotCopyPath | ForEach-Object {
    if ($_ -match '^\d+\.\s+`(?<Name>[^`]+)`\s+\S+\s+(?<Alt>.+\S)\s*$') {
      [pscustomobject]@{ Name = $Matches.Name; Alt = $Matches.Alt.Trim() }
    }
  }
)
$expectedCopyNames = @($phoneScreenshotNames + $tabletScreenshotNames)
$actualCopyNames = @($screenshotCopyRecords.Name)
Assert-Condition (
  $screenshotCopyRecords.Count -eq 10 -and
  (($actualCopyNames -join '|') -ceq ($expectedCopyNames -join '|'))
) 'screenshot_copy.md deve listar os 10 screenshots esperados na ordem aprovada.'
foreach ($copyRecord in $screenshotCopyRecords) {
  Assert-NonEmptyText $copyRecord.Alt "Alt text de $($copyRecord.Name)"
  Assert-Condition ($copyRecord.Alt.Length -le 140) "Alt text excede 140 caracteres: $($copyRecord.Name)"
}

$assetInventoryPath = Join-Path $localeRoot 'STORE_ASSETS_SHA256.txt'
Assert-Condition (Test-Path -LiteralPath $assetInventoryPath) 'Inventario de hashes dos materiais ausente.'
$assetInventory = @(
  Get-Content -Encoding utf8 -LiteralPath $assetInventoryPath |
    Where-Object { $_ -match '^[0-9A-F]{64}\s+\d+\s+.+' }
)
Assert-Condition ($assetInventory.Count -eq 12) 'O inventario deve conter 12 materiais graficos.'
$inventoryRelativePaths = [System.Collections.Generic.List[string]]::new()
foreach ($inventoryLine in $assetInventory) {
  $inventoryParts = $inventoryLine -split '\s+', 3
  $inventoryHash = $inventoryParts[0]
  $inventoryBytes = [int64]$inventoryParts[1]
  $inventoryRelativePath = $inventoryParts[2].Replace('/', '\')
  $inventoryRelativePaths.Add($inventoryParts[2].Replace('\', '/'))
  $inventoryAssetPath = Join-Path $localeRoot $inventoryRelativePath
  Assert-Condition (Test-Path -LiteralPath $inventoryAssetPath -PathType Leaf) "Material inventariado ausente: $inventoryRelativePath"
  Assert-Condition ((Get-Item -LiteralPath $inventoryAssetPath).Length -eq $inventoryBytes) "Tamanho divergente no inventario: $inventoryRelativePath"
  Assert-Condition ((Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryAssetPath).Hash -eq $inventoryHash) "Hash divergente no inventario: $inventoryRelativePath"
}
$actualInventoryNames = @($inventoryRelativePaths | Sort-Object)
$expectedInventoryNames = @($expectedInventoryRelativePaths | Sort-Object)
Assert-Condition (
  (($actualInventoryNames -join '|') -ceq ($expectedInventoryNames -join '|'))
) 'O inventario nao contem exatamente os 12 nomes de materiais esperados.'

if (-not $StaticOnly) {
  $privacyHtmlPath = Join-Path $localeRoot 'privacy_policy.html'
  Assert-Condition (Test-Path -LiteralPath $privacyHtmlPath) 'A politica HTML final nao foi gerada por prepare_publication.ps1.'
  $privacyHtml = Get-Content -Raw -Encoding utf8 $privacyHtmlPath
  Assert-Condition ($privacyHtml -notmatch '\{\{[^}]+\}\}') 'A politica HTML ainda contem placeholders.'
  Assert-Condition ($privacyHtml.Contains([System.Net.WebUtility]::HtmlEncode([string]$metadata.developerDisplayName))) 'O nome do publicador nao corresponde a politica HTML.'
  Assert-Condition ($privacyHtml.Contains([System.Net.WebUtility]::HtmlEncode([string]$metadata.privacyContactEmail))) 'O contato nao corresponde a politica HTML.'
  Assert-Condition ($privacyHtml.Contains([System.Net.WebUtility]::HtmlEncode([string]$metadata.privacyPolicyUrl))) 'A URL publica nao corresponde a politica HTML.'
  Assert-Condition ($privacyMarkdown -notmatch '\{\{[^}]+\}\}') 'A politica Markdown ainda contem placeholders.'
  Assert-Condition ($privacyMarkdown.Contains([string]$metadata.developerDisplayName)) 'O nome do publicador nao corresponde a politica Markdown.'
  Assert-Condition ($privacyMarkdown.Contains([string]$metadata.privacyContactEmail)) 'O contato nao corresponde a politica Markdown.'
  Assert-Condition ($privacyMarkdown.Contains([string]$metadata.privacyPolicyUrl)) 'A URL publica nao corresponde a politica Markdown.'
}

$iconPath = Join-Path $localeRoot 'graphics\app-icon-512.png'
Assert-Condition (Test-Path -LiteralPath $iconPath) 'Icone de 512 px ausente.'
$icon = Get-PngInfo $iconPath
Assert-Condition ($icon.Width -eq 512 -and $icon.Height -eq 512) 'O icone deve medir 512x512.'
Assert-Condition ($icon.BitDepth -eq 8 -and $icon.ColorType -eq 6) 'O icone deve ser PNG RGBA de 32 bits.'
Assert-Condition ((Get-Item -LiteralPath $iconPath).Length -le 1MB) 'O icone excede 1 MiB.'

$featurePath = Join-Path $localeRoot 'graphics\feature-graphic-1024x500.jpg'
Assert-Condition (Test-Path -LiteralPath $featurePath) 'Feature graphic ausente.'
Add-Type -AssemblyName System.Drawing
$feature = [System.Drawing.Image]::FromFile($featurePath)
try {
  Assert-Condition (
    $feature.RawFormat.Guid -eq [System.Drawing.Imaging.ImageFormat]::Jpeg.Guid
  ) 'A feature graphic deve ser um arquivo JPEG real.'
  Assert-Condition ($feature.Width -eq 1024 -and $feature.Height -eq 500) 'A feature graphic deve medir 1024x500.'
  Assert-Condition (
    $feature.PixelFormat -eq [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
  ) 'A feature graphic deve usar RGB de 24 bits, sem alpha.'
} finally {
  $feature.Dispose()
}
Assert-Condition (
  (Get-Item -LiteralPath $featurePath).Length -le (15 * 1024 * 1024)
) 'A feature graphic excede o limite de 15 MB da Google Play.'

$screenshotSets = @(
  @{
    Path = (Join-Path $localeRoot 'screenshots\phone')
    Names = $phoneScreenshotNames
    Width = 1080
    Height = 1920
  },
  @{
    Path = (Join-Path $localeRoot 'screenshots\tablet')
    Names = $tabletScreenshotNames
    Width = 1440
    Height = 2560
  }
)
foreach ($set in $screenshotSets) {
  Assert-Condition (Test-Path -LiteralPath $set.Path) "Diretorio de screenshots ausente: $($set.Path)"
  $screenshots = @(Get-ChildItem -LiteralPath $set.Path -Filter '*.png' -File)
  $actualScreenshotNames = @($screenshots.Name | Sort-Object)
  $expectedScreenshotNames = @($set.Names | Sort-Object)
  Assert-Condition (
    (($actualScreenshotNames -join '|') -ceq ($expectedScreenshotNames -join '|'))
  ) "Nomes ou quantidade incorretos de screenshots em $($set.Path)."
  foreach ($screenshot in $screenshots) {
    $info = Get-PngInfo $screenshot.FullName
    Assert-Condition ($info.Width -eq $set.Width -and $info.Height -eq $set.Height) "Dimensao incorreta: $($screenshot.Name)"
    Assert-Condition ($info.BitDepth -eq 8 -and $info.ColorType -eq 2) "Screenshot deve ser PNG truecolor RGB de 24 bits: $($screenshot.Name)"
  }
}

if ($StaticOnly) {
  Write-Output 'Conteudo estatico do kit LexiNexo 1.0.0 validado.'
} else {
  Write-Output 'Kit de publicacao LexiNexo 1.0.0 validado.'
}
