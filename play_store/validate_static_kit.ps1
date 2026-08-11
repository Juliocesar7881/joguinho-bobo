$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'validate_publication.ps1') -StaticOnly
