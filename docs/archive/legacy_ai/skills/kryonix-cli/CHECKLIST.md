# Checklist: Kryonix CLI

- confirmar se a tarefa pertence mesmo à CLI `kryonix`
- validar host detectado e `--host` explícito quando necessário
- validar resolução de flake antes de executar ação principal
- manter mensagens de erro curtas, diretas e úteis
- não quebrar `doctor` ao adicionar novos subcomandos
- diferenciar inspeção, snapshot, gerações e rollback
- evitar comportamento destrutivo sem confirmação clara de intenção
- manter compatibilidade com desenvolvimento local e `/etc/kryonix`
