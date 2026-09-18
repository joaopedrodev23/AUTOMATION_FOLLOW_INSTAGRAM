# SimpleInstaBot Wrapper

> **Abre o [SimpleInstaBot](https://github.com/mifi/SimpleInstaBot) sem quebrar.**  
> Wrapper PowerShell que repara os bugs de sessão automaticamente toda vez que você abre o app.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-lightgrey.svg)](https://github.com/joaopedrodev23/AUTOMATION_FOLLOW_INSTAGRAM)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://github.com/joaopedrodev23/AUTOMATION_FOLLOW_INSTAGRAM)

---

## O problema

O SimpleInstaBot é ótimo, mas tem dois bugs chatos que aparecem toda hora:

| Bug | Sintoma | Causa |
|-----|---------|-------|
| **ENOENT ao reabrir** | Bot fecha sozinho logo depois de abrir | Ao deslogar, o app apaga os JSONs de controle. Na próxima abertura ele procura e não acha |
| **Tela branca / crash** | Bot para no meio do follow | O Instagram retorna HTML em endpoints que o bot espera JSON — derruba a sessão |

Este wrapper resolve **os dois** antes de abrir o app, sem tocar em senha, cookie ou config.

---

## Como funciona

```
você clica no atalho
       │
       ▼
wrapper repara followed.json, unfollowed.json, liked-photos.json
       │
       ▼
wrapper aplica patch no app.asar (fix do HTML inesperado)
       │
       ▼
SimpleInstaBot abre normalmente ✓
```

---

## Instalação

### 1. Baixe o SimpleInstaBot

👉 [github.com/mifi/SimpleInstaBot/releases](https://github.com/mifi/SimpleInstaBot/releases)

Baixe o `SimpleInstaBot-win.exe` e coloque em qualquer pasta. O wrapper acha automaticamente.

### 2. Clone este repositório

```cmd
git clone https://github.com/joaopedrodev23/AUTOMATION_FOLLOW_INSTAGRAM.git
cd AUTOMATION_FOLLOW_INSTAGRAM
```

### 3. Configure seu usuário

Abra `abrir-simpleinstabot.ps1` e edite a linha:

```powershell
[string]$Usuario = 'SEU_USUARIO_INSTAGRAM'
```

Substitua `SEU_USUARIO_INSTAGRAM` pelo seu usuário do Instagram (sem @).

### 4. Pronto — dê duplo clique

```
abrir-simpleinstabot.cmd  ← duplo clique aqui
```

Se o Windows perguntar sobre política de execução, clique em **Executar assim mesmo**.

---

## Uso via terminal

```powershell
# Abrir normalmente
.\abrir-simpleinstabot.ps1 -Usuario minha.conta

# Fechar instâncias travadas e reabrir
.\abrir-simpleinstabot.ps1 -Reiniciar

# Só reparar os arquivos, sem abrir o bot
.\abrir-simpleinstabot.ps1 -CorrigirSomente

# Especificar o caminho do .exe manualmente
.\abrir-simpleinstabot.ps1 -Exe "C:\Downloads\SimpleInstaBot-win.exe"
```

---

## Parâmetros

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `-Usuario` | string | Seu usuário do Instagram (sem @) |
| `-Exe` | string | Caminho para o `.exe` se não for encontrado automaticamente |
| `-Reiniciar` | switch | Fecha instâncias existentes antes de abrir |
| `-CorrigirSomente` | switch | Repara os arquivos sem abrir o bot |

---

## O que o wrapper faz

✅ Garante que `followed.json`, `unfollowed.json` e `liked-photos.json` existam e sejam JSON válido  
✅ Faz backup automático antes de reparar qualquer arquivo corrompido  
✅ Aplica patch no `app.asar` do Electron para tratar respostas HTML sem derrubar o bot  
✅ Aguarda até 90 segundos pela extração do pacote e aplica o patch na pasta temporária nova  
✅ Recarrega a janela automaticamente via DevTools protocol após aplicar o patch  

## O que o wrapper NÃO faz

❌ Não toca em senha, cookie ou `config.json`  
❌ Não faz login automático  
❌ Não aperta Start  
❌ Não publica nada  

---

## Onde o SimpleInstaBot salva os dados

```
%APPDATA%\SimpleInstaBot\
```

Os JSONs de controle ficam aqui. O wrapper cria e repara esses arquivos automaticamente.

---

## Requisitos

- Windows 10 / 11
- PowerShell 5.1 ou superior *(já vem no Windows — não precisa instalar nada)*
- [SimpleInstaBot](https://github.com/mifi/SimpleInstaBot/releases) baixado

---

## Créditos

- [SimpleInstaBot](https://github.com/mifi/SimpleInstaBot) por [@mifi](https://github.com/mifi) — MIT License

---

## Licença

[MIT](LICENSE) — use, modifique e distribua à vontade.
