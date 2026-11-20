<# : batch
@echo off
rem TDV-Sync.bat : met a jour les mods VikingLands et le mode HD de Terres de Viking.
rem A poser dans le dossier de Valheim (a cote de valheim.exe), puis double-cliquer.
rem Ne telecharge que les fichiers qui ont change (comparaison des empreintes SHA-256 au manifeste publie).
setlocal
set "TDV_SELF=%~f0"
set "TDV_ROOT=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:TDV_SELF))"
set "TDV_CODE=%ERRORLEVEL%"
echo.
pause
exit /b %TDV_CODE%
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$ManifestUrl = 'https://github.com/talath62/TDV-VikingLands-HD/releases/latest/download/tdv-manifest.json'
if ($env:TDV_MANIFEST) { $ManifestUrl = $env:TDV_MANIFEST }  # essais : autre manifeste
$root = $env:TDV_ROOT.TrimEnd('\')

Write-Host 'Terres de Viking : mise a jour des mods VikingLands et du mode HD'
Write-Host ('Dossier : ' + $root)
Write-Host ''
if (-not (Test-Path -LiteralPath (Join-Path $root 'valheim.exe'))) {
    Write-Host 'ERREUR : posez TDV-Sync.bat dans le dossier de Valheim, a cote de valheim.exe.'; exit 2
}
if (-not (Test-Path -LiteralPath (Join-Path $root 'BepInEx\plugins'))) {
    Write-Host 'ERREUR : BepInEx\plugins introuvable dans ce dossier (installez d''abord le modpack).'; exit 2
}
if (Get-Process -Name valheim -ErrorAction SilentlyContinue) {
    Write-Host 'ERREUR : fermez Valheim avant la mise a jour.'; exit 3
}

$wc = New-Object Net.WebClient
$wc.Headers['User-Agent'] = 'TDV-Sync'
$wc.Encoding = [Text.Encoding]::UTF8
try { $m = $wc.DownloadString($ManifestUrl) | ConvertFrom-Json }
catch { Write-Host ('ERREUR : manifeste introuvable (' + $ManifestUrl + ') : ' + $_.Exception.Message); exit 4 }
Write-Host ('Version publiee : ' + $m.version)

# Empreintes deja calculees (meme taille et meme date => meme fichier) : evite de relire les 9 Go de la HD a chaque fois.
$cachePath = Join-Path $root 'BepInEx\cache\tdv-sync.txt'
$cache = @{}
if (Test-Path -LiteralPath $cachePath) {
    foreach ($line in [IO.File]::ReadAllLines($cachePath)) {
        $p = $line.Split("`t")
        if ($p.Count -eq 4) { $cache[$p[0]] = $p }
    }
}
function Get-Sha([string]$path, [string]$key) {
    $fi = Get-Item -LiteralPath $path
    $c = $cache[$key]
    if ($c -and $c[1] -eq [string]$fi.Length -and $c[2] -eq [string]$fi.LastWriteTimeUtc.Ticks) { return $c[3] }
    $h = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $cache[$key] = @($key, [string]$fi.Length, [string]$fi.LastWriteTimeUtc.Ticks, $h)
    return $h
}

Write-Host 'Verification des fichiers installes...'
$todo = New-Object System.Collections.ArrayList
$upToDate = 0
foreach ($f in $m.files) {
    $dest = Join-Path $root ($f.path -replace '/', '\')
    if ((Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -eq $f.size -and (Get-Sha $dest $f.path) -eq $f.sha256) {
        $upToDate++
    } else { [void]$todo.Add($f) }
}
$total = 0; foreach ($f in $todo) { $total += $f.downloadSize }
Write-Host ('{0} fichiers a jour, {1} a telecharger ({2:N0} Mo).' -f $upToDate, $todo.Count, ($total / 1MB))

function Copy-WithHash($in, $out, $sha, [long]$expected, [string]$label) {
    $buf = New-Object byte[] (1MB)
    [long]$done = 0; $next = 0
    while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
        $out.Write($buf, 0, $n)
        [void]$sha.TransformBlock($buf, 0, $n, $null, 0)
        $done += $n
        if ($label -and $expected -ge 8MB -and $done -ge $next) {
            Write-Host -NoNewline ("`r  {0} : {1:N0} / {2:N0} Mo   " -f $label, ($done / 1MB), ($expected / 1MB))
            $next = $done + 16MB
        }
    }
    [void]$sha.TransformFinalBlock($buf, 0, 0)
    if ($label -and $expected -ge 8MB) { Write-Host '' }
    return ([BitConverter]::ToString($sha.Hash) -replace '-', '').ToLowerInvariant()
}

$failed = 0; $i = 0
foreach ($f in $todo) {
    $i++
    $dest = Join-Path $root ($f.path -replace '/', '\')
    $gz = $dest + '.tdvsync.gz'; $new = $dest + '.tdvsync.new'
    Write-Host ('[{0}/{1}] {2}' -f $i, $todo.Count, $f.path)
    $ok = $false
    for ($try = 1; $try -le 3 -and -not $ok; $try++) {
        try {
            [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest))
            $sha = [Security.Cryptography.SHA256]::Create()
            $in = $wc.OpenRead($f.url); $out = [IO.File]::Create($gz)
            try { $h = Copy-WithHash $in $out $sha $f.downloadSize 'telechargement' } finally { $in.Close(); $out.Close() }
            if ($h -ne $f.downloadSha256) { throw 'fichier telecharge abime (empreinte differente)' }
            $sha = [Security.Cryptography.SHA256]::Create()
            $fs = [IO.File]::OpenRead($gz)
            $unzip = New-Object IO.Compression.GZipStream($fs, [IO.Compression.CompressionMode]::Decompress)
            $out = [IO.File]::Create($new)
            try { $h = Copy-WithHash $unzip $out $sha $f.size $null } finally { $unzip.Close(); $out.Close() }
            if ($h -ne $f.sha256) { throw 'fichier decompresse different du manifeste' }
            Move-Item -LiteralPath $new -Destination $dest -Force
            $fi = Get-Item -LiteralPath $dest
            $cache[$f.path] = @($f.path, [string]$fi.Length, [string]$fi.LastWriteTimeUtc.Ticks, $f.sha256)
            $ok = $true
        } catch {
            Write-Host ('  essai {0} : {1}' -f $try, $_.Exception.Message)
        } finally {
            Remove-Item -LiteralPath $gz, $new -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not $ok) { $failed++; Write-Host ('  ECHEC : ' + $f.path) }
}

# Anciens fichiers remplaces (ex. hdtextures.pack d'un seul tenant, qui masquerait ses parties) : seulement si tout a reussi.
if ($failed -eq 0) {
    foreach ($d in $m.delete) {
        $path = if ($d.path) { $d.path } else { [string]$d }
        $full = Join-Path $root ($path -replace '/', '\')
        if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Force; $cache.Remove($path); Write-Host ('Supprime (remplace) : ' + $path) }
    }
}

try {
    [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cachePath))
    [IO.File]::WriteAllLines($cachePath, [string[]]@($cache.Values | ForEach-Object { $_ -join "`t" }))
} catch { }

Write-Host ''
if ($failed -gt 0) { Write-Host ('{0} fichier(s) non mis a jour : relancez TDV-Sync.bat.' -f $failed); exit 1 }
Write-Host ('Termine : version {0} a jour.' -f $m.version)
exit 0
