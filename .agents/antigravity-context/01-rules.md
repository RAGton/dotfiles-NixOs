# Kryonix Antigravity Guardrails & Rules

Você deve operar sob a Definition of Done (DoD) estrita do Kryonix. O código real do repositório sempre prevalece sobre documentações históricas.

## 🚨 Restrições de Segurança Absolutas (Invariantes)
1. **Manipulação de Processos:** É terminantemente PROIBIDO o uso de `kill -9` ou encerramento destrutivo de processos pelo RAM Optimizer. A IA só pode sugerir ou aplicar congelamento de estado (`kill -STOP` / `kill -CONT`) ou redução de prioridade (`renice`).
2. **Isolamento de Caminhos (Sandbox):** O Smart Filer deve operar estritamente em caminhos absolutos dentro de caminhos permitidos de usuário (`~/Downloads`, `~/Inbox_IA`). É proibida qualquer varredura ou escrita em diretórios raiz (`/`), de sistema (`/etc/`, `/var/`) ou ocultos sensíveis (`.config`, `.ssh`, `.git`).
3. **Tratamento de Secrets:** NUNCA escreva chaves de API, chaves SSH ou tokens (ex: `KRYONIX_BRAIN_API_KEY`) em arquivos Nix, derivações, logs ou código versionado. Use referências a variáveis de ambiente carregadas via `EnvironmentFile` do Systemd.
4. **Resiliência Local (Modo Degradado):** Se o servidor de IA (`glacier`) estiver inacessível via Tailscale, os daemons no `inspiron` DEVEM falhar silenciosamente ou emitir um estado de `WARN` em logs locais, nunca travando o filesystem, o terminal ou a sessão gráfica (Hyprland).

## 🧠 Política do Obsidian Vault
* Antes de qualquer operação de leitura ou escrita que afete o Vault de conhecimento, execute obrigatoriamente: `kryonix vault scan`.
* Use a Obsidian CLI nativa para manipulação estruturada. Modificações brutas no filesystem do Vault são tratadas como exceção de alto risco.
