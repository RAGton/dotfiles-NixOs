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
  --version|-v)   echo "knyc $VERSION" ;;
  "")
    echo "knyc: faltando comando. Use: knyc switch"
    exit 1
    ;;
  *)
    echo "knyc: comando desconhecido '$COMMAND'. Use: knyc help"
    exit 1
    ;;
esac
