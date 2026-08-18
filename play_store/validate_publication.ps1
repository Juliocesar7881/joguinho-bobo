param(
  [string]$MetadataPath = (Join-Path $PSScriptRoot 'publication_metadata.json'),
  [string]$GeneratedPagesDirectory = (Join-Path $PSScriptRoot 'generated_publication'),
  [switch]$StaticOnly,
  [switch]$MetadataOnly
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

function Assert-ExactKeys {
  param(
    [object]$Value,
    [string[]]$ExpectedKeys,
    [string]$ObjectName
  )
  Assert-Condition ($null -ne $Value) "$ObjectName deve ser um objeto JSON."
  $actualKeys = @($Value.PSObject.Properties.Name | Sort-Object)
  $sortedExpectedKeys = @($ExpectedKeys | Sort-Object)
  Assert-Condition (
    (($actualKeys -join '|') -ceq ($sortedExpectedKeys -join '|'))
  ) "$ObjectName deve conter exatamente estas chaves: $($sortedExpectedKeys -join ', ')."
}

function Assert-ExactStringArray {
  param(
    [object]$Value,
    [string[]]$ExpectedValues,
    [string]$FieldName
  )
  $actualValues = @($Value)
  Assert-Condition (
    $actualValues.Count -eq $ExpectedValues.Count
  ) "$FieldName deve conter exatamente $($ExpectedValues.Count) valor(es)."
  for ($index = 0; $index -lt $ExpectedValues.Count; $index++) {
    Assert-Condition (
      $actualValues[$index] -is [string] -and
      $actualValues[$index] -ceq $ExpectedValues[$index]
    ) "$FieldName deve ser exatamente: $($ExpectedValues -join ', ')."
  }
}

function Assert-BooleanValue {
  param(
    [object]$Value,
    [bool]$ExpectedValue,
    [string]$FieldName
  )
  Assert-Condition (
    $Value -is [bool] -and $Value -eq $ExpectedValue
  ) "$FieldName deve ser o booleano $($ExpectedValue.ToString().ToLowerInvariant())."
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

Assert-Condition (-not ($StaticOnly -and $MetadataOnly)) 'StaticOnly e MetadataOnly nao podem ser usados juntos.'

if (-not $StaticOnly) {
  Assert-Condition (Test-Path -LiteralPath $MetadataPath) 'publication_metadata.json nao existe; os dados publicos reais sao obrigatorios para liberar a publicacao.'
  $metadata = Get-Content -Raw -Encoding utf8 $MetadataPath | ConvertFrom-Json
  $expectedMetadataKeys = @(
    'accountType',
    'developerWebsiteUrl',
    'developerDisplayName',
    'distributionCountries',
    'packageName',
    'primaryLocale',
    'privacyContactEmail',
    'privacyPolicyUrl',
    'schemaVersion',
    'supportContactEmail',
    'supportPageUrl',
    'supportPhone',
    'targetAudience'
  )
  Assert-ExactKeys $metadata $expectedMetadataKeys 'publication_metadata.json'
  $serializedMetadata = $metadata | ConvertTo-Json -Depth 10
  Assert-Condition (
    $serializedMetadata -notmatch '(?i)EXEMPLO|EXAMPLE|SUBSTITUA|CHANGEME|PLACEHOLDER|TODO|seu-dominio|your[-_ ]?(name|domain|email)|\.example\b|\bexample\.(com|org|net)\b'
  ) 'Os metadados contem placeholders ou valores de exemplo.'
  Assert-Condition ($metadata.schemaVersion -eq 2) 'schemaVersion de publicacao incompativel.'
  Assert-Condition ($metadata.packageName -eq 'worde.com') 'packageName deve ser worde.com.'
  Assert-NonEmptyText $metadata.developerDisplayName 'developerDisplayName'
  Assert-NonEmptyText $metadata.supportContactEmail 'supportContactEmail'
  Assert-NonEmptyText $metadata.privacyContactEmail 'privacyContactEmail'
  Assert-NonEmptyText $metadata.developerWebsiteUrl 'developerWebsiteUrl'
  Assert-NonEmptyText $metadata.supportPageUrl 'supportPageUrl'
  Assert-NonEmptyText $metadata.privacyPolicyUrl 'privacyPolicyUrl'
  Assert-Condition ($metadata.supportContactEmail -match '^[^\s@]+@[^\s@]+\.[^\s@]+$') 'supportContactEmail invalido.'
  Assert-Condition ($metadata.privacyContactEmail -match '^[^\s@]+@[^\s@]+\.[^\s@]+$') 'privacyContactEmail invalido.'
  foreach ($urlField in @('developerWebsiteUrl', 'supportPageUrl', 'privacyPolicyUrl')) {
    $uri = $null
    Assert-Condition ([Uri]::TryCreate([string]$metadata.$urlField, [UriKind]::Absolute, [ref]$uri)) "$urlField invalida."
    Assert-Condition ($uri.Scheme -eq 'https') "$urlField deve usar HTTPS."
  }
  Assert-Condition (
    $null -eq $metadata.supportPhone -or (
      $metadata.supportPhone -is [string] -and
      $metadata.supportPhone -match '^\+[1-9][0-9]{7,14}$'
    )
  ) 'supportPhone deve ser null ou E.164.'
  Assert-Condition ($metadata.primaryLocale -eq 'pt-BR') 'primaryLocale deve ser pt-BR.'
  Assert-Condition ($metadata.accountType -in @('personal', 'organization')) 'accountType deve ser personal ou organization.'
  Assert-Condition ($metadata.targetAudience -eq '13+') 'targetAudience deve ser 13+.'
  Assert-ExactStringArray $metadata.distributionCountries @('BR') 'distributionCountries'
}

if ($MetadataOnly) {
  Write-Output 'Metadados publicos do kit Worde 1.0.0 validados.'
  return
}

$localeRoot = Join-Path $PSScriptRoot 'pt-BR'
$expectedPublicTitle = 'Worde: Aprenda Palavras'
$identityPath = Join-Path $PSScriptRoot 'APP_IDENTITY.json'
$answersJsonPath = Join-Path $localeRoot 'PLAY_CONSOLE_ANSWERS.json'
$answersMarkdownPath = Join-Path $localeRoot 'PLAY_CONSOLE_ANSWERS.md'
$assetUploadMapPath = Join-Path $localeRoot 'ASSET_UPLOAD_MAP.md'
$storeListingCopyPath = Join-Path $localeRoot 'STORE_LISTING_COPY.md'
$packageReadmePath = Join-Path $PSScriptRoot 'PACKAGE_README.md'
$ownerActionsPath = Join-Path $PSScriptRoot 'PREENCHA_COM_SEUS_DADOS.md'
$metadataTemplatePath = Join-Path $PSScriptRoot 'publication_metadata.template.json'
$adMobSetupPath = Join-Path $PSScriptRoot 'ADMOB_SETUP.md'
$appAdsTemplatePath = Join-Path $PSScriptRoot 'app-ads.template.txt'
foreach ($requiredPublicationFile in @(
    $identityPath,
    $answersJsonPath,
    $answersMarkdownPath,
    $assetUploadMapPath,
    $storeListingCopyPath,
    $packageReadmePath,
    $ownerActionsPath,
    $metadataTemplatePath,
    $adMobSetupPath,
    $appAdsTemplatePath
  )) {
  Assert-Condition (
    Test-Path -LiteralPath $requiredPublicationFile -PathType Leaf
  ) "Arquivo obrigatorio do pacote de publicacao ausente: $requiredPublicationFile"
}

$identity = Get-Content -Raw -Encoding utf8 $identityPath | ConvertFrom-Json
Assert-ExactKeys $identity @(
  'android',
  'businessModel',
  'privacy',
  'product',
  'releaseArtifacts',
  'schemaVersion',
  'uploadCertificate'
) 'APP_IDENTITY'
Assert-Condition ($identity.schemaVersion -eq 1) 'APP_IDENTITY schemaVersion incompativel.'
Assert-ExactKeys $identity.product @(
  'applicationType',
  'brandName',
  'category',
  'distributionCountries',
  'installedName',
  'price',
  'primaryLocale',
  'storeTitle',
  'targetAgeGroups'
) 'APP_IDENTITY.product'
Assert-Condition ($identity.product.brandName -ceq 'Worde') 'Marca divergente em APP_IDENTITY.'
Assert-Condition ($identity.product.storeTitle -ceq $expectedPublicTitle) 'Titulo divergente em APP_IDENTITY.'
Assert-Condition ($identity.product.installedName -ceq 'Worde') 'Nome instalado divergente em APP_IDENTITY.'
Assert-Condition ($identity.product.applicationType -ceq 'game') 'Tipo deve ser game em APP_IDENTITY.'
Assert-Condition ($identity.product.price -ceq 'free') 'Preco deve ser free em APP_IDENTITY.'
Assert-Condition ($identity.product.primaryLocale -ceq 'pt-BR') 'Locale divergente em APP_IDENTITY.'
Assert-Condition ($identity.product.category -ceq 'GAME_WORD') 'Categoria divergente em APP_IDENTITY.'
Assert-ExactStringArray $identity.product.distributionCountries @('BR') 'APP_IDENTITY.product.distributionCountries'
Assert-ExactStringArray $identity.product.targetAgeGroups @('13-15', '16-17', '18+') 'APP_IDENTITY.product.targetAgeGroups'

Assert-ExactKeys $identity.android @(
  'abis',
  'compileSdk',
  'dangerousPermissions',
  'dartProjectName',
  'formFactors',
  'internetPermission',
  'minSdk',
  'namespace',
  'orientation',
  'packageName',
  'supports16KiBPages',
  'targetSdk',
  'versionCode',
  'versionName'
) 'APP_IDENTITY.android'
Assert-Condition ($identity.android.packageName -ceq 'worde.com') 'Package divergente em APP_IDENTITY.'
Assert-Condition ($identity.android.namespace -ceq 'worde.com') 'Namespace divergente em APP_IDENTITY.'
Assert-Condition ($identity.android.dartProjectName -ceq 'lexinexo') 'Nome do projeto Dart divergente em APP_IDENTITY.'
Assert-Condition ($identity.android.versionName -ceq '1.0.0' -and $identity.android.versionCode -eq 1) 'Versao divergente em APP_IDENTITY.'
Assert-Condition ($identity.android.minSdk -eq 24 -and $identity.android.targetSdk -eq 36 -and $identity.android.compileSdk -eq 36) 'SDKs divergentes em APP_IDENTITY.'
Assert-Condition ($identity.android.orientation -ceq 'portrait') 'Orientacao divergente em APP_IDENTITY.'
Assert-ExactStringArray $identity.android.formFactors @('phone', 'tablet') 'APP_IDENTITY.android.formFactors'
Assert-ExactStringArray $identity.android.abis @('armeabi-v7a', 'arm64-v8a', 'x86_64') 'APP_IDENTITY.android.abis'
Assert-BooleanValue $identity.android.supports16KiBPages $true 'APP_IDENTITY.android.supports16KiBPages'
Assert-BooleanValue $identity.android.internetPermission $true 'APP_IDENTITY.android.internetPermission'
Assert-Condition (@($identity.android.dangerousPermissions).Count -eq 0) 'APP_IDENTITY nao pode declarar permissao perigosa.'

Assert-ExactKeys $identity.businessModel @(
  'accounts',
  'containsAds',
  'inAppPurchases',
  'onlineServices',
  'subscriptions'
) 'APP_IDENTITY.businessModel'
foreach ($businessFlag in @('containsAds', 'onlineServices')) {
  Assert-BooleanValue $identity.businessModel.$businessFlag $true "APP_IDENTITY.businessModel.$businessFlag"
}
foreach ($businessFlag in @('accounts', 'inAppPurchases', 'subscriptions')) {
  Assert-BooleanValue $identity.businessModel.$businessFlag $false "APP_IDENTITY.businessModel.$businessFlag"
}

Assert-ExactKeys $identity.privacy @(
  'collectsUserData',
  'localDataDeletion',
  'localDataOnly',
  'sharesUserData',
  'usesAdvertisingId',
  'usesTelemetry'
) 'APP_IDENTITY.privacy'
foreach ($privacyTrueFlag in @('collectsUserData', 'sharesUserData', 'usesAdvertisingId', 'usesTelemetry')) {
  Assert-BooleanValue $identity.privacy.$privacyTrueFlag $true "APP_IDENTITY.privacy.$privacyTrueFlag"
}
Assert-BooleanValue $identity.privacy.localDataOnly $false 'APP_IDENTITY.privacy.localDataOnly'
Assert-Condition (
  $identity.privacy.localDataDeletion -ceq 'clear_app_data_or_uninstall'
) 'Exclusao de dados locais divergente em APP_IDENTITY.'

Assert-ExactKeys $identity.releaseArtifacts @(
  'directInstallAndQa',
  'pathScope',
  'playUpload',
  'releaseReport'
) 'APP_IDENTITY.releaseArtifacts'
Assert-Condition (
  $identity.releaseArtifacts.pathScope -ceq 'submission_package_root'
) 'APP_IDENTITY.releaseArtifacts.pathScope deve ser submission_package_root.'
Assert-NonEmptyText $identity.releaseArtifacts.playUpload 'APP_IDENTITY.releaseArtifacts.playUpload'
Assert-NonEmptyText $identity.releaseArtifacts.directInstallAndQa 'APP_IDENTITY.releaseArtifacts.directInstallAndQa'
Assert-NonEmptyText $identity.releaseArtifacts.releaseReport 'APP_IDENTITY.releaseArtifacts.releaseReport'
Assert-Condition (
  [string]$identity.releaseArtifacts.playUpload -match '(?i)\.aab$'
) 'Artefato de upload deve ser um AAB em APP_IDENTITY.'
Assert-Condition (
  [string]$identity.releaseArtifacts.directInstallAndQa -match '(?i)\.apk$'
) 'Artefato de QA deve ser um APK em APP_IDENTITY.'
Assert-Condition (
  [string]$identity.releaseArtifacts.releaseReport -match '(?i)\.md$'
) 'Relatorio de release deve ser Markdown em APP_IDENTITY.'

Assert-ExactKeys $identity.uploadCertificate @(
  'algorithm',
  'sha1',
  'sha256',
  'subjectCommonName',
  'subjectNameIsHistoricalAndNotPublicBrand'
) 'APP_IDENTITY.uploadCertificate'
Assert-Condition ($identity.uploadCertificate.algorithm -ceq 'RSA-4096') 'Algoritmo do certificado divergente.'
Assert-NonEmptyText $identity.uploadCertificate.subjectCommonName 'APP_IDENTITY.uploadCertificate.subjectCommonName'
Assert-BooleanValue $identity.uploadCertificate.subjectNameIsHistoricalAndNotPublicBrand $true 'APP_IDENTITY.uploadCertificate.subjectNameIsHistoricalAndNotPublicBrand'
Assert-Condition (
  $identity.uploadCertificate.sha1 -cmatch '^(?:[0-9A-F]{2}:){19}[0-9A-F]{2}$'
) 'Fingerprint SHA-1 invalida em APP_IDENTITY.'
Assert-Condition (
  $identity.uploadCertificate.sha256 -cmatch '^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$'
) 'Fingerprint SHA-256 invalida em APP_IDENTITY.'

$answers = Get-Content -Raw -Encoding utf8 $answersJsonPath | ConvertFrom-Json
Assert-ExactKeys $answers @(
  'appContent',
  'appliesTo',
  'contentRating',
  'createApp',
  'ownerSuppliedFields',
  'release',
  'schemaVersion',
  'storeSettings'
) 'PLAY_CONSOLE_ANSWERS'
Assert-Condition ($answers.schemaVersion -eq 1) 'PLAY_CONSOLE_ANSWERS schemaVersion incompativel.'
Assert-ExactKeys $answers.appliesTo @('packageName', 'versionCode', 'versionName') 'PLAY_CONSOLE_ANSWERS.appliesTo'
Assert-Condition ($answers.appliesTo.packageName -ceq 'worde.com') 'Package divergente nas respostas da Console.'
Assert-Condition ($answers.appliesTo.versionName -ceq '1.0.0' -and $answers.appliesTo.versionCode -eq 1) 'Versao divergente nas respostas da Console.'

Assert-ExactKeys $answers.createApp @(
  'acceptDeveloperProgramPolicies',
  'acceptPlayAppSigning',
  'acceptUsExportLaws',
  'defaultLanguage',
  'name',
  'price',
  'type'
) 'PLAY_CONSOLE_ANSWERS.createApp'
Assert-Condition ($answers.createApp.name -ceq $expectedPublicTitle) 'Nome divergente nas respostas da Console.'
Assert-Condition ($answers.createApp.defaultLanguage -ceq 'pt-BR') 'Idioma divergente nas respostas da Console.'
Assert-Condition ($answers.createApp.type -ceq 'game') 'Tipo deve ser game nas respostas da Console.'
Assert-Condition ($answers.createApp.price -ceq 'free') 'Preco deve ser free nas respostas da Console.'
foreach ($acceptanceField in @('acceptDeveloperProgramPolicies', 'acceptPlayAppSigning', 'acceptUsExportLaws')) {
  Assert-BooleanValue $answers.createApp.$acceptanceField $true "PLAY_CONSOLE_ANSWERS.createApp.$acceptanceField"
}

Assert-ExactKeys $answers.storeSettings @(
  'category',
  'initialCountry',
  'supportedFormFactors',
  'untestedFormFactorsDisabled'
) 'PLAY_CONSOLE_ANSWERS.storeSettings'
Assert-Condition ($answers.storeSettings.category -ceq 'GAME_WORD') 'Categoria divergente nas respostas da Console.'
Assert-Condition ($answers.storeSettings.initialCountry -ceq 'BR') 'Pais inicial divergente nas respostas da Console.'
Assert-ExactStringArray $answers.storeSettings.supportedFormFactors @('phone', 'tablet') 'PLAY_CONSOLE_ANSWERS.storeSettings.supportedFormFactors'
Assert-ExactStringArray $answers.storeSettings.untestedFormFactorsDisabled @(
  'wearOs',
  'androidTv',
  'automotive',
  'xr',
  'playGamesPc'
) 'PLAY_CONSOLE_ANSWERS.storeSettings.untestedFormFactorsDisabled'

$expectedAppContentKeys = @(
  'accountCreation',
  'accountDeletionUrlApplicable',
  'appAccess',
  'containsAds',
  'covidContactTracingOrStatus',
  'dataCollected',
  'dataShared',
  'dataTransmittedOffDevice',
  'dating',
  'designedForChildren',
  'financialFeatures',
  'governmentAppOrInformation',
  'healthFeatures',
  'highRiskOrSensitivePermissions',
  'inAppPurchases',
  'newsOrMagazine',
  'privacyPolicyRequired',
  'realMoneyGambling',
  'subscriptions',
  'targetAgeGroups',
  'userCommunication',
  'userGeneratedContent',
  'usesAdvertisingId'
)
Assert-ExactKeys $answers.appContent $expectedAppContentKeys 'PLAY_CONSOLE_ANSWERS.appContent'
Assert-BooleanValue $answers.appContent.privacyPolicyRequired $true 'PLAY_CONSOLE_ANSWERS.appContent.privacyPolicyRequired'
Assert-Condition (
  $answers.appContent.appAccess -ceq 'all_functionality_available_without_special_access'
) 'appAccess divergente nas respostas da Console.'
Assert-ExactStringArray $answers.appContent.targetAgeGroups @('13-15', '16-17', '18+') 'PLAY_CONSOLE_ANSWERS.appContent.targetAgeGroups'
$falseAnswerFields = @(
  'accountDeletionUrlApplicable',
  'designedForChildren',
  'accountCreation',
  'financialFeatures',
  'healthFeatures',
  'governmentAppOrInformation',
  'newsOrMagazine',
  'covidContactTracingOrStatus',
  'highRiskOrSensitivePermissions',
  'realMoneyGambling',
  'userGeneratedContent',
  'userCommunication',
  'dating',
  'inAppPurchases',
  'subscriptions'
)
foreach ($falseAnswerField in $falseAnswerFields) {
  Assert-BooleanValue $answers.appContent.$falseAnswerField $false "PLAY_CONSOLE_ANSWERS.appContent.$falseAnswerField"
}
foreach ($trueAnswerField in @(
    'containsAds',
    'dataCollected',
    'dataShared',
    'dataTransmittedOffDevice',
    'usesAdvertisingId'
  )) {
  Assert-BooleanValue $answers.appContent.$trueAnswerField $true "PLAY_CONSOLE_ANSWERS.appContent.$trueAnswerField"
}

Assert-ExactKeys $answers.contentRating @(
  'acceptIarcCalculatedRating',
  'declareMildTextReferences',
  'imagesOrGameplayForThoseReferences',
  'questionnaireType'
) 'PLAY_CONSOLE_ANSWERS.contentRating'
Assert-Condition ($answers.contentRating.questionnaireType -ceq 'game') 'Questionario IARC deve ser game.'
Assert-ExactStringArray $answers.contentRating.declareMildTextReferences @(
  'conflict',
  'death',
  'alcohol'
) 'PLAY_CONSOLE_ANSWERS.contentRating.declareMildTextReferences'
Assert-BooleanValue $answers.contentRating.imagesOrGameplayForThoseReferences $false 'PLAY_CONSOLE_ANSWERS.contentRating.imagesOrGameplayForThoseReferences'
Assert-BooleanValue $answers.contentRating.acceptIarcCalculatedRating $true 'PLAY_CONSOLE_ANSWERS.contentRating.acceptIarcCalculatedRating'

Assert-ExactKeys $answers.release @(
  'artifact',
  'firstTrack',
  'playAppSigning',
  'uploadKeyIsNotDistributionKey'
) 'PLAY_CONSOLE_ANSWERS.release'
Assert-NonEmptyText $answers.release.artifact 'PLAY_CONSOLE_ANSWERS.release.artifact'
Assert-Condition ([string]$answers.release.artifact -match '(?i)\.aab$') 'O artefato da Console deve ser um AAB.'
Assert-Condition ($answers.release.firstTrack -ceq 'internal_testing') 'A primeira faixa deve ser internal_testing.'
Assert-BooleanValue $answers.release.playAppSigning $true 'PLAY_CONSOLE_ANSWERS.release.playAppSigning'
Assert-BooleanValue $answers.release.uploadKeyIsNotDistributionKey $true 'PLAY_CONSOLE_ANSWERS.release.uploadKeyIsNotDistributionKey'

Assert-ExactStringArray $answers.ownerSuppliedFields @(
  'accountType',
  'developerDisplayName',
  'legalIdentityAndAddress',
  'verifiedPrivateAccountEmail',
  'verifiedPrivateAccountPhone',
  'publicDeveloperEmail',
  'publicDeveloperPhoneIfOrganization',
  'organizationContactEmailAndPhoneIfOrganization',
  'supportContactEmail',
  'privacyContactEmail',
  'developerWebsiteUrl',
  'supportPageUrl',
  'privacyPolicyUrl',
  'dunsIfOrganization',
  'physicalDeviceVerificationIfRequired',
  'playConsoleAccess'
) 'PLAY_CONSOLE_ANSWERS.ownerSuppliedFields'

$answersMarkdown = Get-Content -Raw -Encoding utf8 $answersMarkdownPath
$answersSearchText = Convert-ToSearchText $answersMarkdown
foreach ($requiredAnswerPhrase in @(
    'sim, meu app contem anuncios',
    'todas as funcionalidades estao disponiveis sem acesso especial',
    'google mobile ads',
    'localizacao aproximada',
    'dispositivo ou outros ids',
    'meu app nao oferece recursos financeiros',
    'meu app nao oferece recursos de saude',
    'nao e um app governamental',
    'nao e um app de noticias ou revista',
    'pelo menos 12 testadores inscritos continuamente por 14 dias',
    'worde.com'
  )) {
  Assert-Condition (
    $answersSearchText.Contains($requiredAnswerPhrase)
  ) "Matriz da Console nao contem a orientacao obrigatoria: $requiredAnswerPhrase"
}

$adMobSetup = Get-Content -Raw -Encoding utf8 $adMobSetupPath
$adMobSetupSearchText = Convert-ToSearchText $adMobSetup
foreach ($requiredAdMobSetupValue in @(
    'worde.com',
    'worde_admob_app_id',
    'worde_admob_interstitial_id',
    'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy',
    'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy',
    '1 impressao a cada 3 minutos',
    'app-ads.template.txt'
  )) {
  Assert-Condition ($adMobSetupSearchText.Contains($requiredAdMobSetupValue)) "ADMOB_SETUP.md nao contem: $requiredAdMobSetupValue"
}
$appAdsTemplateLines = @(
  Get-Content -Encoding utf8 $appAdsTemplatePath |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }
)
Assert-Condition ($appAdsTemplateLines.Count -eq 1) 'app-ads.template.txt deve conter exatamente uma linha de inventario alem do comentario.'
Assert-Condition (
  $appAdsTemplateLines[0] -ceq 'google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0'
) 'app-ads.template.txt nao contem o placeholder seguro e aprovado.'

$assetUploadMap = Get-Content -Raw -Encoding utf8 $assetUploadMapPath
foreach ($requiredAssetName in @(
    'graphics/app-icon-512.png',
    'graphics/feature-graphic-1024x500.jpg',
    '04-jogo-dicas-bilingues.png',
    '05-vitoria.png',
    'tablet/03-jogo-dicas-bilingues.png'
  )) {
  Assert-Condition ($assetUploadMap.Contains($requiredAssetName)) "Mapa de upload nao referencia: $requiredAssetName"
}

$metadataTemplate = Get-Content -Raw -Encoding utf8 $metadataTemplatePath | ConvertFrom-Json
$expectedMetadataTemplateKeys = @(
  'accountType',
  'developerDisplayName',
  'developerWebsiteUrl',
  'distributionCountries',
  'packageName',
  'primaryLocale',
  'privacyContactEmail',
  'privacyPolicyUrl',
  'schemaVersion',
  'supportContactEmail',
  'supportPageUrl',
  'supportPhone',
  'targetAudience'
)
$actualMetadataTemplateKeys = @($metadataTemplate.PSObject.Properties.Name | Sort-Object)
Assert-Condition (
  (($actualMetadataTemplateKeys -join '|') -ceq (($expectedMetadataTemplateKeys | Sort-Object) -join '|'))
) 'Template de metadados deve conter exatamente as chaves do schema v2.'
Assert-Condition ($metadataTemplate.schemaVersion -eq 2) 'Template de metadados deve usar schemaVersion 2.'
Assert-Condition ($metadataTemplate.packageName -ceq 'worde.com') 'Template de metadados tem package divergente.'

$supportTemplatePaths = @(
  (Join-Path $localeRoot 'support_page.template.html'),
  (Join-Path $localeRoot 'support_page.template.md')
)
foreach ($supportTemplatePath in $supportTemplatePaths) {
  Assert-Condition (Test-Path -LiteralPath $supportTemplatePath -PathType Leaf) "Template de suporte ausente: $supportTemplatePath"
  $supportTemplateContents = Get-Content -Raw -Encoding utf8 $supportTemplatePath
  foreach ($placeholder in @(
      '{{developerDisplayName}}',
      '{{supportContactEmail}}',
      '{{supportPageUrl}}',
      '{{privacyPolicyUrl}}'
    )) {
    Assert-Condition ($supportTemplateContents.Contains($placeholder)) "Template de suporte nao contem $placeholder."
  }
}

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
$expectedAppName = 'Worde: Aprenda Palavras'
Assert-Condition ($listing.appName -ceq $expectedAppName) 'O titulo da ficha deve ser exatamente Worde: Aprenda Palavras.'
$expectedShortDescription = 'Aprenda ingl' + [char]0x00EA + 's em 1.000 desafios, com dicas bil' + [char]0x00ED + 'ngues e jogo offline.'
Assert-Condition (
  $listing.shortDescription -ceq $expectedShortDescription
) 'A descricao curta nao corresponde ao texto aprovado.'
Assert-Condition ($listing.appName.Length -le 30) 'O nome do app excede 30 caracteres.'
Assert-Condition ($listing.shortDescription.Length -le 80) 'A descricao curta excede 80 caracteres.'
Assert-Condition ($listing.fullDescription.Length -le 4000) 'A descricao completa excede 4.000 caracteres.'
$storeListingCopy = Get-Content -Raw -Encoding utf8 $storeListingCopyPath
foreach ($listingValue in @($listing.appName, $listing.shortDescription, $listing.fullDescription)) {
  Assert-Condition ($storeListingCopy.Contains([string]$listingValue)) 'STORE_LISTING_COPY.md diverge de listing.json.'
}
$listingSearchText = Convert-ToSearchText $listing.fullDescription
$requiredListingPhrases = @(
  'pista em portugues e outra em ingles',
  '3, 4, 5, 6, 7 ou 8 letras',
  'cada tamanho guarda seu proprio progresso',
  'teclado qwerty adaptativo de tres linhas',
  'o som pode ser silenciado',
  'preferencia de som ficam no aparelho',
  'anuncios intersticiais do google admob',
  'exigem conexao'
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

$privacyMarkdownPath = if ($StaticOnly) {
  Join-Path $localeRoot 'privacy_policy.md'
} else {
  Join-Path $GeneratedPagesDirectory 'privacy_policy.md'
}
$privacyMarkdown = Get-Content -Raw -Encoding utf8 $privacyMarkdownPath
$privacyTemplate = Get-Content -Raw -Encoding utf8 (Join-Path $localeRoot 'privacy_policy.template.html')
$privacyMarkdownTemplate = Get-Content -Raw -Encoding utf8 (Join-Path $localeRoot 'privacy_policy.template.md')
$dataSafety = Get-Content -Raw -Encoding utf8 (Join-Path $localeRoot 'data_safety.md')
foreach ($document in @($privacyMarkdown, $privacyTemplate, $privacyMarkdownTemplate, $dataSafety)) {
  $documentSearchText = Convert-ToSearchText $document
  Assert-Condition (
    $documentSearchText.Contains('preferencia de som de acerto')
  ) 'Politica e Data Safety devem documentar a preferencia local de som.'
  Assert-Condition (
    $documentSearchText.Contains('nao usa o microfone') -or
    $documentSearchText.Contains('nao usa microfone')
  ) 'Politica e Data Safety devem declarar a ausencia de uso do microfone.'
  foreach ($requiredAdsDisclosure in @(
      'google mobile ads',
      'localizacao aproximada',
      'diagnostico',
      'identificador de publicidade'
    )) {
    Assert-Condition (
      $documentSearchText.Contains($requiredAdsDisclosure)
    ) "Politica e Data Safety nao documentam o dado de anuncios: $requiredAdsDisclosure"
  }
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
  $privacyHtmlPath = Join-Path $GeneratedPagesDirectory 'privacy_policy.html'
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

  $supportHtmlPath = Join-Path $GeneratedPagesDirectory 'support_page.html'
  $supportMarkdownPath = Join-Path $GeneratedPagesDirectory 'support_page.md'
  Assert-Condition (Test-Path -LiteralPath $supportHtmlPath) 'A pagina HTML de suporte nao foi gerada.'
  Assert-Condition (Test-Path -LiteralPath $supportMarkdownPath) 'A pagina Markdown de suporte nao foi gerada.'
  $supportHtml = Get-Content -Raw -Encoding utf8 $supportHtmlPath
  $supportMarkdown = Get-Content -Raw -Encoding utf8 $supportMarkdownPath
  foreach ($supportDocument in @($supportHtml, $supportMarkdown)) {
    Assert-Condition ($supportDocument -notmatch '\{\{[^}]+\}\}') 'A pagina de suporte ainda contem placeholders.'
  }
  foreach ($field in @('developerDisplayName', 'supportContactEmail', 'supportPageUrl', 'privacyPolicyUrl')) {
    $rawValue = [string]$metadata.$field
    $htmlValue = [System.Net.WebUtility]::HtmlEncode($rawValue)
    Assert-Condition ($supportHtml.Contains($htmlValue)) "$field nao corresponde a pagina HTML de suporte."
    Assert-Condition ($supportMarkdown.Contains($rawValue)) "$field nao corresponde a pagina Markdown de suporte."
  }
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
  Write-Output 'Conteudo estatico do kit Worde 1.0.0 validado.'
} else {
  Write-Output 'Kit de publicacao Worde 1.0.0 validado.'
}
