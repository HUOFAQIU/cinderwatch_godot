param(
    [string]$GodotExe = "Godot_v4.7.2-stable_win64_console.exe",
    [string]$OutPath = "build/web/index.html"
)

$ErrorActionPreference = "Stop"
$ProjRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ProjRoot
try {
    $OutDir = Split-Path -Parent $OutPath
    if (-not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    }
    Write-Host "Exporting Cinderwatch (Web) to $OutPath ..."
    & $GodotExe --headless --path . --export-release "Web" $OutPath
    if ($LASTEXITCODE -ne 0) {
        throw "Godot export failed with exit code $LASTEXITCODE"
    }
    Write-Host "Done! Preview locally with: python -m http.server 8080 -d $OutDir"
} finally {
    Pop-Location
}
