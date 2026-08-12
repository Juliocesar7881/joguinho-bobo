param(
  [string]$ChromePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
)

$ErrorActionPreference = 'Stop'
$brandingDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$temporaryRoot = if ($env:LEXINEXO_TEMP) {
  $env:LEXINEXO_TEMP
} else {
  'D:\LexiNexoToolchain\temp'
}
$profile = Join-Path $temporaryRoot 'branding-chrome-profile'

if (-not (Test-Path -LiteralPath $ChromePath)) {
  throw "Chrome not found at: $ChromePath"
}

New-Item -ItemType Directory -Force -Path $profile | Out-Null

$assets = @(
  'lexinexo-icon',
  'lexinexo-splash',
  'lexinexo-adaptive-foreground',
  'lexinexo-adaptive-monochrome'
)

foreach ($asset in $assets) {
  $source = Join-Path $brandingDirectory "$asset.svg"
  $destination = Join-Path $brandingDirectory "$asset.png"
  $sourceUri = [System.Uri]::new($source).AbsoluteUri

  if (Test-Path -LiteralPath $destination) {
    Remove-Item -LiteralPath $destination -Force
  }

  & $ChromePath `
    --headless=new `
    --disable-gpu `
    --no-sandbox `
    --hide-scrollbars `
    --force-device-scale-factor=1 `
    --default-background-color=00000000 `
    "--user-data-dir=$profile" `
    --window-size=1024,1024 `
    "--screenshot=$destination" `
    $sourceUri | Out-Null

  # Chrome can hand the capture to an existing browser process and return first.
  for ($attempt = 0; $attempt -lt 50 -and -not (Test-Path -LiteralPath $destination); $attempt++) {
    Start-Sleep -Milliseconds 100
  }

  if (-not (Test-Path -LiteralPath $destination)) {
    throw "Could not render $asset.svg"
  }
}

Get-FileHash -Algorithm SHA256 ($assets | ForEach-Object {
  Join-Path $brandingDirectory "$_.png"
}) | Select-Object Path, Hash
