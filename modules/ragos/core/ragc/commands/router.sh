COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  switch|deploy)  cmd_switch "$@" ;;
  rollback)       cmd_rollback "$@" ;;
  list|ls)        cmd_list ;;
  status)         cmd_status ;;
  gc)             cmd_gc "${1:-$KEEP_VERSIONS}" ;;
  doctor)         cmd_doctor ;;
  help|--help|-h) cmd_help ;;
  --version|-v)   echo "ragc $VERSION" ;;
  "")
    echo "ragc: faltando comando. Use: ragc switch"
    exit 1
    ;;
  *)
    echo "ragc: comando desconhecido '$COMMAND'. Use: ragc help"
    exit 1
    ;;
esac
