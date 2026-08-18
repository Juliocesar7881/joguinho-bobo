param(
  [string]$SourcePath = (Join-Path $PSScriptRoot 'worde-icon-source.png')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
  throw "Fonte do icone Worde ausente: $SourcePath"
}

function New-RoundedRectanglePath {
  param([float]$X, [float]$Y, [float]$Width, [float]$Height, [float]$Radius)
  $diameter = $Radius * 2
  $path = [Drawing.Drawing2D.GraphicsPath]::new()
  $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
  $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
  $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
  $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
  $path.CloseFigure()
  return $path
}

function New-TransparentBitmap {
  param([int]$Width, [int]$Height)
  return [Drawing.Bitmap]::new($Width, $Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Set-HighQualityGraphics {
  param([Drawing.Graphics]$Graphics)
  $Graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceOver
  $Graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
  $Graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $Graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
}

$source = [Drawing.Bitmap]::new((Resolve-Path -LiteralPath $SourcePath).Path)
try {
  if ($source.Width -ne $source.Height) { throw 'A fonte do icone deve ser quadrada.' }

  # 680 px mantém o alpha útil em aproximadamente 64,4% da camada de
  # 1024 px, dentro da zona segura de 66/108 dos ícones adaptativos Android.
  $adaptiveContentSize = 680
  $adaptiveContentOffset = 172

  $master = New-TransparentBitmap 1024 1024
  try {
    $graphics = [Drawing.Graphics]::FromImage($master)
    try {
      Set-HighQualityGraphics $graphics
      $graphics.Clear([Drawing.Color]::Transparent)
      $clip = New-RoundedRectanglePath 16 16 992 992 168
      try {
        $graphics.SetClip($clip)
        $graphics.DrawImage($source, 0, 0, 1024, 1024)
      } finally { $clip.Dispose() }
    } finally { $graphics.Dispose() }
    $master.Save((Join-Path $PSScriptRoot 'worde-icon.png'), [Drawing.Imaging.ImageFormat]::Png)

    $adaptive = New-TransparentBitmap 1024 1024
    try {
      $graphics = [Drawing.Graphics]::FromImage($adaptive)
      try {
        Set-HighQualityGraphics $graphics
        $graphics.Clear([Drawing.Color]::Transparent)
        # Mantém letras e lupa dentro da zona segura de máscaras circulares.
        $graphics.DrawImage(
          $master,
          $adaptiveContentOffset,
          $adaptiveContentOffset,
          $adaptiveContentSize,
          $adaptiveContentSize
        )
      } finally { $graphics.Dispose() }
      $adaptive.Save((Join-Path $PSScriptRoot 'worde-adaptive-foreground.png'), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $adaptive.Dispose() }

    $splash = New-TransparentBitmap 1024 1024
    try {
      $graphics = [Drawing.Graphics]::FromImage($splash)
      try {
        Set-HighQualityGraphics $graphics
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.DrawImage($master, 192, 192, 640, 640)
      } finally { $graphics.Dispose() }
      $splash.Save((Join-Path $PSScriptRoot 'worde-splash.png'), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $splash.Dispose() }

    # Android usa o alpha desta camada nos ícones temáticos. Mantemos letras,
    # lupa e detalhes claros/amarelos e removemos o fundo azul.
    $monochrome = New-TransparentBitmap 1024 1024
    try {
      $scaled = New-TransparentBitmap $adaptiveContentSize $adaptiveContentSize
      try {
        $graphics = [Drawing.Graphics]::FromImage($scaled)
        try {
          Set-HighQualityGraphics $graphics
          $graphics.Clear([Drawing.Color]::Transparent)
          $graphics.DrawImage(
            $master,
            0,
            0,
            $adaptiveContentSize,
            $adaptiveContentSize
          )
        } finally { $graphics.Dispose() }
        for ($y = 0; $y -lt $adaptiveContentSize; $y++) {
          for ($x = 0; $x -lt $adaptiveContentSize; $x++) {
            $pixel = $scaled.GetPixel($x, $y)
            if ($pixel.A -eq 0) { continue }
            $isBlueBackground = (
              $pixel.B -gt 115 -and
              $pixel.B -gt ($pixel.R * 1.45) -and
              $pixel.B -gt ($pixel.G * 1.12) -and
              ($pixel.R + $pixel.G + $pixel.B) -gt 190
            )
            if (-not $isBlueBackground) {
              $monochrome.SetPixel(
                $x + $adaptiveContentOffset,
                $y + $adaptiveContentOffset,
                [Drawing.Color]::FromArgb($pixel.A, 255, 255, 255)
              )
            }
          }
        }
      } finally { $scaled.Dispose() }
      $monochrome.Save((Join-Path $PSScriptRoot 'worde-adaptive-monochrome.png'), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $monochrome.Dispose() }
  } finally { $master.Dispose() }
} finally { $source.Dispose() }

Get-FileHash -Algorithm SHA256 @(
  (Join-Path $PSScriptRoot 'worde-icon.png'),
  (Join-Path $PSScriptRoot 'worde-adaptive-foreground.png'),
  (Join-Path $PSScriptRoot 'worde-adaptive-monochrome.png'),
  (Join-Path $PSScriptRoot 'worde-splash.png')
) | Select-Object Path, Hash
