#!/usr/bin/env python3
"""Validador estrutural de notas no formato yt-to-notebook.

Uso:
    python3 validar_nota.py <arquivo.md>

Confere as marcas do formato (H1, Mermaid, callouts, fences balanceados) e
pega erros comuns (fences quebrados, caractere não-latino acidental como um
cirílico que escapou no lugar de uma letra latina).

Filosofia de saída:
- exit 1  -> quebra estrutural objetiva (corrija antes de entregar):
             fences ``` desbalanceados, sem H1, ou caractere cirílico/grego acidental.
- exit 0  -> estrutura ok. Pode trazer avisos (⚠️) — o formato fica melhor com
             pelo menos 1 diagrama Mermaid e 1 callout, mas não é erro fatal.
- exit 2  -> uso incorreto / arquivo não encontrado.

Não exige tags, hub, índice nem pasta específica — o formato é portátil; a
organização é decisão do usuário.
"""
import re
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("uso: python3 validar_nota.py <arquivo.md>")
        return 2

    path = sys.argv[1]
    try:
        with open(path, encoding="utf-8") as f:
            s = f.read()
    except FileNotFoundError:
        print(f"❌ arquivo não encontrado: {path}")
        return 2

    erros, avisos, infos = [], [], []

    # H1 — estrutural
    if re.search(r"^# .+", s, re.MULTILINE):
        infos.append("H1 (título) presente")
    else:
        erros.append("sem H1 (todo nota precisa de um `# Título`)")

    # fences ``` balanceados — estrutural
    n_fences = len(re.findall(r"^```", s, re.MULTILINE))
    if n_fences % 2 == 0:
        infos.append(f"fences ``` balanceados ({n_fences})")
    else:
        erros.append(f"fences ``` desbalanceados (achei {n_fences}, número ímpar)")

    # caractere não-latino acidental (cirílico U+0400–04FF / grego U+0370–03FF) — estrutural
    estranhos = sorted(set(re.findall(r"[Ѐ-ӿͰ-Ͽ]", s)))
    if estranhos:
        erros.append("caractere não-latino acidental: " + " ".join(estranhos))
    else:
        infos.append("sem caractere cirílico/grego acidental")

    # Mermaid — recomendado
    n_mermaid = len(re.findall(r"^```mermaid", s, re.MULTILINE))
    if n_mermaid:
        infos.append(f"diagramas Mermaid: {n_mermaid}")
    else:
        avisos.append("nenhum diagrama Mermaid (o formato pede ao menos 1, e um mindmap no fim)")

    # Callouts — recomendado
    n_callouts = len(re.findall(r"^>\s*\[!", s, re.MULTILINE))
    if n_callouts:
        infos.append(f"callouts > [!...]: {n_callouts}")
    else:
        avisos.append("nenhum callout > [!...] (TL;DR, quote, tip, etc. deixam a nota muito mais legível)")

    # Frontmatter — informativo (não se aplica a Notion)
    if s.startswith("---"):
        infos.append("frontmatter YAML no topo")
    else:
        avisos.append("sem frontmatter no topo (ok para Notion; em markdown use titulo/fonte/data)")

    # Wikilinks — informativo
    n_wl = len(re.findall(r"\[\[", s))
    if n_wl:
        infos.append(f"wikilinks [[...]]: {n_wl} — só fazem sentido dentro de um vault Obsidian que os use")

    # relatório
    print(f"\n🔎 Validando: {path}\n")
    for t in infos:
        print(f"  ✅ {t}")
    for t in avisos:
        print(f"  ⚠️  {t}")
    for t in erros:
        print(f"  ❌ {t}")

    if erros:
        print("\n❌ Quebra estrutural — corrija os itens ❌ acima antes de entregar.\n")
        return 1
    if avisos:
        print("\n⚠️  Estrutura válida, mas vale revisar os avisos acima.\n")
        return 0
    print("\n✅ Tudo certo — a nota está no formato.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
