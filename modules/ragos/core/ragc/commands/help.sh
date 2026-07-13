cmd_help() {
  cat <<HELP

ragc — RAGOS Image Manager v$VERSION

USO
  ragc <comando> [opções]

COMANDOS
  switch [--channel CANAL] [--target NOME]
                        Constrói, publica e promove nova geração imutável
  rollback [VERSÃO]      Reverte instantaneamente para a versão anterior (ou para VERSÃO)
  list                   Lista gerações disponíveis com metadados e status
  status                 Mostra geração ativa, timestamp, caminhos e URLs
  gc [N]                 Limpa versões antigas com snapshot prévio, mantém as últimas N (padrão: $KEEP_VERSIONS)
  doctor                 Verifica saúde da infraestrutura (dnsmasq/nginx/NFS/etc)
  help                   Mostra esta ajuda

VARIÁVEIS DE AMBIENTE
  RAGOS_FLAKE=PATH       Caminho para o repositório RAGOS (auto-detectado se omitido)
  RAGC_SNAPSHOTS_ROOT    Diretório para snapshots pré-GC (padrão: /srv/data/snapshots)
  RAGC_GC_GRACE_SECONDS  Janela de proteção para diretórios recentes (padrão: 900)
  RAGC_GC_SNAPSHOT_KEEP  Quantidade de snapshots images-pre-gc-* retidos (padrão: 7)

EXEMPLOS
  ragc switch
  ragc switch --channel generic
  ragc switch --channel lab
  ragc switch --channel rescue
  ragc switch --target hyperv-debug
  ragc switch --target desktop-generic
  ragc switch --target desktop-lab
  ragc switch --target rescue-minimal
  ragc rollback
  ragc rollback --channel lab
  ragc rollback --channel rescue
  ragc rollback v20260305-120000
  ragc list
  ragc status
  ragc gc 3
  RAGOS_FLAKE=/etc/ragos ragc switch

  ragc doctor

PARÂMETROS EMBUTIDOS (build time)
  Servidor : $SERVER_IP
  HTTP     : $HTTP_PORT
  Imagens  : $IMAGES_ROOT
  Versão   : $VERSION

HELP
}
