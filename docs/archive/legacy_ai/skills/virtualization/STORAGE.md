# Storage de Virtualização

Ponto central:

- `/srv/ragenterprise`

Subpastas operacionais esperadas:

- `images`
- `iso`
- `templates`
- `snippets`
- `backups`

Direção:

- pensar primeiro em libvirt/KVM
- evitar misturar storage operacional com definição base de hardware
- documentar risco antes de qualquer mudança que possa apagar, mover ou recriar conteúdo
