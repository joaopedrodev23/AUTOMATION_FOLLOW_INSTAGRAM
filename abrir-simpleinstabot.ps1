<#
.SYNOPSIS
  Abre o SimpleInstaBot depois de reparar os arquivos locais que ele espera.

.DESCRIPTION
  O SimpleInstaBot pode apagar os JSONs globais quando a sessao e trocada ou
  encerrada. Na proxima abertura ele tenta ler followed.json e morre com
  ENOENT. Este wrapper e assistivo e conservador: cria apenas arquivos ausentes
  ou repara JSON vazio/invalido com backup. Tambem aplica um patch local no
  app empacotado para impedir que HTML inesperado do Instagram derrube o bot.
  Nao mexe em senha, cookie, config.json, login, CAPTCHA ou no botao Start.

.PARAMETER Usuario
  Seu usuario do Instagram (sem @). Exemplo: minha.conta
  Padrao: SEU_USUARIO_INSTAGRAM

.PARAMETER Exe
  Caminho completo para o SimpleInstaBot-win.exe se estiver fora das pastas
  padrao que o script procura automaticamente.

.PARAMETER CorrigirSomente
  Repara os arquivos mas nao abre o bot.

.PARAMETER Reiniciar
  Fecha processos existentes antes de abrir.

.EXAMPLE
  .\abrir-simpleinstabot.ps1 -Usuario minha.conta
  .\abrir-simpleinstabot.ps1 -Reiniciar
  .\abrir-simpleinstabot.ps1 -CorrigirSomente
#>
[CmdletBinding()]
param(
    [switch]$CorrigirSomente,
    [switch]$Reiniciar,
    [string]$Exe = '',
    [string]$Usuario = 'SEU_USUARIO_INSTAGRAM'
)

$ErrorActionPreference = 'Stop'

$appDir = Join-Path $env:APPDATA 'SimpleInstaBot'
$runtimeDir = Join-Path $env:LOCALAPPDATA 'SimpleInstaBot-codex-runtime'
$jsonsObrigatorios = @(
    'followed.json',
    'unfollowed.json',
    'liked-photos.json'
)
$usuariosFontePreferidos = @(
    $Usuario
) | Where-Object { $_ -and $_ -ne 'SEU_USUARIO_INSTAGRAM' } | Select-Object -Unique
$usuariosMigracao = $usuariosFontePreferidos

function Escrever-Array-Vazio([string]$Caminho) {
    $utf8SemBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Caminho, '[]', $utf8SemBom)
}

function Garantir-Json([string]$Caminho) {
    if (-not (Test-Path -LiteralPath $Caminho)) {
        Escrever-Array-Vazio $Caminho
        return "criado"
    }

    $conteudo = [System.IO.File]::ReadAllText($Caminho)
    if ([string]::IsNullOrWhiteSpace($conteudo)) {
        Escrever-Array-Vazio $Caminho
        return "reparado-vazio"
    }

    try {
        $null = $conteudo | ConvertFrom-Json -ErrorAction Stop
        return "ok"
    } catch {
        $backup = "$Caminho.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $Caminho -Destination $backup -Force
        Escrever-Array-Vazio $Caminho
        return "reparado-invalido"
    }
}

function Encontrar-Bytes([byte[]]$Bytes, [byte[]]$Padrao, [int]$Inicio = 0) {
    if (-not $Bytes -or -not $Padrao -or $Padrao.Length -eq 0 -or $Bytes.Length -lt $Padrao.Length) {
        return -1
    }

    $primeiro = $Padrao[0]
    $limite = $Bytes.Length - $Padrao.Length
    if ($Inicio -lt 0) { $Inicio = 0 }
    if ($Inicio -gt $limite) { return -1 }

    for ($i = $Inicio; $i -le $limite; $i++) {
        if ($Bytes[$i] -ne $primeiro) { continue }

        $igual = $true
        for ($j = 1; $j -lt $Padrao.Length; $j++) {
            if ($Bytes[$i + $j] -ne $Padrao[$j]) {
                $igual = $false
                break
            }
        }

        if ($igual) { return $i }
    }

    return -1
}

function Obter-Entrada-Asar([object]$Raiz, [string]$CaminhoRelativo) {
    $no = $Raiz

    foreach ($parte in ($CaminhoRelativo -split '/')) {
        if (-not $no.files) { return $null }

        $prop = $no.files.PSObject.Properties[$parte]
        if (-not $prop) { return $null }

        $no = $prop.Value
    }

    return $no
}

function Corrigir-JsonHtmlDoApp([string]$ExeLocal) {
    $dirExe = Split-Path -Parent $ExeLocal
    $asar = Join-Path $dirExe 'resources\app.asar'
    if (-not (Test-Path -LiteralPath $asar)) {
        Write-Host "  patch app: app.asar nao encontrado, pulando"
        return "sem-app-asar"
    }

    $encoding = [System.Text.Encoding]::UTF8
    $substituicoes = @(
        @{
            Nome = 'intercept-json-html'
            Antigo = "                const jsonText = await foundResponse.text();`n                const jsonParsed = JSON.parse(jsonText);"
            Novo = "let jsonText=await foundResponse.text();if(jsonText.trim()[0]!='{')return;const jsonParsed=JSON.parse(jsonText);"
        },
        @{
            Nome = 'manual-fetch-html'
            Antigo = "                        await response.json(); // else it will not finish the request"
            Novo = "                        await response.text(); // else it will not finish the request"
        },
        @{
            Nome = 'pre-json-html'
            Antigo = "        assert(typeof textContentValue === 'string');`n        return JSON.parse(textContentValue);"
            Novo = "        if(String(textContentValue).trim()[0]!='{')return;return JSON.parse(textContentValue);"
        }
    )
    $substituicoesIntervalo = @(
        @{
            Nome = 'profile-page-html-fallback'
            Inicio = "        async function getUserDataFromPage() {"
            Fim = "        // intercept special XHR network request"
            Marcador = "profilePage_"
            Novo = @'
        async function getUserDataFromPage() {
            try {
                const body = await page.content();
                const id = body.match(/"profile_id":"(\d+)"/)?.[1] ?? body.match(/profilePage_(\d+)/)?.[1] ?? body.match(/"props":\{"id":"(\d+)"/)?.[1];
                if (!id)
                    return undefined;
                const desc = body.match(/property="og:description" content="([^"]*)"/)?.[1] ?? body.match(/name="description" content="([^"]*)"/)?.[1] ?? '';
                const parseNum = (v) => { let s = String(v ?? '').trim().toLowerCase().replace(/,/g, ''); let m = 1; if (s.endsWith('k')) { m = 1000; s = s.slice(0, -1); } if (s.endsWith('m')) { m = 1000000; s = s.slice(0, -1); } const n = parseFloat(s.replace(/[^0-9.]/g, '')); return Number.isFinite(n) ? Math.round(n * m) : 0; };
                const counts = desc.match(/([\d.,]+[km]?)\s+followers,\s*([\d.,]+[km]?)\s+following,\s*([\d.,]+[km]?)\s+posts/i);
                return { id, username, edge_followed_by: { count: parseNum(counts?.[1]) }, edge_follow: { count: parseNum(counts?.[2]) }, is_private: body.includes('"is_private":true'), is_verified: body.includes('"is_verified":true') };
            }
            catch (err) {
                const message = err instanceof Error ? err.message : 'Unknown error';
                logger.warn(`Unable to get user data from page (${message}) - This is normal`);
            }
            return undefined;
        }
'@
        }
    )

    $bytes = [System.IO.File]::ReadAllBytes($asar)
    if ($bytes.Length -lt 32) {
        Write-Host "  patch app: app.asar pequeno demais, pulando" -ForegroundColor Yellow
        return "asar-invalido"
    }

    $headerBytesSize = [BitConverter]::ToUInt32($bytes, 8)
    $headerJsonSize = [BitConverter]::ToUInt32($bytes, 12)
    $bodyStart = [int64]16 + [int64]$headerBytesSize
    if ($headerJsonSize -le 0 -or $bodyStart -ge $bytes.Length) {
        Write-Host "  patch app: cabecalho app.asar invalido, pulando" -ForegroundColor Yellow
        return "asar-invalido"
    }

    $headerJson = $encoding.GetString($bytes, 16, [int]$headerJsonSize)
    $header = $headerJson | ConvertFrom-Json -ErrorAction Stop
    $entrada = Obter-Entrada-Asar $header 'node_modules/instauto/dist/index.js'
    if (-not $entrada -or $null -eq $entrada.offset -or $null -eq $entrada.size) {
        Write-Host "  patch app: arquivo alvo nao encontrado no app.asar, pulando" -ForegroundColor Yellow
        return "arquivo-alvo-nao-encontrado"
    }

    $inicio = $bodyStart + [int64]$entrada.offset
    $tamanho = [int64]$entrada.size
    if ($tamanho -le 0 -or $tamanho -gt [int]::MaxValue -or ($inicio + $tamanho) -gt $bytes.Length) {
        Write-Host "  patch app: arquivo alvo fora do limite do app.asar, pulando" -ForegroundColor Yellow
        return "arquivo-alvo-invalido"
    }

    $arquivoBytes = [byte[]]::new([int]$tamanho)
    [Array]::Copy($bytes, $inicio, $arquivoBytes, 0, $tamanho)

    $quantidade = 0
    $jaAplicado = 0
    $ausentes = @()

    foreach ($substituicao in $substituicoes) {
        $antigoBytes = $encoding.GetBytes($substituicao.Antigo)
        $novoBytesBase = $encoding.GetBytes($substituicao.Novo)
        if ($novoBytesBase.Length -gt $antigoBytes.Length) {
            throw "Patch do SimpleInstaBot ficou maior que o trecho original: $($substituicao.Nome)."
        }

        $novo = $substituicao.Novo + (' ' * ($antigoBytes.Length - $novoBytesBase.Length))
        $novoBytes = $encoding.GetBytes($novo)

        $idxNovo = Encontrar-Bytes $arquivoBytes $novoBytes
        $idxAntigo = Encontrar-Bytes $arquivoBytes $antigoBytes
        if ($idxAntigo -lt 0) {
            if ($idxNovo -ge 0) {
                $jaAplicado++
            } else {
                $ausentes += $substituicao.Nome
            }
            continue
        }

        while ($idxAntigo -ge 0) {
            [Array]::Copy($novoBytes, 0, $bytes, ($inicio + $idxAntigo), $novoBytes.Length)
            [Array]::Copy($novoBytes, 0, $arquivoBytes, $idxAntigo, $novoBytes.Length)
            $quantidade++
            $idxAntigo = Encontrar-Bytes $arquivoBytes $antigoBytes
        }
    }

    foreach ($intervalo in $substituicoesIntervalo) {
        $inicioBytes = $encoding.GetBytes($intervalo.Inicio)
        $fimBytes = $encoding.GetBytes($intervalo.Fim)
        $marcadorBytes = $encoding.GetBytes($intervalo.Marcador)

        $idxInicio = Encontrar-Bytes $arquivoBytes $inicioBytes
        if ($idxInicio -lt 0) {
            $ausentes += $intervalo.Nome
            continue
        }

        $idxFim = Encontrar-Bytes $arquivoBytes $fimBytes ($idxInicio + $inicioBytes.Length)
        if ($idxFim -lt 0) {
            $ausentes += $intervalo.Nome
            continue
        }

        $comprimentoAntigo = $idxFim - $idxInicio
        $trechoAtual = [byte[]]::new($comprimentoAntigo)
        [Array]::Copy($arquivoBytes, $idxInicio, $trechoAtual, 0, $comprimentoAntigo)

        if ((Encontrar-Bytes $trechoAtual $marcadorBytes) -ge 0) {
            $jaAplicado++
            continue
        }

        $novoBytesBase = $encoding.GetBytes($intervalo.Novo)
        if ($novoBytesBase.Length -gt $comprimentoAntigo) {
            throw "Patch do SimpleInstaBot ficou maior que o trecho original: $($intervalo.Nome)."
        }

        $novo = $intervalo.Novo + (' ' * ($comprimentoAntigo - $novoBytesBase.Length))
        $novoBytes = $encoding.GetBytes($novo)
        [Array]::Copy($novoBytes, 0, $bytes, ($inicio + $idxInicio), $novoBytes.Length)
        [Array]::Copy($novoBytes, 0, $arquivoBytes, $idxInicio, $novoBytes.Length)
        $quantidade++
    }

    if ($quantidade -eq 0) {
        if ($jaAplicado -gt 0) {
            Write-Host "  patch app: ja aplicado"
            return "ja-aplicado"
        }

        Write-Host ("  patch app: trecho JSON/HTML nao encontrado ({0}), pulando" -f ($ausentes -join ', ')) -ForegroundColor Yellow
        return "trecho-nao-encontrado"
    }

    $backup = "$asar.bak-codex-json-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $asar -Destination $backup -Force
    [System.IO.File]::WriteAllBytes($asar, $bytes)

    Write-Host ("  patch app: aplicado em {0} trecho(s) (backup {1})" -f $quantidade, (Split-Path -Leaf $backup))
    return "aplicado"
}

function Achar-Backup-Historico([string]$UsuarioLocal, [string]$Nome) {
    $raizBackup = Join-Path $appDir '_backup_migracao_codex'
    if (-not (Test-Path -LiteralPath $raizBackup)) { return $null }

    $achado = Get-ChildItem -LiteralPath $raizBackup -Recurse -File -Filter "$UsuarioLocal-$Nome" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($achado) { return $achado.FullName }
    return $null
}

function Escolher-Fonte-Historico([string]$Nome) {
    foreach ($usuarioLocal in $usuariosFontePreferidos) {
        $candidato = Join-Path $appDir "$usuarioLocal-$Nome"
        if (Test-Path -LiteralPath $candidato) {
            return $candidato
        }
    }

    foreach ($usuarioLocal in $usuariosFontePreferidos) {
        $backup = Achar-Backup-Historico $usuarioLocal $Nome
        if ($backup) {
            return $backup
        }
    }

    $generico = Join-Path $appDir $Nome
    if ((Test-Path -LiteralPath $generico) -and ((Get-Item -LiteralPath $generico).Length -gt 2)) {
        return $generico
    }

    if (Test-Path -LiteralPath $generico) { return $generico }

    return $null
}

function Listar-Exes-Extraidos-SimpleInstaBot {
    $tempDir = Join-Path $env:LOCALAPPDATA 'Temp'
    if (-not (Test-Path -LiteralPath $tempDir)) { return @() }

    $resultado = @()
    $diretorios = Get-ChildItem -LiteralPath $tempDir -Directory -ErrorAction SilentlyContinue

    foreach ($dir in $diretorios) {
        $candidatos = @(
            (Join-Path $dir.FullName 'SimpleInstaBot.exe'),
            (Join-Path $dir.FullName '7z-out\SimpleInstaBot.exe')
        )

        foreach ($candidato in $candidatos) {
            $asar = Join-Path (Split-Path -Parent $candidato) 'resources\app.asar'
            if ((Test-Path -LiteralPath $candidato) -and (Test-Path -LiteralPath $asar)) {
                $resultado += [pscustomobject]@{
                    Exe = (Resolve-Path -LiteralPath $candidato).Path
                    Data = (Get-Item -LiteralPath $asar).LastWriteTime
                }
            }
        }
    }

    $resultado |
        Sort-Object Data -Descending |
        Select-Object -ExpandProperty Exe -Unique
}

function Listar-Processos-SimpleInstaBot {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'SimpleInstaBot*.exe' }
}

function Listar-Exes-Dos-Processos-SimpleInstaBot {
    $resultado = @()

    foreach ($proc in (Listar-Processos-SimpleInstaBot)) {
        if (-not $proc.ExecutablePath) { continue }
        if ((Split-Path -Leaf $proc.ExecutablePath) -ne 'SimpleInstaBot.exe') { continue }

        $asar = Join-Path (Split-Path -Parent $proc.ExecutablePath) 'resources\app.asar'
        if (Test-Path -LiteralPath $asar) {
            $resultado += $proc.ExecutablePath
        }
    }

    $resultado | Select-Object -Unique
}

function Obter-Portas-Depuracao-SimpleInstaBot {
    $resultado = @()

    foreach ($proc in (Listar-Processos-SimpleInstaBot)) {
        if ($proc.CommandLine -and $proc.CommandLine -match '--remote-debugging-port=(\d+)') {
            $resultado += [int]$Matches[1]
        }
    }

    $resultado | Select-Object -Unique
}

function Recarregar-Janela-SimpleInstaBot {
    $portas = @(Obter-Portas-Depuracao-SimpleInstaBot)
    foreach ($porta in $portas) {
        try {
            $alvos = @(Invoke-RestMethod -Uri "http://127.0.0.1:$porta/json" -TimeoutSec 2)
            foreach ($alvo in $alvos) {
                if (-not $alvo.id) { continue }

                $id = [uri]::EscapeDataString($alvo.id)
                try {
                    Invoke-WebRequest -UseBasicParsing -Method Put -Uri "http://127.0.0.1:$porta/json/reload/$id" -TimeoutSec 2 | Out-Null
                } catch {
                    Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$porta/json/reload/$id" -TimeoutSec 2 | Out-Null
                }

                Write-Host ("  app: tela recarregada pela porta {0}" -f $porta)
                return $true
            }
        } catch {
            continue
        }
    }

    try {
        $shell = New-Object -ComObject WScript.Shell
        if ($shell.AppActivate('SimpleInstaBot')) {
            Start-Sleep -Milliseconds 300
            $shell.SendKeys('^r')
            Write-Host "  app: tela recarregada com Ctrl+R"
            return $true
        }
    } catch {
        return $false
    }

    return $false
}

function Corrigir-App-Se-Possivel([string]$ExeLocal) {
    try {
        return Corrigir-JsonHtmlDoApp -ExeLocal $ExeLocal
    } catch {
        Write-Host ("  patch app: aguardando pacote liberar ({0})" -f $_.Exception.Message) -ForegroundColor Yellow
        return "erro-temporario"
    }
}

function Preparar-Migracao-Do-Bot {
    $backupDir = Join-Path $appDir ("_backup_migracao_codex\" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $moveuAlgum = $false

    foreach ($nome in $jsonsObrigatorios) {
        $generico = Join-Path $appDir $nome
        $fonte = Escolher-Fonte-Historico $nome

        if ($fonte -and ($fonte -ne $generico)) {
            Copy-Item -LiteralPath $fonte -Destination $generico -Force
        } elseif (-not (Test-Path -LiteralPath $generico)) {
            Escrever-Array-Vazio $generico
        }

        $null = Garantir-Json $generico
    }

    foreach ($usuarioLocal in $usuariosMigracao) {
        foreach ($nome in $jsonsObrigatorios) {
            $destino = Join-Path $appDir "$usuarioLocal-$nome"
            if (-not (Test-Path -LiteralPath $destino)) { continue }

            if (-not $moveuAlgum) {
                New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
                $moveuAlgum = $true
            }

            Move-Item -LiteralPath $destino -Destination (Join-Path $backupDir (Split-Path -Leaf $destino)) -Force
            Write-Host ("  colisao guardada em backup: {0}" -f (Split-Path -Leaf $destino))
        }
    }
}

function Achar-Exe-SimpleInstaBot {
    param([string]$Preferido)

    $candidatos = @()
    if ($Preferido) { $candidatos += $Preferido }

    # Adicione aqui o caminho onde voce instalou o SimpleInstaBot-win.exe
    $candidatos += @(
        (Join-Path $runtimeDir 'SimpleInstaBot.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\SimpleInstaBot\SimpleInstaBot.exe'),
        (Join-Path $env:USERPROFILE 'Documents\SimpleInstaBot\SimpleInstaBot-win.exe'),
        (Join-Path $env:USERPROFILE 'Downloads\SimpleInstaBot-win.exe')
    )

    foreach ($candidato in $candidatos) {
        if ($candidato -and (Test-Path -LiteralPath $candidato)) {
            return (Resolve-Path -LiteralPath $candidato).Path
        }
    }

    $buscas = @(
        $env:LOCALAPPDATA,
        (Join-Path $env:USERPROFILE 'Downloads'),
        (Join-Path $env:USERPROFILE 'Documents')
    )

    foreach ($raiz in $buscas) {
        if (-not (Test-Path -LiteralPath $raiz)) { continue }

        $achado = Get-ChildItem -LiteralPath $raiz -Recurse -Filter 'SimpleInstaBot*.exe' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($achado) { return $achado.FullName }
    }

    return $null
}

function Corrigir-Apps-Extraidos {
    foreach ($extraido in (Listar-Exes-Extraidos-SimpleInstaBot)) {
        $null = Corrigir-App-Se-Possivel -ExeLocal $extraido
    }
}

function Achar-Exe-Runtime-Estavel {
    $exe = Join-Path $runtimeDir 'SimpleInstaBot.exe'
    $asar = Join-Path $runtimeDir 'resources\app.asar'

    if ((Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath $asar)) {
        return (Resolve-Path -LiteralPath $exe).Path
    }

    return $null
}

function Preparar-Runtime-Estavel {
    $existente = Achar-Exe-Runtime-Estavel
    if ($existente) {
        $null = Corrigir-App-Se-Possivel -ExeLocal $existente
        return $existente
    }

    $fonteExe = @(Listar-Exes-Extraidos-SimpleInstaBot | Select-Object -First 1)[0]
    if (-not $fonteExe) { return $null }

    $fonteDir = Split-Path -Parent $fonteExe
    try {
        New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
        Get-ChildItem -LiteralPath $fonteDir -Force |
            Copy-Item -Destination $runtimeDir -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Host ("  runtime estavel: nao consegui copiar agora ({0})" -f $_.Exception.Message) -ForegroundColor Yellow
        return $null
    }

    $exeDestino = Achar-Exe-Runtime-Estavel
    if ($exeDestino) {
        $null = Corrigir-App-Se-Possivel -ExeLocal $exeDestino
        Write-Host ("  runtime estavel: pronto em {0}" -f $runtimeDir)
        return $exeDestino
    }

    return $null
}

function Aguardar-Extracao-E-Corrigir {
    # BUG FIX: timeout aumentado de 45s para 90s para cobrir casos de
    # reextracao apos logout — o bot cria uma pasta Temp nova e o script
    # precisa de mais tempo para encontra-la e aplicar o patch.
    param([int]$TimeoutSegundos = 90)

    $vistos = @{}
    $aplicou = $false
    $temAppExtraido = $false
    $limite = (Get-Date).AddSeconds($TimeoutSegundos)

    while ((Get-Date) -lt $limite) {
        $exes = @(
            Listar-Exes-Dos-Processos-SimpleInstaBot
            Listar-Exes-Extraidos-SimpleInstaBot
        ) |
            Where-Object { $_ } |
            Select-Object -Unique

        foreach ($extraido in $exes) {
            if ($vistos.ContainsKey($extraido)) { continue }

            $status = Corrigir-App-Se-Possivel -ExeLocal $extraido
            if ($status -eq 'aplicado') {
                $aplicou = $true
                $temAppExtraido = $true
                $vistos[$extraido] = $true
            } elseif ($status -eq 'ja-aplicado') {
                $temAppExtraido = $true
                $vistos[$extraido] = $true
            } elseif ($status -eq 'trecho-nao-encontrado') {
                $vistos[$extraido] = $true
            }
        }

        if ($temAppExtraido -and @((Obter-Portas-Depuracao-SimpleInstaBot)).Count -gt 0) {
            break
        }

        Start-Sleep -Milliseconds 500
    }

    if ($aplicou) {
        Start-Sleep -Milliseconds 500
        if (-not (Recarregar-Janela-SimpleInstaBot)) {
            Write-Host "  app: patch aplicado; se a tela antiga continuar, feche e abra por este wrapper." -ForegroundColor Yellow
        }
    }

    return $temAppExtraido
}

# ─── Inicio ────────────────────────────────────────────────────────────────────

New-Item -ItemType Directory -Force -Path $appDir | Out-Null

$usuariosJaNoDisco = foreach ($nome in $jsonsObrigatorios) {
    Get-ChildItem -LiteralPath $appDir -File -Filter "*-$nome" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.bak-*' } |
        ForEach-Object { $_.Name.Substring(0, $_.Name.Length - $nome.Length - 1) }
}
$usuariosMigracao = @($usuariosMigracao + $usuariosJaNoDisco) |
    Where-Object { $_ } |
    Select-Object -Unique

Write-Host ""
Write-Host "=== SimpleInstaBot: reparo seguro ==="

Preparar-Migracao-Do-Bot

foreach ($nome in $jsonsObrigatorios) {
    $caminho = Join-Path $appDir $nome
    $status = Garantir-Json $caminho
    Write-Host ("  {0}: {1}" -f $nome, $status)
}

Corrigir-Apps-Extraidos

if (-not $Exe) {
    $null = Preparar-Runtime-Estavel
}

$exeBot = Achar-Exe-SimpleInstaBot -Preferido $Exe
if (-not $exeBot) {
    Write-Host ""
    Write-Host "Nao achei o executavel do SimpleInstaBot." -ForegroundColor Yellow
    Write-Host "Opcoes:"
    Write-Host "  1. Passe o caminho com -Exe 'C:\caminho\para\SimpleInstaBot-win.exe'"
    Write-Host "  2. Coloque o .exe em: $env:USERPROFILE\Documents\SimpleInstaBot\"
    exit 1
}

$asarDoExe = Join-Path (Split-Path -Parent $exeBot) 'resources\app.asar'
if (Test-Path -LiteralPath $asarDoExe) {
    $null = Corrigir-JsonHtmlDoApp -ExeLocal $exeBot
}

if ($CorrigirSomente) {
    Write-Host ""
    Write-Host "Arquivos e app prontos. Nao abri o bot." -ForegroundColor Green
    exit 0
}

if ($Reiniciar) {
    Get-Process |
        Where-Object { $_.ProcessName -like 'SimpleInstaBot*' } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

$electronRunAsNodeAnterior = $env:ELECTRON_RUN_AS_NODE
try {
    Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
    $processo = Start-Process -FilePath $exeBot -WorkingDirectory (Split-Path -Parent $exeBot) -PassThru
} finally {
    if ($null -eq $electronRunAsNodeAnterior) {
        Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
    } else {
        $env:ELECTRON_RUN_AS_NODE = $electronRunAsNodeAnterior
    }
}

$temAppExtraido = Aguardar-Extracao-E-Corrigir -TimeoutSegundos 90

$processosBot = @(Listar-Processos-SimpleInstaBot)

if ($processo.HasExited -and -not $processosBot) {
    Write-Host ""
    Write-Host "O SimpleInstaBot abriu e fechou logo em seguida." -ForegroundColor Yellow
    Write-Host "Os arquivos locais foram reparados; tente abrir de novo pelo atalho seguro."
    exit 1
}

if (-not $temAppExtraido) {
    Write-Host "Nao consegui confirmar o app.asar temporario ativo; se aparecer erro antigo, rode este wrapper de novo." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "SimpleInstaBot aberto depois do reparo." -ForegroundColor Green
Write-Host "Eu nao apertei Start, nao fiz login e nao publiquei nada."
Write-Host ""

