# AUTOMATION_FOLLOW_INSTAGRAM

> Wrapper PowerShell para o [SimpleInstaBot](https://github.com/mifi/SimpleInstaBot) que corrige automaticamente os bugs de sessao e aplica patches de compatibilidade com o Instagram atual.

## O que faz

O SimpleInstaBot (app Electron de terceiros, open source) tem dois problemas comuns:

1. **ENOENT ao reabrir** — ao deslogar ou trocar de conta, o bot apaga os JSONs de controle (`followed.json`, `unfollowed.json`, `liked-photos.json`). Na proxima abertura ele morre com erro de arquivo nao encontrado.

2. **Tela branca / crash com HTML** — o Instagram ocasionalmente retorna HTML em endpoints que o bot espera JSON, derrubando a sessao.

Este wrapper resolve os dois antes de abrir o app.

## Requisitos

- Windows 10/11
- PowerShell 5.1 ou superior (ja vem no Windows)
- [SimpleInstaBot](https://github.com/mifi/SimpleInstaBot/releases) instalado ou o `.exe` baixado

## Como usar

### 1. Configure seu usuario

Edite `abrir-simpleinstabot.ps1` e altere o parametro padrao:

```powershell
[string]$Usuario = 'SEU_USUARIO_INSTAGRAM'
```

Troque `SEU_USUARIO_INSTAGRAM` pelo seu usuario do Instagram (sem @).

### 2. Abra pelo CMD (duplo clique ou terminal)

```cmd
abrir-simpleinstabot.cmd
```

Ou pelo PowerShell diretamente:

```powershell
.\abrir-simpleinstabot.ps1 -Usuario minha.conta
```

### 3. Parametros disponiveis

| Parametro | Descricao |
|---|---|
| `-Usuario` | Seu usuario do Instagram (sem @) |
| `-Exe` | Caminho para o `.exe` se estiver fora das pastas padrao |
| `-Reiniciar` | Fecha instancias existentes antes de abrir |
| `-CorrigirSomente` | Repara os arquivos sem abrir o bot |

### Exemplos

```powershell
# Abrir normalmente
.\abrir-simpleinstabot.ps1 -Usuario minha.conta

# Fechar e reabrir (util apos travamento)
.\abrir-simpleinstabot.ps1 -Reiniciar

# Apenas reparar os arquivos sem abrir
.\abrir-simpleinstabot.ps1 -CorrigirSomente

# Passar o caminho do exe manualmente
.\abrir-simpleinstabot.ps1 -Exe "C:\Users\voce\Downloads\SimpleInstaBot-win.exe"
```

## O que o wrapper faz automaticamente

1. Garante que `followed.json`, `unfollowed.json` e `liked-photos.json` existam e sejam JSON valido (repara se estiverem vazios ou corrompidos)
2. Aplica patch no `app.asar` do Electron para tratar respostas HTML do Instagram sem derrubar o bot
3. Aguarda ate 90 segundos pela extracao do pacote e aplica o patch na pasta temporaria nova
4. Recarrega a janela automaticamente via DevTools protocol apos aplicar o patch

## O que o wrapper NAO faz

- Nao toca em senha, cookie ou `config.json`
- Nao faz login automatico
- Nao aperta Start
- Nao publica nada

## Onde o SimpleInstaBot salva os dados

```
%APPDATA%\SimpleInstaBot\
```

## Licenca

MIT — faca o que quiser, sem garantia.
