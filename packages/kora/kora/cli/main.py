# =============================================================================
# Kora — CLI
#
# Interface de linha de comando oficial para a assistente Kora.
# Focada em linguagem natural primeiro (NLP-First).
# =============================================================================

import sys
from ..voice.pipeline import chat

def main() -> None:
    """
    Ponto de entrada principal da Kora CLI.
    Rotia comandos com '/' para o admin CLI ou envia consultas em NLP direto.
    """
    if len(sys.argv) < 2:
        print_help()
        sys.exit(0)

    first_arg = sys.argv[1]

    # Atalhos para mute e unmute
    if first_arg in ("mute", "unmute", "/mute", "/unmute"):
        from . import admin
        clean_first_arg = first_arg.lstrip("/")
        admin.main([clean_first_arg] + sys.argv[2:])
        sys.exit(0)

    # Intercepta ajuda para exibir o menu do NLP-First
    if first_arg in ("/help", "help", "-h", "--help"):
        print_help()
        sys.exit(0)

    # Verifica se o primeiro argumento começa com barra (operacional/administrativo)
    if first_arg.startswith("/"):
        from . import admin
        # Remove a barra (ex: /voice -> voice, /config -> config)
        clean_first_arg = first_arg[1:]
        args_list = [clean_first_arg] + sys.argv[2:]
        admin.main(args_list)
    else:
        # Tudo que não começa com '/' vira linguagem natural direta
        query = " ".join(sys.argv[1:])
        chat(query)


def print_help() -> None:
    print("""
Kora CLI — Assistente Pessoal (Natural Language First)

Uso:
  kora "<pergunta>"     Envia uma consulta em linguagem natural diretamente para a assistente.
  kora /<comando>       Executa um comando operacional/administrativo.

Comandos operacionais comuns:
  /help                 Exibe esta ajuda.
  /version              Exibe a versão da assistente.
  /config               Gerencia as configurações locais do agente.

Exemplos:
  kora "como configurar o Tailscale?"
  kora /version
  kora /config list
""")


if __name__ == "__main__":
    main()
