param(
  [string]$DeviceId = 'emulator-5554',
  [string]$FlutterPath = 'D:\LexiNexoToolchain\flutter\bin\flutter.bat',
  [string]$AdbPath = 'D:\LexiNexoToolchain\android-sdk\platform-tools\adb.exe',
  [ValidateSet('all', 'phone', 'tablet')]
  [string]$CaptureSet = 'all'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $projectRoot 'scripts\lexinexo-env.ps1')
$localeRoot = Join-Path $PSScriptRoot 'pt-BR'
$screensRoot = Join-Path $localeRoot 'screenshots'
$assetInventoryPath = Join-Path $localeRoot 'STORE_ASSETS_SHA256.txt'
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
$resolvedProject = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd('\') + '\'
$resolvedScreens = [System.IO.Path]::GetFullPath($screensRoot)
if (-not $resolvedScreens.StartsWith($resolvedProject, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Destino de screenshots fora do projeto: $resolvedScreens"
}
if (-not (Test-Path -LiteralPath $FlutterPath)) { throw "Flutter nao encontrado: $FlutterPath" }
if (-not (Test-Path -LiteralPath $AdbPath)) { throw "adb nao encontrado: $AdbPath" }

$deviceLine = & $AdbPath devices | Select-String -Pattern "^$([regex]::Escape($DeviceId))\s+device$"
if (-not $deviceLine) { throw "Dispositivo $DeviceId nao esta pronto no adb." }
$bootCompleted = (& $AdbPath -s $DeviceId shell getprop sys.boot_completed).Trim()
if ($bootCompleted -ne '1') { throw "O Android em $DeviceId ainda nao concluiu o boot." }

if ($CaptureSet -eq 'all') {
  if (Test-Path -LiteralPath $screensRoot) {
    Remove-Item -LiteralPath $screensRoot -Recurse -Force
  }
} else {
  $selectedScreens = Join-Path $screensRoot $CaptureSet
  if (Test-Path -LiteralPath $selectedScreens) {
    Remove-Item -LiteralPath $selectedScreens -Recurse -Force
  }
}
New-Item -ItemType Directory -Force -Path $screensRoot | Out-Null

$env:LEXINEXO_SCREENSHOT_OUTPUT = $screensRoot

Add-Type -AssemblyName System.Drawing

function Convert-ScreenshotToRgb {
  param([Parameter(Mandatory)] [string]$Path)

  $temporaryPath = "$Path.rgb.tmp.png"
  if (Test-Path -LiteralPath $temporaryPath) {
    Remove-Item -LiteralPath $temporaryPath -Force
  }

  $source = [System.Drawing.Bitmap]::new($Path)
  try {
    $rgb = [System.Drawing.Bitmap]::new(
      $source.Width,
      $source.Height,
      [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($rgb)
      try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(11, 13, 24))
        $graphics.DrawImageUnscaled($source, 0, 0)
      } finally {
        $graphics.Dispose()
      }
      $rgb.Save($temporaryPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $rgb.Dispose()
    }
  } finally {
    $source.Dispose()
  }

  [System.IO.File]::Copy($temporaryPath, $Path, $true)
  Remove-Item -LiteralPath $temporaryPath -Force

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt 26 -or $bytes[24] -ne 8 -or $bytes[25] -ne 2) {
    throw "A conversao RGB de $Path nao produziu PNG truecolor 24-bit."
  }
}

function Convert-CaptureSetToRgb {
  param([Parameter(Mandatory)] [string]$FormFactor)

  $captureDirectory = Join-Path $screensRoot $FormFactor
  $captures = @(Get-ChildItem -LiteralPath $captureDirectory -Filter '*.png' -File)
  if ($captures.Count -eq 0) {
    throw "Nenhum screenshot foi capturado para $FormFactor."
  }
  foreach ($capture in $captures) {
    Convert-ScreenshotToRgb -Path $capture.FullName
  }
}

function Assert-CaptureFileSet {
  param([Parameter(Mandatory)] [string]$FormFactor)

  $expectedNames = if ($FormFactor -eq 'phone') {
    $phoneScreenshotNames
  } else {
    $tabletScreenshotNames
  }
  $captureDirectory = Join-Path $screensRoot $FormFactor
  $actualNames = @(
    Get-ChildItem -LiteralPath $captureDirectory -Filter '*.png' -File |
      Select-Object -ExpandProperty Name |
      Sort-Object
  )
  Assert-Condition (
    (($actualNames -join '|') -ceq (($expectedNames | Sort-Object) -join '|'))
  ) "A navegacao de captura nao produziu os estados aprovados para $FormFactor."
}

function Assert-Condition {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Update-AssetInventory {
  $relativePaths = @(
    'graphics/app-icon-512.png',
    'graphics/feature-graphic-1024x500.jpg'
  )
  $relativePaths += @(
    $phoneScreenshotNames | ForEach-Object { "screenshots/phone/$_" }
  )
  $relativePaths += @(
    $tabletScreenshotNames | ForEach-Object { "screenshots/tablet/$_" }
  )
  $lines = [System.Collections.Generic.List[string]]::new()
  $lines.Add('PalavraX 1.0.0 - Play Store asset inventory')
  $lines.Add('Format: SHA-256  bytes  relative path')
  $lines.Add('')
  foreach ($relativePath in $relativePaths) {
    $assetPath = Join-Path $localeRoot $relativePath.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
      throw "Material ausente ao atualizar inventario: $relativePath"
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $assetPath).Hash
    $bytes = (Get-Item -LiteralPath $assetPath).Length
    $lines.Add("$hash  $bytes  $relativePath")
  }
  [System.IO.File]::WriteAllLines(
    $assetInventoryPath,
    $lines,
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Invoke-CaptureSet {
  param(
    [string]$FormFactor,
    [string]$Size,
    [int]$Density
  )
  & $AdbPath -s $DeviceId shell wm size $Size | Out-Null
  & $AdbPath -s $DeviceId shell wm density $Density | Out-Null
  & $AdbPath -s $DeviceId shell settings put system accelerometer_rotation 0 | Out-Null
  & $AdbPath -s $DeviceId shell settings put system user_rotation 0 | Out-Null
  & $AdbPath -s $DeviceId shell settings put global window_animation_scale 0 | Out-Null
  & $AdbPath -s $DeviceId shell settings put global transition_animation_scale 1 | Out-Null
  # Keep Flutter's explicit success animation enabled for the victory captures.
  # GameScreen treats animator_duration_scale=0 as reduced motion and correctly
  # skips the check overlay, which would make the store integration contract fail.
  & $AdbPath -s $DeviceId shell settings put global animator_duration_scale 1 | Out-Null
  & $AdbPath -s $DeviceId shell settings put system font_scale 1.0 | Out-Null
  & $AdbPath -s $DeviceId shell settings put system time_12_24 24 | Out-Null
  & $AdbPath -s $DeviceId shell settings put global sysui_demo_allowed 1 | Out-Null
  & $AdbPath -s $DeviceId shell am broadcast -a com.android.systemui.demo -e command enter | Out-Null
  & $AdbPath -s $DeviceId shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1000 | Out-Null
  & $AdbPath -s $DeviceId shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false | Out-Null
  & $AdbPath -s $DeviceId shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false | Out-Null
  & $AdbPath -s $DeviceId shell svc wifi disable | Out-Null
  & $AdbPath -s $DeviceId shell svc data disable | Out-Null
  & $FlutterPath drive `
    --driver=test_driver/store_screenshots_test.dart `
    --target=integration_test/store_screenshots_test.dart `
    --device-id=$DeviceId `
    --dart-define="SCREENSHOT_FORM_FACTOR=$FormFactor"
  if ($LASTEXITCODE -ne 0) { throw "Falha ao capturar screenshots de $FormFactor." }
  Assert-CaptureFileSet -FormFactor $FormFactor
  Convert-CaptureSetToRgb -FormFactor $FormFactor
}

try {
  if ($CaptureSet -eq 'all' -or $CaptureSet -eq 'phone') {
    Invoke-CaptureSet -FormFactor phone -Size '1080x1920' -Density 300
  }
  if ($CaptureSet -eq 'all' -or $CaptureSet -eq 'tablet') {
    Invoke-CaptureSet -FormFactor tablet -Size '1440x2560' -Density 320
  }
  Update-AssetInventory
} finally {
  & $AdbPath -s $DeviceId shell am broadcast -a com.android.systemui.demo -e command exit | Out-Null
  & $AdbPath -s $DeviceId shell wm size reset | Out-Null
  & $AdbPath -s $DeviceId shell wm density reset | Out-Null
}

& (Join-Path $PSScriptRoot 'validate_publication.ps1') -StaticOnly
Write-Output "Screenshots reais salvos em $screensRoot"
