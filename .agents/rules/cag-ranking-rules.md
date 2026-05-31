# CAG Ranking Rules
1. Documentos dentro de `docs/hosts/` e `.ai/skills/hosts/` têm prioridade.
2. Em queries sobre rebuild do Glacier, pontue altamente `docs/hosts/glacier-rebuild.md`.
3. Penali-ze e proíba (score 0) chunks que sugiram ISO, mkfs, mount manual, ou disko para hosts existentes.
