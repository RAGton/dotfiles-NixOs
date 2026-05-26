# Atalhos do Teclado (Kryonix Desktop)

Este guia contém os principais atalhos de teclado configurados no Hyprland para o ambiente Kryonix.

A tecla principal (**$mainMod**) é definida como a tecla **SUPER** (Windows/Command).

## 🪟 Gerenciamento de Janelas

| Atalho | Ação |
| :--- | :--- |
| `Super + Q` | Fechar janela ativa |
| `Super + F` | Alternar modo flutuante |
| `Super + CTRL + M` | Alternar tela cheia (fullscreen) |
| `Super + Return` | Trocar janela com a principal (master) |
| `Super + R` | Alternar orientação do layout (horizontal/vertical) |
| `Super + Tab` | Abrir menu de janelas |
| `Super + SHIFT + M` | Mover janela para o workspace especial (minimizar) |
| `Super + SHIFT + P` | Alternar visibilidade do workspace especial |
| `CTRL + ALT + Q` | Sair do Hyprland (Logout) |
| `CTRL + ALT + C` | Centralizar janela ativa |

## 🎯 Foco e Navegação

| Atalho | Ação |
| :--- | :--- |
| `Super + H` | Mover foco para a esquerda |
| `Super + L` | Mover foco para a direita |
| `Super + K` | Mover foco para cima |
| `Super + J` | Mover foco para baixo |
| `Super + [1-0]` | Mover para o workspace 1-10 |
| `Super + SHIFT + [1-0]` | Mover janela para o workspace 1-10 |
| `Super + Scroll Mouse` | Navegar entre workspaces |

## 📏 Redimensionamento

| Atalho | Ação |
| :--- | :--- |
| `Super + SHIFT + Seta Esquerda` | Diminuir largura |
| `Super + SHIFT + Seta Direita` | Aumentar largura |
| `Super + SHIFT + Seta Cima` | Diminuir altura |
| `Super + SHIFT + Seta Baixo` | Aumentar altura |
| `Super + Botão Esquerdo Mouse` | Mover janela |
| `Super + Botão Direito Mouse` | Redimensionar janela |

## 🚀 Aplicativos Rápidos

| Atalho | Ação |
| :--- | :--- |
| `Super + T` | Abrir Terminal (Kryonix Terminal) |
| `Super + E` | Abrir Gerenciador de Arquivos (Dolphin) |
| `Super + C` | Abrir Calculadora (Menu rápido) |
| `Super + SHIFT + B` | Abrir Navegador (Brave) |
| `Super + SHIFT + G` | Abrir AI Agent (Codex) |
| `Super + CTRL + E` | Abrir Analisador de Disco (Filelight) |

## 🐚 Shell e Launcher

| Atalho | Ação |
| :--- | :--- |
| `Super + A` | Abrir Launcher de Aplicativos |
| `Super + D` | Abrir Menu de Ações Rápidas |
| `Super + G` | Abrir Dashboard do Shell |
| `Super + V` | Abrir Histórico de Clipboard |
| `Super + N` | Abrir Central de Notificações |
| `Super + X` | Abrir Menu de Energia (Power Menu) |

## 🛠️ Utilidades e Sistema

| Atalho | Ação |
| :--- | :--- |
| `Super + L` ou `CTRL+ALT+L` | Bloquear tela |
| `Super + M` | Play/Pause (Mídia) |
| `Super + O` | Configurações de Áudio |
| `Super + W` | Configurações de Rede |
| `Super + SHIFT + C` | Seletor de Cores (Color Picker) |
| `Super + SHIFT + BS` | Limpar todas as notificações |
| `CTRL + ALT + P` | Alternar Temporizador Pomodoro |

## 📸 Captura de Tela e Gravação

| Atalho | Ação |
| :--- | :--- |
| `Print` | Capturar área selecionada (copia para clipboard) |
| `Super + Print` | Capturar tela inteira (salva em imagens + copia) |
| `Super + SHIFT + Print` | Capturar janela ativa (salva em imagens + copia) |
| `Super + CTRL + S` | Editar captura de tela |
| `Super + SHIFT + S` | Congelar tela para inspeção |
| `Super + SHIFT + R` | Iniciar/Parar gravação de tela rápida |
| `Super + CTRL + R` | Abrir menu de gravação de tela |

## 🔉 Controle de Hardware

| Atalho | Ação |
| :--- | :--- |
| `Vol +` / `Vol -` | Aumentar/Diminuir volume |
| `Mute` | Alternar mudo (Áudio) |
| `Mic Mute` | Alternar mudo (Microfone) |
| `Brilho +` / `Brilho -` | Aumentar/Diminuir brilho da tela |
| `SHIFT + Brilho` | Controle de brilho do teclado |

## 🖥️ Multi-Monitor

Requer `kryonix-monitors` instalado (disponível em hosts Hyprland automaticamente).

| Atalho | Ação |
| :--- | :--- |
| `Super + P` | Abrir menu interativo de monitores (rofi) |
| `Super + Alt + P` | Ciclar modos: Estender → Duplicar → Interno → Externo |
| `Super + .` | Mover foco para o próximo monitor |
| `Super + ,` | Mover foco para o monitor anterior |
| `Super + SHIFT + .` | Mover janela ativa para o próximo monitor |
| `Super + SHIFT + ,` | Mover janela ativa para o monitor anterior |
| `Super + CTRL + .` | Mover workspace inteiro para o próximo monitor |
| `Super + CTRL + ,` | Mover workspace inteiro para o monitor anterior |
| `Super + Alt + S` | Trocar posição entre os 2 monitores |

### Subcomandos CLI `kryonix-monitors`

```bash
kryonix-monitors                          # Lista monitores ativos e modo salvo
kryonix-monitors mode extend              # Estender lado a lado
kryonix-monitors mode duplicate           # Espelhar todos no monitor interno
kryonix-monitors mode internal            # Só tela interna (desliga externos)
kryonix-monitors mode external            # Só monitor externo (desliga interno)
kryonix-monitors mode toggle              # Cicla entre os modos acima
kryonix-monitors primary <output>         # Define monitor primário
kryonix-monitors resolution <out> <res>   # Muda resolução em runtime (ex: 2560x1440@144)
kryonix-monitors position <out> <pos>     # Reposiciona monitor (ex: 1920x0)
kryonix-monitors scale <out> <fator>      # Muda escala (ex: 1.25)
kryonix-monitors swap                     # Troca posição entre 2 monitores
kryonix-monitors menu                     # Menu rofi interativo
kryonix-monitors restore                  # Restaura último modo salvo (exec-once automático)
```

Estado persistente salvo em `~/.local/state/kryonix/monitor-mode`.
