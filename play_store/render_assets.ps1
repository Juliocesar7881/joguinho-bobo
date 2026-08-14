param(
  [string]$ChromePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $root 'source'
$destination = Join-Path $root 'pt-BR\graphics'
$temporaryRoot = if ($env:LEXINEXO_TEMP) {
  $env:LEXINEXO_TEMP
} else {
  'D:\LexiNexoToolchain\temp'
}
$profile = Join-Path $temporaryRoot 'play-store-chrome-profile'

if (-not (Test-Path -LiteralPath $ChromePath)) {
  throw "Chrome nao encontrado em: $ChromePath"
}

New-Item -ItemType Directory -Force -Path $destination, $profile | Out-Null

function Invoke-SvgRender {
  param(
    [Parameter(Mandatory)] [string]$SourcePath,
    [Parameter(Mandatory)] [string]$DestinationPath,
    [Parameter(Mandatory)] [int]$Width,
    [Parameter(Mandatory)] [int]$Height
  )

  if (Test-Path -LiteralPath $DestinationPath) {
    Remove-Item -LiteralPath $DestinationPath -Force
  }
  $uri = [System.Uri]::new($SourcePath).AbsoluteUri
  & $ChromePath `
    --headless=new `
    --disable-gpu `
    --no-sandbox `
    --hide-scrollbars `
    --force-device-scale-factor=1 `
    "--user-data-dir=$profile" `
    "--window-size=$Width,$Height" `
    "--screenshot=$DestinationPath" `
    $uri | Out-Null

  for ($attempt = 0; $attempt -lt 100 -and -not (Test-Path -LiteralPath $DestinationPath); $attempt++) {
    Start-Sleep -Milliseconds 100
  }
  if (-not (Test-Path -LiteralPath $DestinationPath)) {
    throw "Falha ao renderizar $SourcePath"
  }
}

$iconPath = Join-Path $destination 'app-icon-512.png'
$featurePng = Join-Path $temporaryRoot 'lexinexo-feature-graphic.png'
$featureJpeg = Join-Path $destination 'feature-graphic-1024x500.jpg'

Invoke-SvgRender -SourcePath (Join-Path $source 'feature-graphic.svg') -DestinationPath $featurePng -Width 1024 -Height 500

Add-Type -AssemblyName System.Drawing
$iconSourcePath = Join-Path (Split-Path $root -Parent) 'assets\branding\worde-icon.png'
if (-not (Test-Path -LiteralPath $iconSourcePath -PathType Leaf)) {
  throw "Master do icone Worde ausente: $iconSourcePath"
}
$renderedIcon = [System.Drawing.Bitmap]::new($iconSourcePath)
try {
  $rgbaIcon = [System.Drawing.Bitmap]::new(512, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $iconGraphics = [System.Drawing.Graphics]::FromImage($rgbaIcon)
    try {
      $iconGraphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
      $iconGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $iconGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
      $iconGraphics.DrawImage($renderedIcon, 0, 0, 512, 512)
    } finally {
      $iconGraphics.Dispose()
    }
    $rgbaIcon.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $rgbaIcon.Dispose()
  }
} finally {
  $renderedIcon.Dispose()
}

$bitmap = [System.Drawing.Bitmap]::new($featurePng)
try {
  $rgb = [System.Drawing.Bitmap]::new(1024, 500, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  try {
    $graphics = [System.Drawing.Graphics]::FromImage($rgb)
    try {
      $graphics.DrawImageUnscaled($bitmap, 0, 0)
    } finally {
      $graphics.Dispose()
    }
    $rgb.Save($featureJpeg, [System.Drawing.Imaging.ImageFormat]::Jpeg)
  } finally {
    $rgb.Dispose()
  }
} finally {
  $bitmap.Dispose()
  Remove-Item -LiteralPath $featurePng -Force
}

Get-FileHash -Algorithm SHA256 $iconPath, $featureJpeg | Select-Object Path, Hash
