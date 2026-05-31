#!/usr/bin/env bash
set -euo pipefail

# doc-audit.sh — Auditoria de documentação canônica Kryonix
# Garante que termos proibidos e comandos inconsistentes não cheguem ao main.

DOCS_DIR="$(dirname "$0")/../docs"
USAGE_FILE="$DOCS_DIR/USAGE.md"
MAIN_SH="$(dirname "$0")/../packages/kryonix-cli/main.sh"

echo "======================================"
echo "    AUDITORIA DE DOCUMENTAÇÃO Kryonix"
echo "======================================"

# [1] Verificando termos proibidos (TODO, WIP, etc)
# Nota: Usamos hífens para evitar que o próprio script seja pego se buscado.
echo "[1] Verificando termos proibidos na documentação canônica (T-O-D-O, W-I-P, etc)..."
if grep -rE "\bTODO\b|\bFIXME\b" \
        --exclude-dir=archive --exclude-dir=legacy --exclude-dir=operations \
        "$DOCS_DIR" .agents AGENTS.md > /dev/null 2>&1; then
    grep -rE "\bTODO\b|\bFIXME\b" \
        --exclude-dir=archive --exclude-dir=legacy --exclude-dir=operations \
        "$DOCS_DIR" .agents AGENTS.md || true
    echo "ERRO: Termos como TODO/WIP ou promessas futuras foram encontrados na documentação canônica."
    echo "Corrija os arquivos ou mova as promessas para ROADMAP.md."
    exit 1
fi
echo "✓ Nenhum termo proibido encontrado."

echo ""

# [2] Validando Comandos do USAGE.md contra main.sh
echo "[2] Validando Comandos do USAGE.md..."
if [ ! -f "$USAGE_FILE" ]; then
    echo "⚠ USAGE.md não encontrado em $USAGE_FILE"
    exit 0
fi

if [ ! -f "$MAIN_SH" ]; then
    echo "⚠ main.sh não encontrado em $MAIN_SH. Pulando validação de comandos."
    exit 0
fi

EXIT_CODE=0
# Extrai comandos do USAGE.md (formato: kryonix <comando>)
while read -r cmd; do
    # Procura o comando como ramo de case: word-boundary antes, ) ou | depois.
    # Cobre indentação variável e alternativas como "switch|boot)".
    if ! grep -qE "\b${cmd}[)|]" "$MAIN_SH"; then
        echo "ERRO: Comando 'kryonix $cmd' está documentado no USAGE.md, mas não foi encontrado no main.sh."
        EXIT_CODE=1
    fi
done < <(grep -oP '(?<=kryonix )[\w-]+' "$USAGE_FILE" | sort -u | grep -v 'mcp\|brain\|graph\|doctor\|health\|stats\|search\|ask\|print-config\|--help')

if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Todos os comandos documentados estão presentes na CLI."
else
    echo "FALHA: Inconsistência entre documentação e código da CLI."
fi

exit $EXIT_CODE
