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

$iconRender = Join-Path $temporaryRoot 'lexinexo-play-icon.png'
$iconPath = Join-Path $destination 'app-icon-512.png'
$featurePng = Join-Path $temporaryRoot 'lexinexo-feature-graphic.png'
$featureJpeg = Join-Path $destination 'feature-graphic-1024x500.jpg'

Invoke-SvgRender -SourcePath (Join-Path $source 'play-icon.svg') -DestinationPath $iconRender -Width 512 -Height 512
Invoke-SvgRender -SourcePath (Join-Path $source 'feature-graphic.svg') -DestinationPath $featurePng -Width 1024 -Height 500

Add-Type -AssemblyName System.Drawing
$renderedIcon = [System.Drawing.Bitmap]::new($iconRender)
try {
  $rgbaIcon = [System.Drawing.Bitmap]::new(512, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $iconGraphics = [System.Drawing.Graphics]::FromImage($rgbaIcon)
    try {
      $iconGraphics.DrawImageUnscaled($renderedIcon, 0, 0)
    } finally {
      $iconGraphics.Dispose()
    }
    $rgbaIcon.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $rgbaIcon.Dispose()
  }
} finally {
  $renderedIcon.Dispose()
  Remove-Item -LiteralPath $iconRender -Force
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
