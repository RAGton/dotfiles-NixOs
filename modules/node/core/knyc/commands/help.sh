cmd_help() {
  cat <<HELP

knyc — NODE Image Manager v$VERSION

USO
  knyc <comando> [opções]

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
  NODE_FLAKE=PATH       Caminho para o repositório NODE (auto-detectado se omitido)
  KNYC_SNAPSHOTS_ROOT    Diretório para snapshots pré-GC (padrão: /srv/data/snapshots)
  KNYC_GC_GRACE_SECONDS  Janela de proteção para diretórios recentes (padrão: 900)
  KNYC_GC_SNAPSHOT_KEEP  Quantidade de snapshots images-pre-gc-* retidos (padrão: 7)

EXEMPLOS
  knyc switch
  knyc switch --channel generic
  knyc switch --channel lab
  knyc switch --channel rescue
  knyc switch --target hyperv-debug
  knyc switch --target desktop-generic
  knyc switch --target desktop-lab
  knyc switch --target rescue-minimal
  knyc rollback
  knyc rollback --channel lab
  knyc rollback --channel rescue
  knyc rollback v20260305-120000
  knyc list
  knyc status
  knyc gc 3
  NODE_FLAKE=/etc/node knyc switch

  knyc doctor

PARÂMETROS EMBUTIDOS (build time)
  Servidor : $SERVER_IP
  HTTP     : $HTTP_PORT
  Imagens  : $IMAGES_ROOT
  Versão   : $VERSION

HELP
}
