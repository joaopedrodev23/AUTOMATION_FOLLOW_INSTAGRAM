# SimpleInstaBot Wrapper & Patches

> **Abre e roda o [SimpleInstaBot](https://github.com/mifi/SimpleInstaBot) 100% atualizado para 2026.**  
> Repara bugs de login, seletores em Português, coleta moderna de seguidores (REST API + modal fallback) e banco de dados local.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/platform-Windows-lightgrey.svg)](https://github.com/joaopedrodev23/AUTOMATION_FOLLOW_INSTAGRAM)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://github.com/joaopedrodev23/AUTOMATION_FOLLOW_INSTAGRAM)

---

## 🚀 O que foi corrigido nesta versão

O projeto original do SimpleInstaBot foi abandonado há alguns anos e começou a falhar com as mudanças do Instagram. Esta versão inclui correções completas:

| Problema Antigo | Sintoma | Solução Implementada |
|-----------------|---------|----------------------|
| **0 seguidores seguidos** | Robô finalizava o lote sem seguir ninguém (`User followers batch []`) | A query GraphQL legada foi desativada pelo Instagram. Implementamos **coleta dupla**: API REST `/api/v1/friendships` autenticada + scraping visual do modal de seguidores (`div[role="dialog"]`). |
| **Idioma em Português** | Botões não eram encontrados | Suporte nativo aos seletores em português (`Seguir`, `Seguindo`, `Curtir`, `Fechar`, contadores em `mil`, etc.). |
| **Erro `dest already exists.`** | Pop-up de erro ao clicar em Start | Migração segura do banco de dados de histórico (`initInstautoDb`), tratando arquivos existentes sem conflito. |
| **ENOENT / Crash ao abrir** | Bot fecha sozinho logo ao iniciar | Script reparador que recria e valida os JSONs em `%APPDATA%\SimpleInstaBot` automaticamente. |
| **Prompt "abre e fecha"** | `abrir-simpleinstabot.cmd` fechava instantaneamente | Correção de variáveis de ambiente (`ELECTRON_RUN_AS_NODE`), desvinculação limpa de processos e controle de fluxo seguro com confirmação visual. |

---

## 🛠️ Como Usar

### 1. Clonar o repositório
```cmd
git clone https://github.com/joaopedrodev23/AUTOMATION_FOLLOW_INSTAGRAM.git
cd AUTOMATION_FOLLOW_INSTAGRAM
```

### 2. Abrir o programa
Basta dar duplo clique em:
```text
abrir-simpleinstabot.cmd
```
O script cuidará de tudo:
1. Valida e prepara os arquivos de banco de dados (`followed.json`, etc.).
2. Sincroniza o pacote corrigido (`resources/app.asar`).
3. Inicia o aplicativo e confirma a inicialização no terminal.

> 💡 **Dica:** Você também pode usar o script auxiliar `importar-sessao.cmd` caso seu Instagram exija verificação ou CAPTCHA no navegador. Ele permite colar o cookie `sessionid` para entrar diretamente conectado!

---

## 💻 Uso via Terminal (Opcional)

```powershell
# Abrir normalmente passando o usuário desejado
.\abrir-simpleinstabot.ps1 -Usuario seu.usuario

# Fechar processos travados e reabrir do zero
.\abrir-simpleinstabot.ps1 -Reiniciar

# Apenas reparar os arquivos locais sem abrir o app
.\abrir-simpleinstabot.ps1 -CorrigirSomente
```

---

## ⚙️ Parâmetros do Script

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `-Usuario` | string | Usuário do Instagram alvo (sem @). Se omitido, detecta do `config.json` ou solicita na tela. |
| `-Exe` | string | Caminho alternativo para o executável `SimpleInstaBot.exe` caso esteja em outro local. |
| `-Reiniciar` | switch | Encerra instâncias antigas antes de iniciar. |
| `-CorrigirSomente` | switch | Apenas valida/repara os JSONs sem iniciar o executável. |

---

## 📁 Onde os dados são salvos

Os bancos de dados e preferências ficam na pasta padrão do usuário no Windows:
```text
%APPDATA%\SimpleInstaBot\
```
Arquivos gerenciados:
- `<usuario>-followed.json`
- `<usuario>-unfollowed.json`
- `<usuario>-liked-photos.json`
- `config.json`

---

## 🛡️ Segurança e Privacidade

- **100% Open Source**: Nenhum dado sensível, senha ou token fica salvo no repositório.
- **Armazenamento Local**: Suas credenciais e cookies ficam apenas na sua máquina local (`%APPDATA%`).
- O bot roda diretamente pelo Chromium/Electron do seu computador.

---

## 📜 Licença

Distribuído sob a licença [MIT](LICENSE). Sinta-se livre para usar, estudar e aprimorar.
