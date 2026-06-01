#!/usr/bin/env bash
# Kryonix Post-Install Healing Automaton
# Autor: Engenheiro de Sistemas Sênior

set -euo pipefail

FLAG_FILE="/etc/kryonix-installed"
INSTALLER_BIN="kryonix-installer"

echo "🤖 Iniciando Autômato de Cura Kryonix..."

if [[ ! -f "$FLAG_FILE" ]]; then
    echo "⚠️ Flag de instalação não encontrada ($FLAG_FILE)."
    echo "🔍 Executando verificação de integridade..."

    # Verificação de Usuários
    if ! id "rocha" &>/dev/null; then
        echo "❌ Erro: Usuário principal 'rocha' não encontrado!"
        BROKEN=1
    fi

    # Verificação de Chaves SSH (exemplo)
    if [[ ! -d "/home/rocha/.ssh" ]]; then
        echo "⚠️ Aviso: Chaves SSH não configuradas."
    fi

    if [[ "${BROKEN:-0}" -eq 1 ]]; then
        echo "🚨 Sistema detectado como 'quebrado'. Disparando instalador..."
        if command -v "$INSTALLER_BIN" &>/dev/null; then
            # Dispara o instalador em modo kiosk ou verificação
            # Nota: Isso assume ambiente gráfico ativo se for kiosk
            systemctl start kryonix-installer-kiosk.service || true
        else
            echo "❌ Erro fatal: $INSTALLER_BIN não encontrado no PATH."
        fi
    else
        echo "✅ Integridade básica OK. Criando flag retroativamente..."
        touch "$FLAG_FILE"
    fi
else
    echo "✅ Sistema validado como 'Kryonix Native'."
fi
