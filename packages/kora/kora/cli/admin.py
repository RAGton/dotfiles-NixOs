# =============================================================================
# Kora — Admin CLI
#
# Interface de linha de comando administrativa oficial para a assistente Kora.
# Permite gerenciar serviços, usuários, áudio, modelos e diagnósticos.
# =============================================================================

import argparse
import json
import logging
import os
import sys
import subprocess
import getpass
import asyncio
from pathlib import Path
from typing import Any

from rich.console import Console

from ..client import KoraClient, KoraClientError
from ..voice import devices, recorder, stt, tts, pipeline, daemon, identity, wakeword
from ..voice import vad as voice_vad
from ..voice import signals as voice_signals
from ..core import users
from ..integrations.n8n import trigger_n8n
from ..integrations.ha import call_ha


class CommandDispatcher:
    """
    Dispatcher inteligente de comandos do sistema com suporte a sudo seguro e auditoria de log.
    """
    def __init__(self):
        self.log_path = Path.home() / ".kryonix" / "logs" / "cli.log"
        self.log_path.parent.mkdir(parents=True, exist_ok=True)

    def log_command(self, cmd: list[str], success: bool):
        import datetime
        timestamp = datetime.datetime.now().isoformat()
        status = "SUCCESS" if success else "FAILED"
        try:
            with open(self.log_path, "a") as f:
                f.write(f"[{timestamp}] [{status}] {' '.join(cmd)}\n")
        except Exception as e:
            sys.stderr.write(f"Warning: Failed to write to log file: {e}\n")

    def needs_sudo(self, cmd: list[str]) -> bool:
        privileged_binaries = ["nixos-rebuild", "systemctl"]
        if os.geteuid() == 0:
            return False
        
        # Verifica se algum elemento do comando requer privilégios
        for word in cmd:
            if any(binary in word for binary in privileged_binaries):
                if "systemctl" in word and "--user" in cmd:
                    continue
                return True
        return False

    def execute(self, cmd: list[str], cwd: str = None) -> bool:
        from ..utils.lock import HardwareLock

        need_s = self.needs_sudo(cmd)
        
        run_cmd = cmd.copy()
        if need_s:
            if run_cmd[0] != "sudo":
                run_cmd = ["sudo", "-S"] + run_cmd
            elif "-S" not in run_cmd:
                run_cmd.insert(1, "-S")
                
        password = None
        if need_s:
            # getpass solicita a senha com echo desabilitado
            password = getpass.getpass(prompt="[sudo] senha: ")

        with HardwareLock():
            try:
                proc = subprocess.Popen(
                    run_cmd,
                    stdin=subprocess.PIPE if need_s else None,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    cwd=cwd
                )
                
                if need_s and password is not None:
                    stdout, stderr = proc.communicate(input=f"{password}\n")
                else:
                    stdout, stderr = proc.communicate()
                    
                if stdout:
                    sys.stdout.write(stdout)
                if stderr:
                    sys.stderr.write(stderr)
                    
                success = (proc.returncode == 0)
                self.log_command(cmd, success)
                return success
            except Exception as e:
                sys.stderr.write(f"Erro ao executar comando: {e}\n")
                self.log_command(cmd, False)
                return False


class KoraConfig:
    """
    Gerenciador de configurações locais da Kora (~/.config/kryonix/kora.env)
    """
    def __init__(self):
        self.user_config_path = Path.home() / ".config" / "kryonix" / "kora.env"
        self.global_config_path = Path("/etc/kryonix/kora.env")

    def _parse_file(self, path: Path) -> dict[str, str]:
        config = {}
        if not path.exists():
            return config
        try:
            with open(path, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if line.startswith("export "):
                        line = line[7:]
                    if "=" in line:
                        k, v = line.split("=", 1)
                        k = k.strip()
                        v = v.strip().strip("'\"")
                        config[k] = v
        except Exception as e:
            sys.stderr.write(f"Warning: erro ao ler {path}: {e}\n")
        return config

    def load_all(self) -> dict[str, str]:
        config = {}
        # 1. OS environment starting with KORA_
        for k, v in os.environ.items():
            if k.startswith("KORA_"):
                config[k] = v
        # 2. Global /etc/kryonix/kora.env
        config.update(self._parse_file(self.global_config_path))
        # 3. User ~/.config/kryonix/kora.env
        config.update(self._parse_file(self.user_config_path))
        return config

    def set(self, key: str, value: str) -> None:
        if not key.startswith("KORA_"):
            key = f"KORA_{key.upper()}"
        else:
            key = key.upper()

        if key == "KORA_VOICE_ENABLED":
            is_enabled = value.lower() in ("true", "1", "on", "yes")
            value = "true" if is_enabled else "false"

        config = self._parse_file(self.user_config_path)
        config[key] = value

        self.user_config_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            with open(self.user_config_path, "w") as f:
                for k, v in sorted(config.items()):
                    f.write(f'export {k}="{v}"\n')
            if key == "KORA_VOICE_ENABLED":
                status = "ativado" if value == "true" else "desativado"
                resp_mode = "com áudio" if value == "true" else "apenas por texto"
                print(f"✓ Modo de voz {status}. Kora responderá {resp_mode}.")
            else:
                print(f"✓ Configuração salva: {key}={value}")
        except Exception as e:
            sys.stderr.write(f"Erro ao salvar configuração em {self.user_config_path}: {e}\n")
            sys.exit(1)

    def delete(self, key: str) -> None:
        if not key.startswith("KORA_"):
            key = f"KORA_{key.upper()}"
        else:
            key = key.upper()

        config = self._parse_file(self.user_config_path)
        if key in config:
            del config[key]
            try:
                with open(self.user_config_path, "w") as f:
                    for k, v in sorted(config.items()):
                        f.write(f'export {k}="{v}"\n')
                print(f"✓ Configuração removida: {key}")
            except Exception as e:
                sys.stderr.write(f"Erro ao atualizar {self.user_config_path}: {e}\n")
                sys.exit(1)
        else:
            print(f"Configuração {key} não encontrada no escopo do usuário.")


def print_json(data: Any) -> None:
    """Print data as formatted JSON."""
    print(json.dumps(data, indent=2, ensure_ascii=False))


def print_table(title: str, data: dict[str, Any]) -> None:
    """Print data in a simple key-value table (fallback without rich)."""
    print(f"\n=== {title} ===")
    for k, v in data.items():
        if isinstance(v, dict):
            print(f"{k}:")
            for sub_k, sub_v in v.items():
                print(f"  {sub_k}: {sub_v}")
        elif isinstance(v, list):
            print(f"{k}:")
            for item in v:
                print(f"  - {item}")
        else:
            print(f"{k}: {v}")
    print()


def get_client(args: argparse.Namespace) -> KoraClient:
    """Instantiate the client based on args."""
    return KoraClient(url=args.url, timeout=args.timeout)


def handle_health(args: argparse.Namespace) -> None:
    client = get_client(args)
    try:
        res = client.health()
        if args.json:
            print_json(res)
        else:
            print_table("Kora Health", res)
    except KoraClientError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


def handle_status(args: argparse.Namespace) -> None:
    target = getattr(args, "target", "kora")
    if target == "nixos":
        dispatcher = CommandDispatcher()
        dispatcher.execute(["systemctl", "status"])
        return
    elif target == "brain":
        dispatcher = CommandDispatcher()
        dispatcher.execute(["systemctl", "status", "kryonix-brain-api.service"])
        return

    client = get_client(args)
    try:
        res = client.status()
        if args.json:
            print_json(res)
        else:
            print_table("Kora Status", res)
    except KoraClientError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


def handle_capabilities(args: argparse.Namespace) -> None:
    client = get_client(args)
    try:
        res = client.capabilities()
        if args.json:
            print_json(res)
        else:
            print_table("Kora Capabilities", res)
    except KoraClientError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


def handle_memory_search(args: argparse.Namespace) -> None:
    client = get_client(args)
    try:
        res = client.memory_search(query=args.query, mode=args.mode)
        if args.json:
            print_json(res)
        else:
            print_table(f"Memory Search Results (mode: {args.mode})", res)
    except KoraClientError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


def handle_voice_devices(args: argparse.Namespace) -> None:
    print("\n--- Dispositivos de Entrada ---")
    for d in devices.list_input_devices():
        print(f"  {d}")
    print("\n--- Dispositivos de Saída ---")
    for d in devices.list_output_devices():
        print(f"  {d}")


def handle_voice_doctor(args: argparse.Namespace) -> None:
    import shutil
    import pwd, grp
    from ..voice import models as voice_models
    print("\n=== KORA VOICE DOCTOR ===")

    print("\n[BINÁRIOS]")
    binaries = ["whisper-cli", "whisper-cpp", "whisper-cpp-cli", "piper-tts", "piper", "aplay", "arecord"]
    for b in binaries:
        path = shutil.which(b)
        if path:
            print(f"  {b}: FOUND ({path})")
        else:
            print(f"  {b}: MISSING")

    print("\n[MODELOS]")
    whisper = voice_models.resolve_whisper_model()
    if whisper:
        size_mb = round(whisper.stat().st_size / 1_048_576, 1)
        print(f"  Whisper: FOUND {whisper}  ({size_mb} MB)")
    else:
        print("  Whisper: MISSING")
    piper_m, piper_c = voice_models.resolve_piper_model()
    if piper_m:
        print(f"  Piper model:  FOUND {piper_m}")
    else:
        print("  Piper model:  MISSING")
    if piper_c:
        print(f"  Piper config: FOUND {piper_c}")
    else:
        print("  Piper config: MISSING")

    print("\n[DISPOSITIVOS DE ÁUDIO]")
    handle_voice_devices(args)

    print("\n[DIRETÓRIOS E PERMISSÕES]")
    dirs = [
        "/var/lib/kryonix/kora",
        "/var/lib/kryonix/kora/voice",
        "/var/lib/kryonix/kora/voice/profiles",
        "/var/lib/kryonix/kora/voice/models/whisper",
        "/var/lib/kryonix/kora/voice/models/piper",
    ]
    for d in dirs:
        if os.path.exists(d):
            st = os.stat(d)
            user = pwd.getpwuid(st.st_uid).pw_name
            group = grp.getgrgid(st.st_gid).gr_name
            perms = oct(st.st_mode)[-3:]
            print(f"  {d}: EXISTE ({user}:{group} {perms})")
        else:
            print(f"  {d}: MISSING")


def handle_voice_models_status(args: argparse.Namespace) -> None:
    from ..voice import models as voice_models
    voice_models.cmd_status()


def handle_voice_models_list(args: argparse.Namespace) -> None:
    from ..voice import models as voice_models
    voice_models.cmd_list()


def handle_voice_models_install(args: argparse.Namespace) -> None:
    from ..voice import models as voice_models
    kind = args.model_type.lower()
    name = args.model_name.lower()
    if kind == "whisper":
        voice_models.cmd_install_whisper(name)
    elif kind == "piper":
        voice_models.cmd_install_piper(name)
    else:
        print(f"[ERRO] Tipo desconhecido: '{kind}'. Use 'whisper' ou 'piper'.")


def handle_voice_test_mic(args: argparse.Namespace) -> None:
    rec = recorder.KoraRecorder()
    path = rec.record_to_file("test_mic.wav", seconds=args.seconds)
    print(f"Gravado em: {path}")


def handle_voice_transcribe(args: argparse.Namespace) -> None:
    rec = recorder.KoraRecorder()
    path = rec.record_to_file("temp_transcribe.wav", seconds=args.seconds)
    text = stt.transcribe_audio(path)
    print(f"Transcrição: {text}")


DEFAULT_SPEAK_TEXT = "Kora online, Ragton. Estou pronta para acompanhar você."


def handle_voice_speak(args: argparse.Namespace) -> None:
    from ..voice.voices import get_active_preset
    preset = get_active_preset()
    text = getattr(args, "text", None) or DEFAULT_SPEAK_TEXT
    if getattr(args, "test", False):
        text = "Kora online, Ragton. Testando voice atual com preset ativo."
    tts.speak_text_with_preset(text, preset=preset)


def handle_voice_voices(args: argparse.Namespace) -> None:
    from ..voice import voices as voice_voices
    cmd = args.voice_voices_command
    if cmd == "list":
        voice_voices.cmd_list()
    elif cmd == "current":
        voice_voices.cmd_current()
    elif cmd == "set":
        voice_voices.cmd_set(args.preset_name)
    elif cmd == "test":
        voice_voices.cmd_test()


SERVICE_UNIT = "kora-voice-listener.service"


def _systemctl_user(*subcmds: str, capture: bool = False) -> int | str:
    cmd = ["systemctl", "--user"] + list(subcmds)
    if capture:
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout + result.stderr
    return subprocess.run(cmd).returncode


def handle_voice_service(args: argparse.Namespace) -> None:
    cmd = args.voice_service_command
    if cmd == "enable":
        rc = _systemctl_user("enable", "--now", SERVICE_UNIT)
        if rc == 0:
            print(f"  ✓ {SERVICE_UNIT} habilitado e iniciado.")
            print("  ⚠ Wake-word real 'Kora' ainda pendente de modelo custom.")
        else:
            print(f"  ✗ Falha ao habilitar. Crie o unit primeiro via 'kryonix switch all'.")
    elif cmd == "disable":
        _systemctl_user("disable", "--now", SERVICE_UNIT)
        print(f"  ✓ {SERVICE_UNIT} desabilitado.")
    elif cmd == "start":
        _systemctl_user("start", SERVICE_UNIT)
        print(f"  ✓ {SERVICE_UNIT} iniciado.")
    elif cmd == "stop":
        _systemctl_user("stop", SERVICE_UNIT)
        print(f"  ✓ {SERVICE_UNIT} parado.")
    elif cmd == "restart":
        _systemctl_user("restart", SERVICE_UNIT)
        print(f"  ✓ {SERVICE_UNIT} reiniciado.")
    elif cmd == "status":
        out = _systemctl_user("status", "--no-pager", "-l", SERVICE_UNIT, capture=True)
        print(out or f"  {SERVICE_UNIT}: não encontrado ou não iniciado.")
    elif cmd == "logs":
        subprocess.run([
            "journalctl", "--user", "-u", SERVICE_UNIT,
            "--no-pager", "-n", "50"
        ])


def handle_listen(args: argparse.Namespace) -> None:
    ptt = getattr(args, "push_to_talk", False) or not getattr(args, "vad", False)
    try:
        asyncio.run(pipeline.listen_and_respond(push_to_talk=ptt))
    except KeyboardInterrupt:
        sys.exit(0)


def handle_voice_daemon(args: argparse.Namespace) -> None:
    if args.voice_daemon_command == "status":
        print_json({
            "status": "foundation",
            "ready": False,
            "note": "Daemon is currently in foundation mode. Use 'kora listen' for PTT."
        })
    elif args.voice_daemon_command == "start":
        print("Starting Kora Voice Daemon (Foundation)...")
        asyncio.run(daemon.run_daemon())
    elif args.voice_daemon_command == "run":
        logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
        logger = logging.getLogger("kora.voice.daemon")
        logger.info("Kora Voice Daemon starting in foreground (systemd mode)...")
        try:
            asyncio.run(daemon.run_daemon())
        except KeyboardInterrupt:
            logger.info("Daemon stopped by signal.")
    elif args.voice_daemon_command == "stop":
        print("Stopping Kora Voice Daemon... (Not yet implemented via CLI control)")


def handle_voice_mute(args: argparse.Namespace) -> None:
    mute_file = Path("/var/lib/kryonix/kora/voice/muted")
    mute_file.parent.mkdir(parents=True, exist_ok=True)
    mute_file.touch()
    print("  ✓ Microfone silenciado (Kora não processará áudio).")


def handle_voice_unmute(args: argparse.Namespace) -> None:
    mute_file = Path("/var/lib/kryonix/kora/voice/muted")
    if mute_file.exists():
        mute_file.unlink()
    print("  ✓ Microfone ativo novamente.")


def handle_mute(args: argparse.Namespace) -> None:
    mute_path = Path("/run/kryonix/kora_mute")
    try:
        if not mute_path.parent.exists():
            mute_path.parent.mkdir(parents=True, exist_ok=True)
            try:
                os.chmod(mute_path.parent, 0o777)
            except Exception:
                pass
        mute_path.touch()
        print("🔇 Mute ativado.")
    except Exception as e:
        sys.stderr.write(f"Erro ao ativar mute em {mute_path}: {e}\n")
        sys.exit(1)


def handle_unmute(args: argparse.Namespace) -> None:
    mute_path = Path("/run/kryonix/kora_mute")
    try:
        if mute_path.exists():
            mute_path.unlink()
        print("🔊 Kora falando.")
    except Exception as e:
        sys.stderr.write(f"Erro ao desativar mute em {mute_path}: {e}\n")
        sys.exit(1)


def handle_voice_status(args: argparse.Namespace) -> None:
    import shutil
    muted = Path("/var/lib/kryonix/kora/voice/muted").exists()
    session_file = Path("/var/lib/kryonix/kora/sessions/voice-current.json")
    has_session = session_file.exists()

    whisper_ok = shutil.which("whisper-cli") is not None
    piper_ok = shutil.which("piper") is not None or shutil.which("piper-tts") is not None

    from ..voice import models as voice_models
    whisper_model = voice_models.resolve_whisper_model()
    piper_model, _ = voice_models.resolve_piper_model()

    from ..voice.voices import get_active_preset_name
    preset = get_active_preset_name()

    status = {
        "voice_pipeline": "ready" if (whisper_ok and piper_ok and whisper_model and piper_model) else "incomplete",
        "stt": "ok" if (whisper_ok and whisper_model) else "missing",
        "tts": "ok" if (piper_ok and piper_model) else "missing",
        "microphone_muted": muted,
        "active_preset": preset,
        "active_session": has_session,
        "wake_word_ready": False,
        "background_service": "use 'kora voice service status' for details",
    }
    print_json(status)


def handle_user(args: argparse.Namespace) -> None:
    registry = users.UserRegistry()

    if args.user_command == "init":
        ragton = users.KoraUser(
            id="ragton",
            display_name="Ragton",
            full_name="Gabriel Aguiar Rocha",
            linux_user="rocha",
            github_user="RAGton",
            role="owner",
            permission_level="admin_owner",
            can_access_private_memory=True,
            can_request_commands=True,
            can_request_admin_actions=True,
            preferences=["Linux", "NixOS", "IA", "Development"]
        )
        nicoly = users.KoraUser(
            id="nicoly",
            display_name="Nicoly",
            linux_user="nina",
            role="trusted_partner",
            permission_level="trusted_user",
            preferences=["Culinária", "Design", "Filmes"]
        )
        registry.save_user(ragton)
        registry.save_user(nicoly)
        print("Initial users created: ragton, nicoly")

    elif args.user_command == "add":
        user = users.KoraUser(
            id=args.id,
            display_name=args.display_name,
            full_name=args.full_name,
            linux_user=args.linux_user,
            github_user=args.github,
            role=args.role,
            permission_level="admin_owner" if args.role == "owner" else "trusted_user"
        )
        registry.save_user(user)
        print(f"User {args.id} added.")

    elif args.user_command == "list":
        usrs = registry.list_users()
        data = {u.id: {"display": u.display_name, "role": u.role, "level": u.permission_level} for u in usrs}
        print_json(data)

    elif args.user_command == "show":
        user = registry.get_user(args.id)
        if user:
            print_json(user.to_dict())
        else:
            print(f"User {args.id} not found.")

    elif args.user_command == "remove":
        registry.delete_user(args.id)
        print(f"User {args.id} removed.")


def _current_learning_user() -> str:
    return os.environ.get("KORA_USER_ID") or os.environ.get("USER") or "unknown"


def handle_learning(args: argparse.Namespace) -> None:
    from .learning import LearningEngine

    user = _current_learning_user()
    engine = LearningEngine()
    cmd = args.learning_command

    if cmd == "status":
        print_json({
            "user": user,
            "learning_dir": str(engine.learning_dir),
            "corrections": len(engine.get_corrections(user)),
            "aliases": len(engine.get_aliases(user)),
        })
    elif cmd == "profile":
        print_json(engine.get_profile(user))
    elif cmd == "corrections":
        print_json(engine.get_corrections(user))
    elif cmd == "aliases":
        print_json(engine.get_aliases(user))
    elif cmd == "add-correction":
        engine.add_correction(user, args.wrong, args.right)
        print(f"Correção registrada: {args.wrong} -> {args.right}")
    elif cmd == "add-alias":
        engine.add_alias(user, args.expression, args.meaning)
        print(f"Alias registrado: {args.expression} -> {args.meaning}")
    elif cmd == "daily-summary":
        print(engine.daily_summary(user))


def handle_feedback(args: argparse.Namespace) -> None:
    from .training import TrainingStore

    store = TrainingStore()
    if args.feedback_command == "good":
        event = store.set_feedback("good")
    else:
        event = store.set_feedback("bad", args.reason)

    if not event:
        print("Nenhum evento de conversa encontrado para rotular.", file=sys.stderr)
        sys.exit(1)
    print_json({"status": "ok", "feedback": event.get("user_feedback"), "events_path": str(store.events_path)})


def handle_training(args: argparse.Namespace) -> None:
    from .training import TrainingStore

    store = TrainingStore()
    if args.training_command == "status":
        print_json(store.status())
    elif args.training_command == "export":
        path = store.export_sft() if args.export_format == "sft" else store.export_dpo()
        print_json({"status": "ok", "path": str(path)})


def handle_voice_identity(args: argparse.Namespace) -> None:
    manager = identity.VoiceIdentityManager()

    if args.voice_identity_command == "status":
        print_json(identity.get_voice_identity_status())
    elif args.voice_identity_command == "enroll":
        manager.enroll(args.user_id)
    elif args.voice_identity_command == "identify":
        print_json(manager.identify())


def handle_voice_wakeword_status(args: argparse.Namespace) -> None:
    print_json(wakeword.get_wakeword_status())


def handle_atualizar(args: argparse.Namespace) -> None:
    dispatcher = CommandDispatcher()
    console = Console()
    
    if args.target == "nixos":
        cmd = ["nixos-rebuild", "switch", "--flake", ".#glacier"]
        cwd = "/etc/kryonix"
    elif args.target == "kora":
        cmd = ["systemctl", "--user", "restart", "kora-api.service", "kora-voice-listener.service", "kora-memory-worker.service"]
        cwd = None
    else:
        console.print(f"[bold red]Alvo inválido: {args.target}")
        sys.exit(1)

    with console.status("Kora está pensando...") as status:
        success = dispatcher.execute(cmd, cwd=cwd)

    if success:
        console.print(f"Prontinho, Ragton. atualizar {args.target} finalizada com sucesso.")
    else:
        console.print(f"[bold red]Erro ao executar atualizar {args.target}.")
        sys.exit(1)


def handle_rodar(args: argparse.Namespace) -> None:
    dispatcher = CommandDispatcher()
    console = Console()
    
    if args.target == "api":
        cmd = ["systemctl", "--user", "restart", "kora-api.service"]
        with console.status("Kora está pensando...") as status:
            success = dispatcher.execute(cmd)
        if success:
            console.print("Prontinho, Ragton. rodar api finalizada com sucesso.")
        else:
            console.print("[bold red]Erro ao executar rodar api.")
            sys.exit(1)
            
    elif args.target == "doctor":
        with console.status("Kora está pensando...") as status:
            handle_voice_doctor(args)
        console.print("Prontinho, Ragton. rodar doctor finalizada com sucesso.")
        
    elif args.target == "assistant":
        console.print("[bold yellow]Iniciando assistente de voz...")
        handle_listen(args)
        console.print("Prontinho, Ragton. rodar assistant finalizada com sucesso.")


def handle_fazer(args: argparse.Namespace) -> None:
    dispatcher = CommandDispatcher()
    console = Console()
    tarefa = args.tarefa
    
    dispatcher.log_command(["fazer", tarefa], True)
    
    with console.status("Kora está pensando...") as status:
        try:
            if "luz" in tarefa.lower() or "home assistant" in tarefa.lower() or "ha" in tarefa.lower():
                res = asyncio.run(call_ha("light.living_room", "on" if "liga" in tarefa.lower() else "off"))
            else:
                res = asyncio.run(trigger_n8n("kora-task", {"task": tarefa}))
                
            success = (res.get("status") in ("success", "stub_success"))
        except Exception as e:
            console.print(f"[bold red]Erro no dispatcher: {e}")
            success = False

    if success:
        console.print(f"Prontinho, Ragton. {tarefa} finalizada com sucesso.")
    else:
        console.print(f"[bold red]Falha ao executar tarefa: {tarefa}.")
        sys.exit(1)


def handle_config(args: argparse.Namespace) -> None:
    cfg = KoraConfig()
    cmd = args.config_command

    if not cmd or cmd == "list":
        all_cfg = cfg.load_all()
        if args.json:
            print_json(all_cfg)
        else:
            print_table("Kora Configurations (Merged)", all_cfg)
    elif cmd == "get":
        val = cfg.load_all().get(args.key)
        if val is not None:
            if args.json:
                print_json({args.key: val})
            else:
                print(val)
        else:
            sys.stderr.write(f"Configuração '{args.key}' não encontrada.\n")
            sys.exit(1)
    elif cmd == "set":
        cfg.set(args.key, args.value)
    elif cmd == "delete":
        cfg.delete(args.key)


def main(args_list: list[str] = None) -> None:
    parser = argparse.ArgumentParser(description="Kora Personal Assistant Admin CLI")
    parser.add_argument("--url", help="Override KORA_API_URL")
    parser.add_argument("--timeout", type=int, default=120, help="Request timeout (seconds)")
    parser.add_argument("--json", action="store_true", help="Output raw JSON")
    parser.add_argument("--quiet", "-q", action="store_true", help="Suppress metadata/diagnostics")

    subparsers = parser.add_subparsers(dest="command")

    # health
    subparsers.add_parser("health", help="Check API and dependencies health")

    # mute
    subparsers.add_parser("mute", help="Mute Kora's voice (suppress TTS output)")

    # unmute
    subparsers.add_parser("unmute", help="Unmute Kora's voice (enable TTS output)")

    # status
    status_parser = subparsers.add_parser("status", help="Get service metadata and uptime or system status")
    status_parser.add_argument("target", nargs="?", default="kora", choices=["kora", "nixos", "brain"], help="Alvo do status")

    # capabilities
    subparsers.add_parser("capabilities", help="List active and planned capabilities")

    # version
    subparsers.add_parser("version", help="Get Kora assistant version")

    # config
    config_parser = subparsers.add_parser("config", help="Manage local agent configurations")
    config_subparsers = config_parser.add_subparsers(dest="config_command", required=False)
    config_subparsers.add_parser("list", help="List all active configurations")
    
    get_parser = config_subparsers.add_parser("get", help="Get a configuration value")
    get_parser.add_argument("key", help="Configuration key (e.g. KORA_API_URL)")
    
    set_parser = config_subparsers.add_parser("set", help="Set a user-level configuration value")
    set_parser.add_argument("key", help="Configuration key (e.g. KORA_API_URL)")
    set_parser.add_argument("value", help="Configuration value")
    
    delete_parser = config_subparsers.add_parser("delete", help="Delete a user-level configuration key")
    delete_parser.add_argument("key", help="Configuration key to delete")

    # memory
    memory_parser = subparsers.add_parser("memory", help="Memory and graph operations")
    memory_subparsers = memory_parser.add_subparsers(dest="memory_command", required=True)

    search_parser = memory_subparsers.add_parser("search", help="Search the knowledge base")
    search_parser.add_argument("query", help="Search query")
    search_parser.add_argument("--mode", choices=["hybrid", "naive", "local", "global"], default="hybrid", help="Search mode")

    # brain
    brain_parser = subparsers.add_parser("brain", help="Infrastructure graph operations")
    brain_subparsers = brain_parser.add_subparsers(dest="brain_command", required=True)

    brain_sync_parser = brain_subparsers.add_parser(
        "sync", help="Sync a NixOS host's configuration into Neo4j"
    )
    brain_sync_parser.add_argument(
        "--host", required=True, help="Target hostname (e.g. inspiron, glacier)"
    )
    brain_sync_parser.add_argument(
        "--config-file",
        default=None,
        help="Override path to a configuration.nix (bypasses nix eval; uses regex parser)",
    )
    brain_sync_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Log Cypher statements without writing to Neo4j",
    )

    # voice
    voice_parser = subparsers.add_parser("voice", help="Voice and audio operations")
    voice_subparsers = voice_parser.add_subparsers(dest="voice_command", required=True)

    voice_subparsers.add_parser("devices", help="List audio devices")
    voice_subparsers.add_parser("doctor", help="Run diagnostics for voice pipeline")
    voice_subparsers.add_parser("status", help="Show voice pipeline status")
    voice_subparsers.add_parser("mute",   help="Mute microphone (daemon will ignore audio)")
    voice_subparsers.add_parser("unmute", help="Unmute microphone")

    mic_parser = voice_subparsers.add_parser("test-mic", help="Test microphone recording")
    mic_parser.add_argument("--seconds", type=int, default=5)

    stt_parser = voice_subparsers.add_parser("transcribe", help="Transcribe audio to text")
    stt_parser.add_argument("--seconds", type=int, default=5)

    speak_parser = voice_subparsers.add_parser("speak", help="Speak text using TTS")
    speak_parser.add_argument("text", nargs="?", default=None, help="Texto a falar (usa padrão se omitido)")
    speak_parser.add_argument("--test", action="store_true", help="Fala frase de teste")
    speak_parser.add_argument("--voice", default=None, help="Preset de voz (faber, cadu...)")

    # voice voices
    voices_parser = voice_subparsers.add_parser("voices", help="Manage voice presets")
    voices_subparsers = voices_parser.add_subparsers(dest="voice_voices_command", required=True)
    voices_subparsers.add_parser("list",    help="List voice presets")
    voices_subparsers.add_parser("current", help="Show active preset")
    voices_subparsers.add_parser("test",    help="Test active preset")
    voices_set_parser = voices_subparsers.add_parser("set", help="Set active preset")
    voices_set_parser.add_argument("preset_name", help="Preset name (default, soft, fast, expressive)")

    # voice service
    service_parser = voice_subparsers.add_parser("service", help="Manage Kora background voice service")
    service_subparsers = service_parser.add_subparsers(dest="voice_service_command", required=True)
    for svc_cmd, svc_help in [
        ("enable",  "Enable and start background listener"),
        ("disable", "Disable background listener"),
        ("start",   "Start background listener"),
        ("stop",    "Stop background listener"),
        ("restart", "Restart background listener"),
        ("status",  "Show service status"),
        ("logs",    "Show recent service logs"),
    ]:
        service_subparsers.add_parser(svc_cmd, help=svc_help)

    # voice daemon
    daemon_parser = voice_subparsers.add_parser("daemon", help="Manage voice listener daemon")
    daemon_subparsers = daemon_parser.add_subparsers(dest="voice_daemon_command", required=True)
    daemon_subparsers.add_parser("start", help="Start the daemon")
    daemon_subparsers.add_parser("run",   help="Run daemon in foreground (for systemd)")
    daemon_subparsers.add_parser("stop",  help="Stop the daemon")
    daemon_subparsers.add_parser("status", help="Get daemon status")

    # voice identity
    identity_parser = voice_subparsers.add_parser("identity", help="Manage voice identity")
    identity_subparsers = identity_parser.add_subparsers(dest="voice_identity_command", required=True)
    identity_subparsers.add_parser("status", help="Get identity engine status")
    enroll_parser = identity_subparsers.add_parser("enroll", help="Enroll a user's voice")
    enroll_parser.add_argument("user_id", help="User ID to enroll")
    identity_subparsers.add_parser("identify", help="Identify the current speaker")

    # voice wake-word
    ww_parser = voice_subparsers.add_parser("wake-word", help="Manage wake-word engine")
    ww_subparsers = ww_parser.add_subparsers(dest="voice_ww_command", required=True)
    ww_subparsers.add_parser("status", help="Get wake-word engine status")

    # voice models
    models_parser = voice_subparsers.add_parser("models", help="Manage local voice models")
    models_subparsers = models_parser.add_subparsers(dest="voice_models_command", required=True)
    models_subparsers.add_parser("status", help="Show active model status")
    models_subparsers.add_parser("list",   help="List available models for installation")
    install_parser = models_subparsers.add_parser("install", help="Install a model (e.g. install whisper base)")
    install_parser.add_argument("model_type", choices=["whisper", "piper"], help="Type of model")
    install_parser.add_argument("model_name", help="Model name (e.g. base, small, faber, cadu)")
    import_parser = models_subparsers.add_parser("import", help="Import custom Piper voice model from local path")
    import_parser.add_argument("import_type", choices=["piper"], help="Import type")
    import_parser.add_argument("import_name", help="Voice name (e.g. kora_ptbr_female)")
    import_parser.add_argument("--model", required=True, help="Path to .onnx model")
    import_parser.add_argument("--config", required=True, help="Path to .onnx.json config")

    # voice vad
    vad_parser = voice_subparsers.add_parser("vad", help="Voice Activity Detection")
    subparsers_vad = vad_parser.add_subparsers(dest="voice_vad_command", required=True)
    subparsers_vad.add_parser("test", help="Test VAD (record until silence)")

    # voice signal
    signal_parser = voice_subparsers.add_parser("signal", help="Play a signal sound")
    signal_parser.add_argument("signal_name", choices=["wake", "thinking", "error", "done"], help="Signal to play")

    # listen
    listen_parser = subparsers.add_parser("listen", help="Listen and respond (Voice Mode)")
    listen_parser.add_argument("--push-to-talk", action="store_true", default=False, help="Use push-to-talk mode (ENTER to record)")
    listen_parser.add_argument("--vad", action="store_true", default=False, help="Use VAD mode (stops after 1s silence)")

    # user
    user_parser = subparsers.add_parser("user", help="Manage Kora users")
    user_subparsers = user_parser.add_subparsers(dest="user_command", required=True)
    user_subparsers.add_parser("init", help="Initialize default users")
    user_add_parser = user_subparsers.add_parser("add", help="Add a new user")
    user_add_parser.add_argument("--id", required=True)
    user_add_parser.add_argument("--display-name", required=True)
    user_add_parser.add_argument("--full-name")
    user_add_parser.add_argument("--linux-user")
    user_add_parser.add_argument("--github")
    user_add_parser.add_argument("--role", default="trusted_partner")

    user_subparsers.add_parser("list", help="List all users")

    user_show_parser = user_subparsers.add_parser("show", help="Show user details")
    user_show_parser.add_argument("id")

    user_remove_parser = user_subparsers.add_parser("remove", help="Remove a user")
    user_remove_parser.add_argument("id")

    # learning
    learning_parser = subparsers.add_parser("learning", help="Personal learning operations")
    learning_subparsers = learning_parser.add_subparsers(dest="learning_command", required=True)
    learning_subparsers.add_parser("status", help="Show learning store status")
    learning_subparsers.add_parser("profile", help="Show current user learning profile")
    learning_subparsers.add_parser("corrections", help="Show learned corrections")
    learning_subparsers.add_parser("aliases", help="Show learned aliases")
    add_corr_parser = learning_subparsers.add_parser("add-correction", help="Add a speech/text correction")
    add_corr_parser.add_argument("wrong")
    add_corr_parser.add_argument("right")
    add_alias_parser = learning_subparsers.add_parser("add-alias", help="Add an expression alias")
    add_alias_parser.add_argument("expression")
    add_alias_parser.add_argument("meaning")
    learning_subparsers.add_parser("daily-summary", help="Write/show daily learning summary")

    # feedback
    feedback_parser = subparsers.add_parser("feedback", help="Label last Kora answer")
    feedback_subparsers = feedback_parser.add_subparsers(dest="feedback_command", required=True)
    feedback_subparsers.add_parser("good", help="Mark last answer as good")
    bad_parser = feedback_subparsers.add_parser("bad", help="Mark last answer as bad")
    bad_parser.add_argument("reason")

    # training
    training_parser = subparsers.add_parser("training", help="Training dataset operations")
    training_subparsers = training_parser.add_subparsers(dest="training_command", required=True)
    training_subparsers.add_parser("status", help="Show training dataset status")
    export_parser = training_subparsers.add_parser("export", help="Export dataset")
    export_parser.add_argument("export_format", choices=["sft", "dpo"])

    # benchmark
    bench_parser = subparsers.add_parser("benchmark", help="Run automated benchmarks")
    bench_subparsers = bench_parser.add_subparsers(dest="bench_command", required=True)
    bench_subparsers.add_parser("quality", help="Run quality guard scenario tests")

    # atualizar / rodar / fazer
    atualizar_parser = subparsers.add_parser("atualizar", help="Atualizar components do sistema ou assistente")
    atualizar_parser.add_argument("target", choices=["nixos", "kora"], help="Alvo a atualizar")

    rodar_parser = subparsers.add_parser("rodar", help="Executar/gerenciar serviços da Kora")
    rodar_parser.add_argument("target", choices=["api", "doctor", "assistant"], help="Alvo a rodar")

    fazer_parser = subparsers.add_parser("fazer", help="Enviar tarefa para o dispatcher")
    fazer_parser.add_argument("tarefa", help="Descrição da tarefa a executar")

    if args_list is not None:
        args = parser.parse_args(args_list)
    else:
        args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(0)

    if args.command == "health":
        handle_health(args)
    elif args.command == "mute":
        handle_mute(args)
    elif args.command == "unmute":
        handle_unmute(args)
    elif args.command == "status":
        handle_status(args)
    elif args.command == "capabilities":
        handle_capabilities(args)
    elif args.command == "version":
        from .. import __version__
        print(f"Kora v{__version__}")
    elif args.command == "config":
        handle_config(args)
    elif args.command == "memory":
        if args.memory_command == "search":
            handle_memory_search(args)
    elif args.command == "brain":
        if args.brain_command == "sync":
            from .brain_sync import handle_brain_sync
            sys.exit(handle_brain_sync(args))
    elif args.command == "voice":
        if args.voice_command == "devices":
            handle_voice_devices(args)
        elif args.voice_command == "status":
            handle_voice_status(args)
        elif args.voice_command == "mute":
            handle_voice_mute(args)
        elif args.voice_command == "unmute":
            handle_voice_unmute(args)
        elif args.voice_command == "doctor":
            handle_voice_doctor(args)
        elif args.voice_command == "test-mic":
            handle_voice_test_mic(args)
        elif args.voice_command == "transcribe":
            handle_voice_transcribe(args)
        elif args.voice_command == "speak":
            handle_voice_speak(args)
        elif args.voice_command == "voices":
            handle_voice_voices(args)
        elif args.voice_command == "service":
            handle_voice_service(args)
        elif args.voice_command == "daemon":
            handle_voice_daemon(args)
        elif args.voice_command == "identity":
            handle_voice_identity(args)
        elif args.voice_command == "models":
            if args.voice_models_command == "status":
                handle_voice_models_status(args)
            elif args.voice_models_command == "list":
                handle_voice_models_list(args)
            elif args.voice_models_command == "install":
                handle_voice_models_install(args)
            elif args.voice_models_command == "import":
                from ..voice import models as voice_models
                voice_models.cmd_import_piper(args.import_name, args.model, args.config)
        elif args.voice_command == "vad":
            if args.voice_vad_command == "test":
                voice_vad.cmd_test()
        elif args.voice_command == "signal":
            voice_signals.cmd_signal(args.signal_name)
        elif args.voice_command == "wake-word":
            if args.voice_ww_command == "status":
                handle_voice_wakeword_status(args)
    elif args.command == "listen":
        handle_listen(args)
    elif args.command == "user":
        handle_user(args)
    elif args.command == "learning":
        handle_learning(args)
    elif args.command == "feedback":
        handle_feedback(args)
    elif args.command == "training":
        handle_training(args)
    elif args.command == "benchmark":
        if args.bench_command == "quality":
            from ..eval import quality_eval
            quality_eval.run_benchmarks()
    elif args.command == "atualizar":
        handle_atualizar(args)
    elif args.command == "rodar":
        handle_rodar(args)
    elif args.command == "fazer":
        handle_fazer(args)


if __name__ == "__main__":
    main()
