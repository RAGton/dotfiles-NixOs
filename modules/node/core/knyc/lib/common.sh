# Bibliotecas compartilhadas do KNYC.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}      $*"; }
log_warn()    { echo -e "${YELLOW}[AVISO]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERRO]${NC}    $*" >&2; }
log_section() { echo -e "\n${BOLD}$*${NC}"; }

die() { log_error "$*"; exit 1; }

find_flake_root() {
	if [[ -n "${NODE_FLAKE:-}" ]]; then
		echo "$NODE_FLAKE"
		return
	fi

	local dir="$PWD"
	while [[ "$dir" != "/" ]]; do
		[[ -f "$dir/flake.nix" ]] && { echo "$dir"; return; }
		dir="$(dirname "$dir")"
	done

	die "flake.nix não encontrado. Defina NODE_FLAKE=/caminho/para/repo ou execute knyc de dentro do repositório."
}

print_check() {
	local label="$1"
	local status="$2"
	printf "%-22s %s\n" "$label" "$status"
}

check_service() {
	local svc="$1"
	if [[ "${KNYC_SKIP_SERVICE_CHECKS:-0}" == "1" ]]; then
		print_check "$svc" "SKIP"
		return 0
	fi

	if systemctl is-active --quiet "$svc"; then
		print_check "$svc" "OK"
		(( DOCTOR_OK++ )) || true
	else
		print_check "$svc" "FAIL"
		(( DOCTOR_FAIL++ )) || true
	fi
}

check_dir() {
	local path="$1"
	local label="$2"
	if [[ -d "$path" ]]; then
		print_check "$label" "OK"
		(( DOCTOR_OK++ )) || true
	else
		print_check "$label" "FAIL"
		(( DOCTOR_FAIL++ )) || true
	fi
}

check_symlink() {
	local path="$1"
	local label="$2"
	if [[ -L "$path" ]]; then
		local target
		target="$(readlink -f "$path" 2>/dev/null || true)"
		if [[ -n "$target" && -e "$target" ]]; then
			print_check "$label" "OK"
			(( DOCTOR_OK++ )) || true
		else
			print_check "$label" "FAIL"
			(( DOCTOR_FAIL++ )) || true
		fi
	else
		print_check "$label" "FAIL"
		(( DOCTOR_FAIL++ )) || true
	fi
}

check_file() {
	local path="$1"
	local label="$2"
	if [[ -f "$path" ]]; then
		print_check "$label" "OK"
		(( DOCTOR_OK++ )) || true
	else
		print_check "$label" "FAIL"
		(( DOCTOR_FAIL++ )) || true
	fi
}

check_path_exists() {
	local path="$1"
	local label="$2"
	if [[ -e "$path" || -L "$path" ]]; then
		print_check "$label" "OK"
		(( DOCTOR_OK++ )) || true
	else
		print_check "$label" "FAIL"
		(( DOCTOR_FAIL++ )) || true
	fi
}

check_http() {
	local url="$1"
	local label="$2"
	if [[ "${KNYC_SKIP_HTTP_CHECKS:-0}" == "1" ]]; then
		print_check "$label" "SKIP"
		return 0
	fi
	local code
	code="$(curl -sS --max-time 2 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo 000)"

	if [[ ! "$code" =~ ^[23][0-9][0-9]$ ]]; then
		print_check "$label" "FAIL"
		(( DOCTOR_FAIL++ )) || true
	else
		print_check "$label" "OK"
		(( DOCTOR_OK++ )) || true
	fi
}
