# Sign2Digital native branding from YOUR local icon. No redraw.
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $project
$assets = Join-Path $project 'assets'
$png = Join-Path $assets 'sign_app_icon.png'
$jpg = Join-Path $assets 'sign_app_icon.jpg'
$jpeg = Join-Path $assets 'sign_app_icon.jpeg'
$splash = Join-Path $assets 'logo_splash.png'

if (-not (Test-Path -LiteralPath $splash -PathType Leaf)) {
    throw "Missing your existing splash: $splash"
}
if (-not (Test-Path -LiteralPath $png -PathType Leaf)) {
    $source = if (Test-Path -LiteralPath $jpg -PathType Leaf) { $jpg } elseif (Test-Path -LiteralPath $jpeg -PathType Leaf) { $jpeg } else { $null }
    if (-not $source) {
        throw 'Missing assets\sign_app_icon.png (or .jpg/.jpeg). Keep your original icon in the assets folder.'
    }
    Add-Type -AssemblyName System.Drawing
    $image = [System.Drawing.Image]::FromFile($source)
    try { $image.Save($png, [System.Drawing.Imaging.ImageFormat]::Png) }
    finally { $image.Dispose() }
    Write-Host "Converted YOUR icon from JPEG to PNG: $png"
}

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile($png)
try {
    $width = $image.Width
    $height = $image.Height
    if ($width -ne $height) {
        Write-Warning "The launcher icon is $($width)x$($height), not square. Use a square icon for best results."
    }
    if ($width -lt 512 -or $height -lt 512) {
        Write-Warning "For sharp icons at all sizes, use your original artwork in a 1024x1024 PNG."
    }
} finally { $image.Dispose() }

& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
& dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { throw 'flutter_launcher_icons failed' }
& dart run flutter_native_splash:create
if ($LASTEXITCODE -ne 0) { throw 'flutter_native_splash failed' }

Write-Host 'Sign2Digital native launcher icons and splash are generated.'
Write-Host 'The Flutter SplashScreen still uses your original assets/logo_splash.png.'
Write-Host 'Fully restart the app. If Android still caches the old icon, uninstall and reinstall it.'

