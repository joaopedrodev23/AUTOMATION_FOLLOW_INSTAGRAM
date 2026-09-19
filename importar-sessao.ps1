<#
.SYNOPSIS
  Importa sessao do Instagram (cookie sessionid) direto para o SimpleInstaBot.
.DESCRIPTION
  Se o Instagram bloquear o login por automacao (desafio de seguranca / CAPTCHA),
  voce pode pegar o cookie 'sessionid' do seu navegador comum (Brave / Chrome / Edge)
  e colar aqui. O bot abrira ja 100% conectado, sem pedir senha nem passar pela tela de login!
#>
[CmdletBinding()]
param(
    [string]$Usuario = '',
    [string]$SessionId = ''
)

$ErrorActionPreference = 'Stop'
$appDir = Join-Path $env:APPDATA 'SimpleInstaBot'
New-Item -ItemType Directory -Force -Path $appDir | Out-Null

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  IMPORTADOR DE SESSAO DO INSTAGRAM (SimpleInstaBot)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

if (-not $Usuario) {
    $Usuario = Read-Host "Digite o usuario do Instagram (sem @)"
    $Usuario = $Usuario.Trim().TrimStart('@')
}

if (-not $SessionId) {
    Write-Host "Como pegar seu sessionid no navegador (Chrome, Brave, Edge):" -ForegroundColor Yellow
    Write-Host " 1. Abra o Instagram no seu navegador onde voce ja esta logado."
    Write-Host " 2. Pressione F12 -> aba 'Aplicativo' (Application) -> Cookies -> https://www.instagram.com"
    Write-Host " 3. Copie o valor do cookie 'sessionid'."
    Write-Host ""
    $SessionId = Read-Host "Cole o valor do cookie 'sessionid' aqui"
}

$SessionId = $SessionId.Trim().Trim('"').Trim("'")

if (-not $SessionId) {
    Write-Host "Nenhum sessionid informado. Cancelando." -ForegroundColor Red
    exit 1
}

$cookies = @(
    [ordered]@{
        name = "sessionid"
        value = $SessionId
        domain = ".instagram.com"
        path = "/"
        expires = -1
        httpOnly = $true
        secure = $true
        session = $true
    }
)

$cookiesJson = $cookies | ConvertTo-Json -Depth 5
$cookiesPath = Join-Path $appDir 'cookies.json'
[System.IO.File]::WriteAllText($cookiesPath, $cookiesJson, [System.Text.UTF8Encoding]::new($false))

# Atualiza config.json se existir
$configPath = Join-Path $appDir 'config.json'
$configObj = [ordered]@{}
if (Test-Path -LiteralPath $configPath) {
    try {
        $configObj = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    } catch {}
}
$configObj | Add-Member -NotePropertyName 'currentUsername' -NotePropertyValue $Usuario -Force
$configJson = $configObj | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($configPath, $configJson, [System.Text.UTF8Encoding]::new($false))

# Garante os JSONs da conta
$jsons = @('followed.json', 'unfollowed.json', 'liked-photos.json')
foreach ($j in $jsons) {
    $caminhoGen = Join-Path $appDir $j
    $caminhoUser = Join-Path $appDir "$Usuario-$j"
    if (-not (Test-Path -LiteralPath $caminhoGen)) {
        [System.IO.File]::WriteAllText($caminhoGen, '[]', [System.Text.UTF8Encoding]::new($false))
    }
    if (-not (Test-Path -LiteralPath $caminhoUser)) {
        [System.IO.File]::WriteAllText($caminhoUser, '[]', [System.Text.UTF8Encoding]::new($false))
    }
}

Write-Host ""
Write-Host "Sessao salva com sucesso para @$Usuario!" -ForegroundColor Green
Write-Host "O SimpleInstaBot agora abrira ja autenticado." -ForegroundColor Green
Write-Host ""

