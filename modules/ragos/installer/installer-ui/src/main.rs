use axum::{
	extract::State,
	http::StatusCode,
	response::{Html, IntoResponse},
	routing::{get, post},
	Json, Router,
};
use axum::extract::Query;
use axum::response::sse::{Event, Sse};
use hmac::{Hmac, Mac};
use jsonschema::JSONSchema;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::{
	collections::HashMap,
	convert::Infallible,
	net::{Ipv4Addr, SocketAddr},
	path::{Path, PathBuf},
	process::Stdio,
	sync::Arc,
};
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use thiserror::Error;
use tokio::{
	fs,
	process::Command,
	sync::Mutex,
};
use tokio::io::{AsyncBufReadExt, BufReader};
use tower_http::trace::TraceLayer;
use tower_http::services::ServeDir;
use tower_http::set_header::SetResponseHeaderLayer;
use tracing::{info, warn};
use axum::http::header::{CACHE_CONTROL, HeaderValue};
use tokio::time::{Duration, interval};

const INSTALL_PLAN_VERSION: u32 = 1;
const INSTALL_PLAN_HMAC_KEY_BYTES: usize = 32;

type HmacSha256 = Hmac<Sha256>;

#[derive(Clone)]
struct AppState {
	static_dir: PathBuf,
	imgs_dir: PathBuf,
	runtime_dir: PathBuf,
	install_lock: Arc<Mutex<()>>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
struct PlanSubmission {
	plan: InstallPlan,
	secrets: InstallSecrets,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
struct InstallPlan {
	version: u32,
	disk: DiskPlan,
	network: NetworkPlan,
	locale: LocalePlan,
	admin: AdminPlan,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
struct DiskPlan {
	mode: String,    // one|two
	profile: String, // single|raid
	selected_disks: Option<Vec<String>>,
	raid_level: Option<String>,
	luks_enabled: Option<bool>,
	sys_disk: String,
	data_disk: Option<String>,
	root_fs: Option<String>,
	data_fs: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
struct NetworkPlan {
	hostname: String,
	interface: String,
	server_ip: String,
	prefix_length: u8,
	gateway: String,
	dns: Vec<String>,
	http_port: u16,
	wan: WanPlan,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
struct WanPlan {
	interface: String,
	mode: String, // dhcp|static|pppoe
	address: Option<String>,
	prefix_length: Option<u8>,
	gateway: Option<String>,
	dns: Option<Vec<String>>,
	pppoe_user: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
struct LocalePlan {
	country: String,
	timezone: String,
	locale: String,
	keymap: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
struct AdminPlan {
	user: String,
	uid: u32,
	email: String,
	authorized_keys: Option<Vec<String>>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
struct InstallSecrets {
	admin_password: String,
	admin_password_confirm: String,
	wan_pppoe_password: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
struct InstallRequest {
	#[serde(default)]
	confirm_wipe: bool,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct DisksResponse {
	disks: Vec<DiskInfo>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct DiskInfo {
	path: String,
	name: String,
	model: String,
	serial: String,
	transport: String,
	disk_type: String,
	size_bytes: u64,
	read_only: bool,
	removable: bool,
	hotplug: bool,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct NetIfsResponse {
	interfaces: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct NetworkTestQuery {
	target: Option<String>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct NetworkTestResponse {
	target: String,
	success: bool,
	output: String,
}

#[derive(Debug, Deserialize)]
struct DiskLayoutQuery {
	disk: String,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct ListResponse {
	items: Vec<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct TimezoneLocation {
	timezone: String,
	country_code: String,
	latitude: f64,
	longitude: f64,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct TimezoneLocationsResponse {
	items: Vec<TimezoneLocation>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct StatusResponse {
	have_plan: bool,
	can_install: bool,
	running: bool,
	exit_code: Option<i32>,
	#[serde(rename = "startedAt")]
	started_at: Option<i64>,
	#[serde(rename = "finishedAt")]
	finished_at: Option<i64>,
	install_running: bool,
	last_install_exit: Option<i32>,
	install_started_at_unix: Option<i64>,
	current_phase: Option<String>,
	last_error: Option<String>,
	last_log_line: Option<String>,
}

#[derive(Debug, Error)]
enum AppError {
	#[error("io: {0}")]
	Io(#[from] std::io::Error),
	#[error("utf8: {0}")]
	Utf8(#[from] std::string::FromUtf8Error),
	#[error("json: {0}")]
	Json(#[from] serde_json::Error),
	#[error("validation: {0}")]
	Validation(String),
	#[error("command failed: {0}")]
	CommandFailed(String),
}

impl IntoResponse for AppError {
	fn into_response(self) -> axum::response::Response {
		let msg = self.to_string();
		(
			StatusCode::BAD_REQUEST,
			Json(serde_json::json!({ "error": msg })),
		)
			.into_response()
	}
}

fn now_unix() -> i64 {
	use std::time::{SystemTime, UNIX_EPOCH};
	SystemTime::now()
		.duration_since(UNIX_EPOCH)
		.unwrap_or_default()
		.as_secs() as i64
}

fn parse_geo_component(value: &str) -> Option<f64> {
	let trimmed = value.trim();
	if trimmed.len() < 4 {
		return None;
	}

	let sign = if trimmed.starts_with('-') { -1.0 } else { 1.0 };
	let digits = trimmed.trim_start_matches(['+', '-']);
	let (deg, min, sec) = match digits.len() {
		4 | 5 => {
			let split = digits.len().saturating_sub(2);
			(
				digits[..split].parse::<f64>().ok()?,
				digits[split..].parse::<f64>().ok()?,
				0.0,
			)
		}
		6 | 7 => {
			let split = digits.len().saturating_sub(4);
			(
				digits[..split].parse::<f64>().ok()?,
				digits[split..split + 2].parse::<f64>().ok()?,
				digits[split + 2..].parse::<f64>().ok()?,
			)
		}
		_ => return None,
	};

	Some(sign * (deg + (min / 60.0) + (sec / 3600.0)))
}

fn parse_timezone_locations_from_tab(content: &str) -> Vec<TimezoneLocation> {
	let mut items = Vec::new();

	for line in content.lines() {
		let line = line.trim();
		if line.is_empty() || line.starts_with('#') {
			continue;
		}

		let parts: Vec<&str> = line.split('\t').collect();
		if parts.len() < 3 {
			continue;
		}

		let country_code = parts[0].split(',').next().unwrap_or("").trim().to_string();
		let position = parts[1].trim();
		let timezone = parts[2].trim().to_string();
		if timezone.is_empty() || country_code.is_empty() {
			continue;
		}

		let split_index = position[1..]
			.find(|c| c == '+' || c == '-')
			.map(|idx| idx + 1);
		let Some(split_index) = split_index else {
			continue;
		};

		let latitude = parse_geo_component(&position[..split_index]);
		let longitude = parse_geo_component(&position[split_index..]);
		let (Some(latitude), Some(longitude)) = (latitude, longitude) else {
			continue;
		};

		items.push(TimezoneLocation {
			timezone,
			country_code,
			latitude,
			longitude,
		});
	}

	items.sort_by(|a, b| a.timezone.cmp(&b.timezone));
	items.dedup_by(|a, b| a.timezone == b.timezone);
	items
}

fn plan_path(runtime_dir: &Path) -> PathBuf {
	runtime_dir.join("install-plan.json")
}

fn secrets_path(runtime_dir: &Path) -> PathBuf {
	runtime_dir.join("install-secrets.json")
}

fn log_path(runtime_dir: &Path) -> PathBuf {
	runtime_dir.join("install.log")
}

fn plan_sig_path(runtime_dir: &Path) -> PathBuf {
	runtime_dir.join("install-plan.sig")
}

fn hmac_key_path(runtime_dir: &Path) -> PathBuf {
	runtime_dir.join("hmac.key")
}

fn runtime_manifest_path(runtime_dir: &Path) -> PathBuf {
	runtime_dir.join("runtime.manifest")
}

fn install_state_path(runtime_dir: &Path) -> PathBuf {
	runtime_dir.join("install-state.json")
}

async fn ensure_runtime_dir(runtime_dir: &Path) -> Result<(), AppError> {
	fs::create_dir_all(runtime_dir).await?;
	chmod_best_effort(runtime_dir, 0o700).await;
	Ok(())
}

async fn chmod_best_effort(path: &Path, mode: u32) {
	#[cfg(unix)]
	{
		let perms = std::fs::Permissions::from_mode(mode);
		if let Err(e) = fs::set_permissions(path, perms).await {
			warn!(
				path = %path.display(),
				mode = %format!("{mode:#o}"),
				error = %e,
				"failed to set permissions"
			);
		}
	}
}

async fn write_file_with_mode(path: &Path, bytes: &[u8], mode: u32) -> Result<(), AppError> {
	fs::write(path, bytes).await?;
	chmod_best_effort(path, mode).await;
	Ok(())
}

fn bytes_to_hex(bytes: &[u8]) -> String {
	let mut out = String::with_capacity(bytes.len() * 2);
	for b in bytes {
		use std::fmt::Write;
		let _ = write!(&mut out, "{:02x}", b);
	}
	out
}

fn sha256_hex(bytes: &[u8]) -> String {
	bytes_to_hex(&Sha256::digest(bytes))
}

fn sign_plan_hmac_sha256(plan_bytes: &[u8], key: &[u8]) -> Result<Vec<u8>, AppError> {
	let mut mac = HmacSha256::new_from_slice(key)
		.map_err(|e| AppError::Validation(format!("chave HMAC inválida: {e}")))?;
	mac.update(plan_bytes);
	Ok(mac.finalize().into_bytes().to_vec())
}

async fn read_or_create_hmac_key(runtime_dir: &Path) -> Result<Vec<u8>, AppError> {
	ensure_runtime_dir(runtime_dir).await?;
	let p = hmac_key_path(runtime_dir);
	if p.exists() {
		let bytes = fs::read(&p).await?;
		if bytes.len() < INSTALL_PLAN_HMAC_KEY_BYTES {
			return Err(AppError::Validation(format!(
				"hmac.key inválida: esperado {INSTALL_PLAN_HMAC_KEY_BYTES}+ bytes"
			)));
		}
		chmod_best_effort(&p, 0o600).await;
		return Ok(bytes);
	}

	let mut key = vec![0u8; INSTALL_PLAN_HMAC_KEY_BYTES];
	getrandom::getrandom(&mut key)
		.map_err(|e| AppError::Validation(format!("falha ao gerar chave HMAC: {e}")))?;
	write_file_with_mode(&p, &key, 0o600).await?;
	Ok(key)
}

async fn write_runtime_manifest(
	runtime_dir: &Path,
	plan_bytes: &[u8],
	secrets_bytes: &[u8],
	sig_bytes: &[u8],
) -> Result<(), AppError> {
	ensure_runtime_dir(runtime_dir).await?;
	let manifest = format!(
		"{}  install-plan.json\n{}  install-secrets.json\n{}  install-plan.sig\n",
		sha256_hex(plan_bytes),
		sha256_hex(secrets_bytes),
		sha256_hex(sig_bytes),
	);
	write_file_with_mode(&runtime_manifest_path(runtime_dir), manifest.as_bytes(), 0o600).await?;
	Ok(())
}

async fn verify_runtime_integrity(runtime_dir: &Path) -> Result<(), AppError> {
	use std::collections::HashMap;

	let plan_file = plan_path(runtime_dir);
	let secrets_file = secrets_path(runtime_dir);
	let key_file = hmac_key_path(runtime_dir);
	let sig_file = plan_sig_path(runtime_dir);
	let manifest_file = runtime_manifest_path(runtime_dir);

	for (label, p) in [
		("install-plan.json", &plan_file),
		("install-secrets.json", &secrets_file),
		("hmac.key", &key_file),
		("install-plan.sig", &sig_file),
		("runtime.manifest", &manifest_file),
	] {
		if !p.exists() {
			return Err(AppError::Validation(format!("{label} ausente: {}", p.display())));
		}
	}

	let plan_bytes = fs::read(&plan_file).await?;
	let secrets_bytes = fs::read(&secrets_file).await?;
	let key_bytes = fs::read(&key_file).await?;
	if key_bytes.len() < INSTALL_PLAN_HMAC_KEY_BYTES {
		return Err(AppError::Validation(format!(
			"hmac.key inválida: esperado {INSTALL_PLAN_HMAC_KEY_BYTES}+ bytes"
		)));
	}
	let sig_bytes = fs::read(&sig_file).await?;

	let expected_sig = sign_plan_hmac_sha256(&plan_bytes, &key_bytes)?;
	if sig_bytes != expected_sig {
		return Err(AppError::Validation(
			"assinatura HMAC inválida: install-plan.sig não confere".into(),
		));
	}

	let manifest_content = fs::read_to_string(&manifest_file).await?;
	let mut entries: HashMap<String, String> = HashMap::new();
	for line in manifest_content.lines() {
		let line = line.trim();
		if line.is_empty() || line.starts_with('#') {
			continue;
		}
		let parts: Vec<&str> = line.split_whitespace().collect();
		if parts.len() < 2 {
			continue;
		}
		let digest = parts[0].trim().to_lowercase();
		let name = parts[parts.len() - 1].trim().to_string();
		if !digest.is_empty() && !name.is_empty() {
			entries.insert(name, digest);
		}
	}

	let actual = [
		("install-plan.json", sha256_hex(&plan_bytes)),
		("install-secrets.json", sha256_hex(&secrets_bytes)),
		("install-plan.sig", sha256_hex(&sig_bytes)),
	];
	for (name, actual_hex) in actual {
		let expected = entries
			.get(name)
			.ok_or_else(|| AppError::Validation(format!("runtime.manifest ausente para: {name}")))?;
		if expected != &actual_hex {
			return Err(AppError::Validation(format!(
				"runtime.manifest mismatch para {name}: esperado {expected}, calculado {actual_hex}"
			)));
		}
	}

	Ok(())
}

#[derive(Debug, Deserialize, Serialize, Default, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
struct InstallState {
	running: bool,
	#[serde(alias = "lastExit")]
	exit_code: Option<i32>,
	#[serde(rename = "startedAt", alias = "startedAtUnix")]
	started_at_unix: Option<i64>,
	#[serde(rename = "finishedAt", alias = "finishedAtUnix")]
	finished_at_unix: Option<i64>,
	current_phase: Option<String>,
	last_error: Option<String>,
	last_log_line: Option<String>,
}

async fn read_install_state(runtime_dir: &Path) -> Result<InstallState, AppError> {
	let p = install_state_path(runtime_dir);
	if !p.exists() {
		return Ok(InstallState::default());
	}
	let bytes = fs::read(p).await?;
	Ok(serde_json::from_slice(&bytes)?)
}

async fn write_install_state(runtime_dir: &Path, state: &InstallState) -> Result<(), AppError> {
	ensure_runtime_dir(runtime_dir).await?;
	let p = install_state_path(runtime_dir);
	let bytes = serde_json::to_vec_pretty(state)?;
	write_file_with_mode(&p, &bytes, 0o644).await?;
	Ok(())
}

#[derive(Debug, Default, Clone)]
struct InstallLogSummary {
	current_phase: Option<String>,
	last_error: Option<String>,
	last_log_line: Option<String>,
}

fn parse_phase_from_log_line(line: &str) -> Option<String> {
	let trimmed = line.trim();
	if trimmed.is_empty() {
		return None;
	}

	let mut bracket_values = Vec::new();
	let mut rest = trimmed;
	while let Some(after_open) = rest.strip_prefix('[') {
		let close = after_open.find(']')?;
		bracket_values.push(after_open[..close].trim().to_string());
		rest = after_open[close + 1..].trim_start();
	}

	if bracket_values.len() >= 2 {
		let candidate = bracket_values[1].trim();
		if !candidate.is_empty() {
			return Some(candidate.to_string());
		}
	}

	if bracket_values.len() == 1 {
		let candidate = bracket_values[0].trim();
		if !candidate.is_empty() && candidate.chars().all(|c| c.is_ascii_uppercase()) {
			return Some(candidate.to_string());
		}
	}

	None
}

fn summarize_install_log(log_text: &str) -> InstallLogSummary {
	let mut summary = InstallLogSummary::default();

	for raw_line in log_text.lines() {
		let line = raw_line.trim();
		if line.is_empty() {
			continue;
		}

		summary.last_log_line = Some(line.to_string());

		if let Some(phase) = parse_phase_from_log_line(line) {
			if phase == "ERROR" {
				summary.last_error = Some(line.to_string());
			} else {
				summary.current_phase = Some(phase);
			}
			continue;
		}

		if line.starts_with("ERRO:") {
			summary.last_error = Some(line.to_string());
		}
	}

	summary
}

async fn read_install_log_tail(runtime_dir: &Path, line_count: usize) -> Result<String, AppError> {
	let log_file = log_path(runtime_dir);
	let line_count_arg = line_count.to_string();
	let log_file_arg = log_file.to_string_lossy().to_string();
	let out = Command::new("tail")
		.args(["-n", &line_count_arg, &log_file_arg])
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.output()
		.await;

	match out {
		Ok(output) if output.status.success() => Ok(String::from_utf8(output.stdout)?),
		_ => Ok(String::new()),
	}
}

async fn enrich_install_state(runtime_dir: &Path, state: InstallState) -> InstallState {
	let mut enriched = state;
	let log_tail = read_install_log_tail(runtime_dir, 400).await.unwrap_or_default();
	let summary = summarize_install_log(&log_tail);

	if summary.current_phase.is_some() {
		enriched.current_phase = summary.current_phase;
	}
	if summary.last_error.is_some() {
		enriched.last_error = summary.last_error;
	}
	if summary.last_log_line.is_some() {
		enriched.last_log_line = summary.last_log_line;
	}

	enriched
}

async fn get_index(State(state): State<AppState>) -> Result<impl IntoResponse, AppError> {
	let index = fs::read_to_string(state.static_dir.join("index.html")).await?;
	Ok(Html(index))
}

async fn get_netifs() -> Result<Json<NetIfsResponse>, AppError> {
	let out = Command::new("ip")
		.args(["-o", "link", "show"])
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.output()
		.await?;
	if !out.status.success() {
		return Err(AppError::CommandFailed(String::from_utf8(out.stderr)?));
	}
	let stdout = String::from_utf8(out.stdout)?;
	let mut interfaces = vec![];
	for line in stdout.lines() {
		// formato: "2: ens18: <BROADCAST,MULTICAST,UP,LOWER_UP> ..."
		let mut parts = line.split(':');
		let _idx = parts.next();
		let name = parts.next().unwrap_or("").trim();
		if name.is_empty() {
			continue;
		}
		// remove "@..." (ex: eth0@if3)
		let name = name.split('@').next().unwrap_or(name);
		if name != "lo" {
			interfaces.push(name.to_string());
		}
	}
	interfaces.sort();
	interfaces.dedup();
	Ok(Json(NetIfsResponse { interfaces }))
}

async fn get_network_test(Query(q): Query<NetworkTestQuery>) -> Result<Json<NetworkTestResponse>, AppError> {
	let target = q
		.target
		.unwrap_or_else(|| "1.1.1.1".to_string())
		.trim()
		.to_string();

	if target.is_empty() {
		return Err(AppError::Validation("target vazio".into()));
	}

	let out = Command::new("ping")
		.args(["-c", "1", "-W", "2", &target])
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.output()
		.await?;

	let stdout = String::from_utf8(out.stdout)?;
	let stderr = String::from_utf8(out.stderr)?;
	let output = if stdout.trim().is_empty() { stderr } else { stdout };

	Ok(Json(NetworkTestResponse {
		target,
		success: out.status.success(),
		output,
	}))
}

fn zoneinfo_tab_candidates(names: &[&str]) -> Vec<PathBuf> {
	let mut candidates = Vec::new();

	if let Some(base_dir) = std::env::var_os("RAGOS_INSTALLER_ZONEINFO_DIR") {
		let base = PathBuf::from(base_dir);
		for name in names {
			candidates.push(base.join(name));
		}
	}

	for prefix in ["/etc/zoneinfo", "/usr/share/zoneinfo"] {
		for name in names {
			candidates.push(Path::new(prefix).join(name));
		}
	}

	candidates
}

async fn load_timezone_items() -> Result<Vec<String>, AppError> {
	let timedatectl_output = Command::new("timedatectl")
		.args(["list-timezones"])
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.output()
		.await;
	if let Ok(out) = &timedatectl_output {
		if out.status.success() {
			let stdout = String::from_utf8(out.stdout.clone())?;
			let items = stdout
				.lines()
				.map(|l| l.trim())
				.filter(|l| !l.is_empty())
				.map(|l| l.to_string())
				.collect();
			return Ok(items);
		}
	}

	let mut items = Vec::new();
	for path in zoneinfo_tab_candidates(&["zone1970.tab", "zone.tab"]) {
		if !path.exists() {
			continue;
		}
		let content = fs::read_to_string(&path).await?;
		for item in parse_timezone_locations_from_tab(&content) {
			items.push(item.timezone);
		}
	}

	items.sort();
	items.dedup();
	if items.is_empty() {
		return match timedatectl_output {
			Ok(out) => Err(AppError::CommandFailed(String::from_utf8(out.stderr)?)),
			Err(error) => Err(AppError::Io(error)),
		};
	}

	Ok(items)
}

fn resolve_installer_runner() -> Result<String, AppError> {
	let runner = std::env::var("RAGOS_INSTALLER_RUNNER")
		.ok()
		.filter(|value| !value.trim().is_empty())
		.unwrap_or_else(|| "ragos-install".into());

	if runner.contains('/') {
		let path = PathBuf::from(&runner);
		if !path.exists() {
			return Err(AppError::Validation(format!(
				"runner do instalador ausente: {}",
				path.display()
			)));
		}
	}

	Ok(runner)
}

async fn get_timezones() -> Result<Json<ListResponse>, AppError> {
	let items = load_timezone_items().await?;
	Ok(Json(ListResponse { items }))
}

async fn get_timezone_locations() -> Result<Json<TimezoneLocationsResponse>, AppError> {
	for path in zoneinfo_tab_candidates(&["zone.tab", "zone1970.tab"]) {
		if path.exists() {
			let content = fs::read_to_string(&path).await?;
			let items = parse_timezone_locations_from_tab(&content);
			if !items.is_empty() {
				return Ok(Json(TimezoneLocationsResponse { items }));
			}
		}
	}

	Err(AppError::Validation("não foi possível carregar coordenadas de timezone".into()))
}

fn size_value_to_u64(v: &Value) -> u64 {
	match v {
		Value::Number(n) => n.as_u64().unwrap_or(0),
		Value::String(s) => s.trim().parse::<u64>().unwrap_or(0),
		_ => 0,
	}
}

fn find_disk_value(root: &Value, disk_path: &str) -> Option<Value> {
	let ty = root.get("type").and_then(|x| x.as_str()).unwrap_or("");
	let path = root.get("path").and_then(|x| x.as_str()).unwrap_or("");
	if ty == "disk" && path == disk_path {
		return Some(root.clone());
	}
	if let Some(children) = root.get("children").and_then(|x| x.as_array()) {
		for ch in children {
			if let Some(found) = find_disk_value(ch, disk_path) {
				return Some(found);
			}
		}
	}
	None
}

fn enrich_size_bytes(n: &mut Value) {
	if let Some(obj) = n.as_object_mut() {
		if let Some(size_v) = obj.get("size") {
			let bytes = size_value_to_u64(size_v);
			obj.insert("sizeBytes".into(), Value::from(bytes));
		}
	}
	if let Some(children) = n.get_mut("children").and_then(|x| x.as_array_mut()) {
		for ch in children {
			enrich_size_bytes(ch);
		}
	}
}

fn value_as_string(v: Option<&Value>) -> String {
	v.and_then(|item| item.as_str()).unwrap_or("").trim().to_string()
}

fn value_as_bool(v: Option<&Value>) -> bool {
	match v {
		Some(Value::Bool(flag)) => *flag,
		Some(Value::Number(number)) => number.as_u64().unwrap_or(0) != 0,
		Some(Value::String(text)) => matches!(text.trim(), "1" | "true" | "yes" | "on"),
		_ => false,
	}
}

fn collect_disk_infos(node: &Value, acc: &mut Vec<DiskInfo>) {
	let path = value_as_string(node.get("path"));
	let disk_type = value_as_string(node.get("type"));

	if !path.is_empty() && disk_type == "disk" {
		acc.push(DiskInfo {
			path: path.clone(),
			name: value_as_string(node.get("name")),
			model: value_as_string(node.get("model")),
			serial: value_as_string(node.get("serial")),
			transport: value_as_string(node.get("tran")),
			disk_type,
			size_bytes: size_value_to_u64(node.get("size").unwrap_or(&Value::Null)),
			read_only: value_as_bool(node.get("ro")),
			removable: value_as_bool(node.get("rm")),
			hotplug: value_as_bool(node.get("hotplug")),
		});
	}

	if let Some(children) = node.get("children").and_then(|item| item.as_array()) {
		for child in children {
			collect_disk_infos(child, acc);
		}
	}
}

async fn load_disk_inventory() -> Result<Vec<DiskInfo>, AppError> {
	let out = Command::new("lsblk")
		.args([
			"-J",
			"-b",
			"-o",
			"NAME,PATH,TYPE,SIZE,MODEL,SERIAL,RM,RO,HOTPLUG,TRAN",
		])
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.output()
		.await?;

	if !out.status.success() {
		return Err(AppError::CommandFailed(String::from_utf8(out.stderr)?));
	}

	let stdout = String::from_utf8(out.stdout)?;
	let parsed: Value = serde_json::from_str(&stdout)?;
	let blockdevices = parsed
		.get("blockdevices")
		.and_then(|item| item.as_array())
		.ok_or_else(|| AppError::Validation("lsblk retornou formato inesperado".into()))?;

	let mut disks = Vec::new();
	for blockdevice in blockdevices {
		collect_disk_infos(blockdevice, &mut disks);
	}

	disks.sort_by(|left, right| left.path.cmp(&right.path));
	disks.dedup_by(|left, right| left.path == right.path);
	Ok(disks)
}

fn disk_path_blocking_reason(disk: &DiskInfo) -> Option<String> {
	let invalid_prefix = [
		"/dev/loop",
		"/dev/zram",
		"/dev/ram",
		"/dev/sr",
		"/dev/fd",
		"/dev/md",
		"/dev/dm-",
		"/dev/mapper/",
		"/dev/nbd",
	]
	.iter()
	.any(|prefix| disk.path.starts_with(prefix));

	if !disk.path.starts_with("/dev/") {
		return Some("caminho fora de /dev".into());
	}
	if disk.disk_type != "disk" {
		return Some(format!("tipo nao elegivel: {}", disk.disk_type));
	}
	if invalid_prefix {
		return Some("loop device, CD-ROM, zram ou ramdisk nao sao elegiveis".into());
	}
	if disk.removable || disk.hotplug || disk.transport.eq_ignore_ascii_case("usb") {
		return Some("discos removiveis/USB nao sao aceitos".into());
	}
	if disk.read_only {
		return Some("disco marcado como readonly".into());
	}
	if disk.size_bytes == 0 {
		return Some("nao foi possivel determinar o tamanho util".into());
	}
	None
}

fn validate_disk_plan(plan: &InstallPlan, disk_inventory: &[DiskInfo]) -> Result<(), AppError> {
	let inventory_map: HashMap<&str, &DiskInfo> = disk_inventory
		.iter()
		.map(|disk| (disk.path.as_str(), disk))
		.collect();
	let selected_raw = plan.disk.selected_disks.clone().unwrap_or_default();
	let mut selected_paths = Vec::new();

	for path in selected_raw {
		let trimmed = path.trim();
		if !trimmed.is_empty() {
			selected_paths.push(trimmed.to_string());
		}
	}

	if selected_paths.is_empty() {
		return Err(AppError::Validation("disk.selectedDisks vazio".into()));
	}

	let mut seen = std::collections::HashSet::new();
	for path in &selected_paths {
		if !seen.insert(path.clone()) {
			return Err(AppError::Validation(format!("disk.selectedDisks contem duplicata: {path}")));
		}
		let disk = inventory_map
			.get(path.as_str())
			.ok_or_else(|| AppError::Validation(format!("disco nao encontrado no inventario atual: {path}")))?;
		if let Some(reason) = disk_path_blocking_reason(disk) {
			return Err(AppError::Validation(format!("{path}: {reason}")));
		}
	}

	if !selected_paths.iter().any(|path| path == &plan.disk.sys_disk) {
		return Err(AppError::Validation("disk.sysDisk precisa fazer parte de disk.selectedDisks".into()));
	}

	if plan.disk.profile == "raid" {
		let raid_level = plan.disk.raid_level.as_deref().unwrap_or("");
		let min_required = match raid_level {
			"raid0" | "raid1" => 2,
			"raid5" => 3,
			"raid10" => 4,
			_ => return Err(AppError::Validation("disk.raidLevel invalido".into())),
		};

		if selected_paths.len() < min_required {
			return Err(AppError::Validation(format!(
				"disk.selectedDisks precisa ter pelo menos {min_required} discos para {raid_level}"
			)));
		}
		if raid_level == "raid10" && selected_paths.len() % 2 != 0 {
			return Err(AppError::Validation("RAID 10 exige quantidade par de discos".into()));
		}
		if plan.disk.data_disk.is_some() {
			return Err(AppError::Validation("disk.dataDisk deve ficar vazio em RAID".into()));
		}

		let mut smallest = u64::MAX;
		let mut largest = 0u64;
		for path in &selected_paths {
			if let Some(disk) = inventory_map.get(path.as_str()) {
				smallest = smallest.min(disk.size_bytes);
				largest = largest.max(disk.size_bytes);
			}
		}

		if matches!(raid_level, "raid1" | "raid5" | "raid10") && largest > 0 {
			let deviation = ((largest - smallest) as f64 / largest as f64) * 100.0;
			if deviation > 5.0 {
				return Err(AppError::Validation(format!(
					"Os discos selecionados nao sao suficientemente homogeneos para {raid_level} (desvio {:.1}% > 5%)",
					deviation
				)));
			}
		}
	} else if plan.disk.mode == "two" {
		if selected_paths.len() != 2 {
			return Err(AppError::Validation(
				"disk.selectedDisks deve conter exatamente 2 discos no layout split".into(),
			));
		}
		let data = plan
			.disk
			.data_disk
			.as_deref()
			.ok_or_else(|| AppError::Validation("disk.dataDisk obrigatorio (modo two)".into()))?;
		if !selected_paths.iter().any(|path| path == data) {
			return Err(AppError::Validation("disk.dataDisk precisa fazer parte de disk.selectedDisks".into()));
		}
		if data == plan.disk.sys_disk {
			return Err(AppError::Validation("disk.dataDisk nao pode ser igual ao disk.sysDisk".into()));
		}
	} else {
		if selected_paths.len() != 1 {
			return Err(AppError::Validation(
				"disk.selectedDisks deve conter exatamente 1 disco no layout single".into(),
			));
		}
		if plan.disk.data_disk.is_some() {
			return Err(AppError::Validation("disk.dataDisk nao e permitido no layout single".into()));
		}
	}

	Ok(())
}

async fn get_disk_layout(Query(q): Query<DiskLayoutQuery>) -> Result<Json<Value>, AppError> {
	let disk = q.disk.trim().to_string();
	if !disk.starts_with("/dev/") {
		return Err(AppError::Validation("disk inválido".into()));
	}

	// lsblk JSON tree with bytes. Using PATH keeps /dev/xyz stable for UI.
	let out = Command::new("lsblk")
		.args([
			"-J",
			"-b",
			"-o",
			"NAME,PATH,TYPE,SIZE,MOUNTPOINT,FSTYPE,PKNAME",
		])
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.output()
		.await?;
	if !out.status.success() {
		return Err(AppError::CommandFailed(String::from_utf8(out.stderr)?));
	}
	let stdout = String::from_utf8(out.stdout)?;
	let v: Value = serde_json::from_str(&stdout)?;
	let blockdevices = v
		.get("blockdevices")
		.and_then(|x| x.as_array())
		.ok_or_else(|| AppError::Validation("lsblk retornou formato inesperado".into()))?;

	let mut disk_val: Option<Value> = None;
	for bd in blockdevices {
		if let Some(found) = find_disk_value(bd, &disk) {
			disk_val = Some(found);
			break;
		}
	}
	let mut disk_val = disk_val.ok_or_else(|| AppError::Validation("disco não encontrado".into()))?;
	enrich_size_bytes(&mut disk_val);
	let size_bytes = disk_val
		.get("sizeBytes")
		.map(size_value_to_u64)
		.unwrap_or(0);

	Ok(Json(serde_json::json!({
		"disk": disk_val,
		"sizeBytes": size_bytes,
	})))
}

async fn get_keymaps() -> Result<Json<ListResponse>, AppError> {
	let out = Command::new("localectl")
		.args(["list-keymaps"])
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.output()
		.await?;
	if !out.status.success() {
		return Err(AppError::CommandFailed(String::from_utf8(out.stderr)?));
	}
	let stdout = String::from_utf8(out.stdout)?;
	let items = stdout
		.lines()
		.map(|l| l.trim())
		.filter(|l| !l.is_empty())
		.map(|l| l.to_string())
		.collect();
	Ok(Json(ListResponse { items }))
}

async fn get_locales() -> Result<Json<ListResponse>, AppError> {
	// Preferência: `localectl list-locales` (systemd). Fallback: `locale -a`.
	let out = Command::new("localectl")
		.args(["list-locales"])
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.output()
		.await;

	let mut items: Vec<String> = match out {
		Ok(o) if o.status.success() => {
			let stdout = String::from_utf8(o.stdout)?;
			stdout
				.lines()
				.map(|l| l.trim())
				.filter(|l| !l.is_empty())
				.map(|l| l.to_string())
				.collect()
		}
		_ => vec![],
	};

	if items.is_empty() {
		let out = Command::new("locale")
			.args(["-a"])
			.stdout(Stdio::piped())
			.stderr(Stdio::piped())
			.output()
			.await;
		if let Ok(o) = out {
			if o.status.success() {
				let stdout = String::from_utf8(o.stdout)?;
				items = stdout
					.lines()
					.map(|l| l.trim())
					.filter(|l| !l.is_empty())
					.map(|l| l.to_string())
					.collect();
			}
		}
	}

	items.sort();
	items.dedup();
	Ok(Json(ListResponse { items }))
}

async fn get_countries() -> Result<Json<ListResponse>, AppError> {
	let mut content = None;
	for p in zoneinfo_tab_candidates(&["iso3166.tab", "zone1970.tab", "zone.tab"]) {
		if p.exists() {
			content = Some(fs::read_to_string(&p).await?);
			break;
		}
	}

	if let Some(text) = content {
		let mut items = vec![];
		for line in text.lines() {
			let line = line.trim();
			if line.is_empty() || line.starts_with('#') {
				continue;
			}
			// iso3166.tab: "BR\tBrazil"
			let mut parts = line.split('\t');
			let code_or_cc = parts.next().unwrap_or("").trim();
			let name = parts.next().unwrap_or("").trim();
			if !code_or_cc.is_empty() {
				// Para autocomplete, preferimos manter valores curtos quando possível.
				// Se for iso3166.tab, o primeiro campo é o código do país.
				if code_or_cc.len() == 2 && code_or_cc.chars().all(|c| c.is_ascii_uppercase()) {
					items.push(code_or_cc.to_string());
				} else if !name.is_empty() {
					items.push(name.to_string());
				}
			}
		}
		items.sort();
		items.dedup();
		return Ok(Json(ListResponse { items }));
	}

	// Fallback: deriva códigos de país a partir de locales (ex: pt_BR.UTF-8 -> BR)
	let out = Command::new("locale")
		.args(["-a"])
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.output()
		.await;

	let mut items: Vec<String> = vec![];
	if let Ok(o) = out {
		if o.status.success() {
			let stdout = String::from_utf8(o.stdout)?;
			for line in stdout.lines() {
				let s = line.trim();
				// formatos comuns: pt_BR.UTF-8, en_US, de_DE@euro
				let mut s = s.split('@').next().unwrap_or(s);
				s = s.split('.').next().unwrap_or(s);
				if let Some((_lang, cc)) = s.split_once('_') {
					let cc = cc.trim();
					if cc.len() == 2 && cc.chars().all(|c| c.is_ascii_uppercase()) {
						items.push(cc.to_string());
					}
				}
			}
		}
	}

	items.sort();
	items.dedup();
	Ok(Json(ListResponse { items }))
}

async fn get_disks() -> Result<Json<DisksResponse>, AppError> {
	let disks = load_disk_inventory().await?;
	Ok(Json(DisksResponse { disks }))
}

async fn validate_plan(plan: &InstallPlan, secrets: &InstallSecrets) -> Result<(), AppError> {
	if plan.version != INSTALL_PLAN_VERSION {
		return Err(AppError::Validation(format!(
			"plan.version não suportado: {} (esperado: {})",
			plan.version, INSTALL_PLAN_VERSION
		)));
	}

	// Disk
	if plan.disk.mode != "one" && plan.disk.mode != "two" {
		return Err(AppError::Validation("disk.mode inválido".into()));
	}
	if plan.disk.profile != "single" && plan.disk.profile != "raid" {
		return Err(AppError::Validation("disk.profile inválido".into()));
	}
	if !plan.disk.sys_disk.starts_with("/dev/") {
		return Err(AppError::Validation("disk.sysDisk inválido".into()));
	}
	let disk_inventory = load_disk_inventory().await?;
	validate_disk_plan(plan, &disk_inventory)?;
	if plan.disk.profile == "raid" {
		let disks = plan.disk.selected_disks.clone().unwrap_or_default();
		let raid_level = plan.disk.raid_level.as_deref().unwrap_or("");
		if raid_level.is_empty() {
			return Err(AppError::Validation("disk.raidLevel obrigatório (raid)".into()));
		}
		let min_required = match raid_level {
			"raid0" | "raid1" => 2,
			"raid5" => 3,
			"raid10" => 4,
			_ => return Err(AppError::Validation("disk.raidLevel inválido".into())),
		};
		if disks.len() < min_required {
			return Err(AppError::Validation(format!(
				"disk.selectedDisks precisa ter {min_required}+ discos ({raid_level})"
			)));
		}
		if plan.disk.root_fs.as_deref().unwrap_or("btrfs") != "btrfs" {
			return Err(AppError::Validation("No modo RAID, rootFs deve ser btrfs".into()));
		}
		if plan.disk.data_fs.as_deref().unwrap_or("btrfs") != "btrfs" {
			return Err(AppError::Validation("No modo RAID, dataFs deve ser btrfs".into()));
		}
	} else if plan.disk.mode == "two" {
		let data = plan
			.disk
			.data_disk
			.as_deref()
			.ok_or_else(|| AppError::Validation("disk.dataDisk obrigatório (modo two)".into()))?;
		if !data.starts_with("/dev/") {
			return Err(AppError::Validation("disk.dataDisk inválido".into()));
		}
		if data == plan.disk.sys_disk {
			return Err(AppError::Validation("disk.dataDisk não pode ser igual ao disk.sysDisk".into()));
		}
		let root_fs = plan
			.disk
			.root_fs
			.as_deref()
			.ok_or_else(|| AppError::Validation("disk.rootFs obrigatório (modo two)".into()))?;
		let data_fs = plan
			.disk
			.data_fs
			.as_deref()
			.ok_or_else(|| AppError::Validation("disk.dataFs obrigatório (modo two)".into()))?;
		let valid_fs = ["btrfs", "ext4", "xfs"];
		if !valid_fs.contains(&root_fs) {
			return Err(AppError::Validation("disk.rootFs inválido".into()));
		}
		if !valid_fs.contains(&data_fs) {
			return Err(AppError::Validation("disk.dataFs inválido".into()));
		}
	} else {
		if plan.disk.data_disk.is_some() {
			return Err(AppError::Validation("disk.dataDisk deve ficar vazio no layout single".into()));
		}
		if plan.disk.root_fs.as_deref().unwrap_or("btrfs") != "btrfs" {
			return Err(AppError::Validation("No layout single, rootFs deve ser btrfs".into()));
		}
		if plan.disk.data_fs.as_deref().unwrap_or("btrfs") != "btrfs" {
			return Err(AppError::Validation("No layout single, dataFs deve ser btrfs".into()));
		}
	}

	// Locale
	if plan.locale.country.trim().is_empty() {
		return Err(AppError::Validation("locale.country vazio".into()));
	}
	if plan.locale.timezone.trim().is_empty() {
		return Err(AppError::Validation("locale.timezone vazio".into()));
	}
	let known_timezones = load_timezone_items().await?;
	if !known_timezones.iter().any(|item| item == &plan.locale.timezone) {
		return Err(AppError::Validation(format!(
			"locale.timezone invalido ou nao suportado pelo host: {}",
			plan.locale.timezone
		)));
	}
	if plan.locale.locale.trim().is_empty() {
		return Err(AppError::Validation("locale.locale vazio".into()));
	}
	if plan.locale.keymap.trim().is_empty() {
		return Err(AppError::Validation("locale.keymap vazio".into()));
	}

	// Admin
	if plan.admin.user.trim().is_empty() {
		return Err(AppError::Validation("admin.user vazio".into()));
	}
	if plan.admin.email.trim().is_empty() {
		return Err(AppError::Validation("admin.email vazio".into()));
	}
	if secrets.admin_password.len() < 8 {
		return Err(AppError::Validation("Senha deve ter pelo menos 8 caracteres".into()));
	}
	if !is_strong_password(&secrets.admin_password) {
		return Err(AppError::Validation(
			"Senha fraca: use 12+ caracteres e misture maiúsculas, minúsculas, números e símbolos".into(),
		));
	}
	if secrets.admin_password != secrets.admin_password_confirm {
		return Err(AppError::Validation("Senha e confirmação não batem".into()));
	}

	// Network
	if plan.network.server_ip.trim().is_empty() {
		return Err(AppError::Validation("network.serverIp vazio".into()));
	}
	if !is_valid_ipv4(&plan.network.server_ip) {
		return Err(AppError::Validation("network.serverIp inválido".into()));
	}
	if plan.network.hostname.trim().is_empty() {
		return Err(AppError::Validation("network.hostname vazio".into()));
	}
	if plan.network.interface.trim().is_empty() {
		return Err(AppError::Validation("network.interface vazio".into()));
	}
	if plan.network.gateway.trim().is_empty() {
		return Err(AppError::Validation("network.gateway vazio".into()));
	}
	if !is_valid_ipv4(&plan.network.gateway) {
		return Err(AppError::Validation("network.gateway inválido".into()));
	}
	if plan.network.dns.is_empty() {
		return Err(AppError::Validation("network.dns vazio".into()));
	}
	if !plan.network.dns.iter().all(|item| is_valid_ipv4(item)) {
		return Err(AppError::Validation("network.dns contém IPv4 inválido".into()));
	}
	if plan.network.prefix_length == 0 || plan.network.prefix_length > 32 {
		return Err(AppError::Validation("network.prefixLength inválido".into()));
	}
	if plan.network.http_port == 0 {
		return Err(AppError::Validation("network.httpPort inválido".into()));
	}

	let wan = &plan.network.wan;
	if wan.mode != "dhcp" && wan.mode != "static" && wan.mode != "pppoe" {
		return Err(AppError::Validation("network.wan.mode inválido".into()));
	}
	if !wan.interface.trim().is_empty() && wan.interface.trim() == plan.network.interface.trim() {
		return Err(AppError::Validation("network.wan.interface não pode ser igual a network.interface".into()));
	}
	if !wan.interface.trim().is_empty() && wan.mode == "static" {
		if wan.address.as_deref().unwrap_or("").trim().is_empty() {
			return Err(AppError::Validation("network.wan.address obrigatório (static)".into()));
		}
		if !is_valid_ipv4(wan.address.as_deref().unwrap_or("")) {
			return Err(AppError::Validation("network.wan.address inválido".into()));
		}
		if wan.prefix_length.unwrap_or(0) == 0 || wan.prefix_length.unwrap_or(0) > 32 {
			return Err(AppError::Validation("network.wan.prefixLength obrigatório (static)".into()));
		}
		if wan.gateway.as_deref().unwrap_or("").trim().is_empty() {
			return Err(AppError::Validation("network.wan.gateway obrigatório (static)".into()));
		}
		if !is_valid_ipv4(wan.gateway.as_deref().unwrap_or("")) {
			return Err(AppError::Validation("network.wan.gateway inválido".into()));
		}
		let dns = wan
			.dns
			.as_ref()
			.ok_or_else(|| AppError::Validation("network.wan.dns obrigatório (static)".into()))?;
		if dns.is_empty() {
			return Err(AppError::Validation("network.wan.dns obrigatório (static)".into()));
		}
		if !dns.iter().all(|item| is_valid_ipv4(item)) {
			return Err(AppError::Validation("network.wan.dns contém IPv4 inválido".into()));
		}
	}
	if !wan.interface.trim().is_empty() && wan.mode == "pppoe" {
		if wan.pppoe_user.as_deref().unwrap_or("").trim().is_empty() {
			return Err(AppError::Validation("network.wan.pppoeUser obrigatório (pppoe)".into()));
		}
		if secrets.wan_pppoe_password.as_deref().unwrap_or("").trim().is_empty() {
			return Err(AppError::Validation("secrets.wanPppoePassword obrigatório (pppoe)".into()));
		}
	}

	Ok(())
}

fn is_valid_ipv4(value: &str) -> bool {
	value.trim().parse::<Ipv4Addr>().is_ok()
}

fn validate_plan_schema(plan_value: &Value) -> Result<(), AppError> {
	let schema_json: Value = serde_json::from_str(include_str!("install-plan.schema.json"))?;
	let compiled = JSONSchema::options().compile(&schema_json)
		.map_err(|e| AppError::Validation(format!("schema inválido: {e}")))?;

	if let Err(errors) = compiled.validate(plan_value) {
		let msg = errors
			.take(12)
			.map(|e| e.to_string())
			.collect::<Vec<_>>()
			.join("; ");
		return Err(AppError::Validation(format!("plano inválido: {msg}")));
	}
	Ok(())
}

fn is_strong_password(pw: &str) -> bool {
	if pw.len() < 12 {
		return false;
	}
	let mut have_lower = false;
	let mut have_upper = false;
	let mut have_digit = false;
	let mut have_symbol = false;
	for ch in pw.chars() {
		if ch.is_ascii_lowercase() {
			have_lower = true;
		} else if ch.is_ascii_uppercase() {
			have_upper = true;
		} else if ch.is_ascii_digit() {
			have_digit = true;
		} else if !ch.is_whitespace() {
			have_symbol = true;
		}
	}
	let classes = [have_lower, have_upper, have_digit, have_symbol]
		.into_iter()
		.filter(|x| *x)
		.count();
	classes >= 3
}

fn parse_dns_csv(s: &str) -> Vec<String> {
	s.split(',')
		.map(|x| x.trim())
		.filter(|x| !x.is_empty())
		.map(|x| x.to_string())
		.collect()
}

fn netmask_to_prefix(netmask: &str) -> Result<u8, AppError> {
	let parts: Vec<&str> = netmask.trim().split('.').collect();
	if parts.len() != 4 {
		return Err(AppError::Validation("Netmask inválida".into()));
	}
	let mut bits = 0u8;
	let mut seen_zero = false;
	for p in parts {
		let oct: u8 = p
			.parse()
			.map_err(|_| AppError::Validation("Netmask inválida".into()))?;
		for i in (0..8).rev() {
			let b = (oct >> i) & 1;
			if b == 1 {
				if seen_zero {
					return Err(AppError::Validation("Netmask inválida".into()));
				}
				bits = bits.saturating_add(1);
			} else {
				seen_zero = true;
			}
		}
	}
	Ok(bits)
}

async fn hash_password_sha512(password: &str) -> Result<String, AppError> {
	let mut child = Command::new("mkpasswd")
		.args(["-m", "sha-512", "--stdin"])
		.stdin(Stdio::piped())
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.spawn()?;

	{
		use tokio::io::AsyncWriteExt;
		let mut stdin = child
			.stdin
			.take()
			.ok_or_else(|| AppError::CommandFailed("mkpasswd stdin".into()))?;
		stdin.write_all(password.as_bytes()).await?;
		stdin.write_all(b"\n").await?;
	}

	let out = child.wait_with_output().await?;
	if !out.status.success() {
		return Err(AppError::CommandFailed(String::from_utf8(out.stderr)?));
	}
	let stdout = String::from_utf8(out.stdout)?;
	let hash = stdout.lines().next().unwrap_or("").trim().to_string();
	if hash.is_empty() {
		return Err(AppError::CommandFailed("mkpasswd retornou vazio".into()));
	}
	Ok(hash)
}

async fn post_plan(
	State(state): State<AppState>,
	Json(payload): Json<Value>,
) -> Result<Json<InstallPlan>, AppError> {
	let (plan_value, secrets_value) = if payload.get("plan").is_some() {
		(
			payload.get("plan").cloned().unwrap_or(Value::Null),
			payload.get("secrets").cloned().unwrap_or(Value::Null),
		)
	} else {
		(Value::Null, Value::Null)
	};

	if plan_value.is_null() {
		return Err(AppError::Validation("payload inválido: esperado { plan, secrets }".into()));
	}
	if secrets_value.is_null() {
		return Err(AppError::Validation("payload inválido: secrets ausente".into()));
	}

	validate_plan_schema(&plan_value)?;
	let plan: InstallPlan = serde_json::from_value(plan_value)?;
	let secrets: InstallSecrets = serde_json::from_value(secrets_value)?;
	validate_plan(&plan, &secrets).await?;

	let ist = read_install_state(&state.runtime_dir).await?;
	if ist.running {
		return Err(AppError::Validation("instalação em andamento: não é permitido alterar o plano".into()));
	}
	ensure_runtime_dir(&state.runtime_dir).await?;

	let plan_bytes = serde_json::to_vec_pretty(&plan)?;
	write_file_with_mode(&plan_path(&state.runtime_dir), &plan_bytes, 0o644).await?;

	// Secrets: escrita separada
	let secrets_bytes = serde_json::to_vec_pretty(&secrets)?;
	write_file_with_mode(&secrets_path(&state.runtime_dir), &secrets_bytes, 0o600).await?;

	// Integridade: HMAC do plano e manifest de checksums.
	let key = read_or_create_hmac_key(&state.runtime_dir).await?;
	let sig = sign_plan_hmac_sha256(&plan_bytes, &key)?;
	write_file_with_mode(&plan_sig_path(&state.runtime_dir), &sig, 0o600).await?;
	write_runtime_manifest(&state.runtime_dir, &plan_bytes, &secrets_bytes, &sig).await?;

	// Marca estado como pronto.
	let mut ist = read_install_state(&state.runtime_dir).await?;
	ist.running = false;
	ist.current_phase = None;
	ist.last_error = None;
	ist.last_log_line = None;
	write_install_state(&state.runtime_dir, &ist).await?;

	Ok(Json(plan))
}

async fn get_status(State(state): State<AppState>) -> Result<Json<StatusResponse>, AppError> {
	let have_plan = plan_path(&state.runtime_dir).exists();
	let ist = enrich_install_state(&state.runtime_dir, read_install_state(&state.runtime_dir).await?).await;
	Ok(Json(StatusResponse {
		have_plan,
		can_install: have_plan && !ist.running,
		running: ist.running,
		exit_code: ist.exit_code,
		started_at: ist.started_at_unix,
		finished_at: ist.finished_at_unix,
		install_running: ist.running,
		last_install_exit: ist.exit_code,
		install_started_at_unix: ist.started_at_unix,
		current_phase: ist.current_phase.clone(),
		last_error: ist.last_error.clone(),
		last_log_line: ist.last_log_line.clone(),
	}))
}

async fn get_log(State(state): State<AppState>) -> Result<Json<serde_json::Value>, AppError> {
	let tail = read_install_log_tail(&state.runtime_dir, 400).await?;
	if tail.trim().is_empty() {
		return Ok(Json(serde_json::json!({ "ok": false, "tail": "(sem log ainda)" })));
	}
	Ok(Json(serde_json::json!({ "ok": true, "tail": tail })))
}

async fn get_install_log(
	State(state): State<AppState>,
) -> Result<Sse<impl tokio_stream::Stream<Item = Result<Event, Infallible>>>, AppError> {
	let runtime_dir = state.runtime_dir.clone();
	let log_file = log_path(&runtime_dir).to_string_lossy().to_string();
	let mut child = Command::new("tail")
		.args(["-n", "400", "-F", &log_file])
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.spawn()?;

	let stdout = child
		.stdout
		.take()
		.ok_or_else(|| AppError::CommandFailed("tail stdout".into()))?;
	let mut lines = BufReader::new(stdout).lines();
	let mut tick = interval(Duration::from_secs(1));
	let mut last_state = InstallState::default();
	let stream = async_stream::stream! {
		loop {
			tokio::select! {
				line = lines.next_line() => {
					match line {
						Ok(Some(l)) => {
							yield Ok(Event::default().event("log").data(format!("{}\n", l)));
						}
						Ok(None) => {
							break;
						}
						Err(_) => {
							break;
						}
					}
				}
				_ = tick.tick() => {
					let st = enrich_install_state(&runtime_dir, read_install_state(&runtime_dir).await.unwrap_or_default()).await;
					if st != last_state {
						last_state = st.clone();
						yield Ok(Event::default().event("status").data(serde_json::to_string(&last_state).unwrap_or_else(|_| "{}".into())));
					}
					if !last_state.running {
						if let Some(code) = last_state.exit_code {
							yield Ok(Event::default().event("done").data(code.to_string()));
							break;
						}
					}
				}
			}
		}
		let _ = child.kill().await;
	};

	Ok(Sse::new(stream))
}

async fn post_reboot(State(state): State<AppState>) -> Result<Json<serde_json::Value>, AppError> {
	let ist = read_install_state(&state.runtime_dir).await?;
	if ist.running {
		return Err(AppError::Validation("instalação ainda em andamento".into()));
	}
	if ist.exit_code != Some(0) {
		return Err(AppError::Validation("reboot liberado apenas após sucesso".into()));
	}
	let out = Command::new("systemctl")
		.args(["reboot"])
		.stdout(Stdio::piped())
		.stderr(Stdio::piped())
		.output()
		.await;
	match out {
		Ok(o) if o.status.success() => Ok(Json(serde_json::json!({"ok": true}))),
		Ok(o) => Err(AppError::CommandFailed(String::from_utf8(o.stderr)?)),
		Err(e) => Err(AppError::Io(e)),
	}
}

async fn post_install(
	State(state): State<AppState>,
	Json(req): Json<InstallRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
	if !req.confirm_wipe {
		return Err(AppError::Validation(
			"confirmWipe obrigatório: envie {\"confirmWipe\": true} para iniciar".into(),
		));
	}

	let _guard = state.install_lock.lock().await;
	ensure_runtime_dir(&state.runtime_dir).await?;

	let lf = log_path(&state.runtime_dir);
	write_file_with_mode(&lf, b"", 0o644).await?;

	let plan_file = plan_path(&state.runtime_dir);
	let secrets_file = secrets_path(&state.runtime_dir);
	if !plan_file.exists() {
		return Err(AppError::Validation("sem plano: finalize o wizard antes".into()));
	}
	if !secrets_file.exists() {
		return Err(AppError::Validation("sem secrets: finalize o wizard antes".into()));
	}

	verify_runtime_integrity(&state.runtime_dir).await?;
	let plan_file_str = plan_file.to_string_lossy().to_string();
	let secrets_file_str = secrets_file.to_string_lossy().to_string();
	let log_file_str = lf.to_string_lossy().to_string();
	let log_file_str_spawn = log_file_str.clone();
	let installer_runner = resolve_installer_runner()?;

	let ist = read_install_state(&state.runtime_dir).await?;
	if ist.running {
		return Err(AppError::Validation("instalação já em andamento".into()));
	}

	// Marca como running.
	write_install_state(
		&state.runtime_dir,
		&InstallState {
			running: true,
			exit_code: None,
			started_at_unix: Some(now_unix()),
			finished_at_unix: None,
			current_phase: Some("PRECHECK".into()),
			last_error: None,
			last_log_line: Some("Instalacao iniciada pelo backend. Aguardando precheck.".into()),
		},
	)
	.await?;

	let runtime_dir = state.runtime_dir.clone();
	tokio::spawn(async move {
		let mut cmd = Command::new(&installer_runner);
		cmd.arg("unattended");
		cmd.arg("--plan").arg(&plan_file_str);
		cmd.arg("--secrets").arg(&secrets_file_str);
		cmd.arg("--log").arg(&log_file_str_spawn);
		cmd.env("RAGOS_I_UNDERSTAND_THIS_WIPES_DISKS", "YES");

		cmd.stdout(Stdio::inherit());
		cmd.stderr(Stdio::inherit());

		info!("starting installer unattended");
		let status = cmd.status().await;
		let (ok, code, spawn_error) = match status {
			Ok(s) => (s.success(), s.code().unwrap_or(1), None),
			Err(error) => (false, 1, Some(error.to_string())),
		};

		warn!(exit_code = code, ok = ok, "installer finished");
		let previous_state = read_install_state(&runtime_dir).await.unwrap_or_default();
		let started_at = previous_state.started_at_unix;
		let mut next_state = enrich_install_state(&runtime_dir, previous_state).await;
		if let Some(error) = spawn_error {
			next_state.last_error = Some(format!("Falha ao iniciar ragos-install: {error}"));
			next_state.current_phase = Some("ERROR".into());
		}
		let _ = write_install_state(
			&runtime_dir,
			&InstallState {
				running: false,
				exit_code: Some(code),
				started_at_unix: started_at,
				finished_at_unix: Some(now_unix()),
				current_phase: next_state.current_phase.take(),
				last_error: next_state.last_error.take(),
				last_log_line: next_state.last_log_line.take(),
			},
		)
		.await;
	});

	Ok(Json(serde_json::json!({
		"started": true,
		"log_file": log_file_str
	})))
}

#[tokio::main]
async fn main() -> Result<(), AppError> {
	tracing_subscriber::fmt()
		.with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
		.init();

	let listen = std::env::var("RAGOS_INSTALLER_LISTEN").unwrap_or_else(|_| "0.0.0.0:8000".into());
	let addr: SocketAddr = listen
		.parse()
		.map_err(|_| AppError::Validation("RAGOS_INSTALLER_LISTEN inválido".into()))?;

	let static_dir = std::env::var("RAGOS_INSTALLER_STATIC")
		.map(PathBuf::from)
		.unwrap_or_else(|_| {
			let local = PathBuf::from("./static");
			if local.exists() {
				return local;
			}
			let repo = PathBuf::from("./installer/installer-ui/static");
			if repo.exists() {
				return repo;
			}
			local
		});
	let imgs_dir = std::env::var("RAGOS_INSTALLER_IMGS")
		.map(PathBuf::from)
		.unwrap_or_else(|_| {
			let dev_imgs = PathBuf::from("./imgs");
			if dev_imgs.exists() {
				dev_imgs
			} else if PathBuf::from("./installer/installer-ui/imgs").exists() {
				PathBuf::from("./installer/installer-ui/imgs")
			} else {
				static_dir.join("imgs")
			}
		});
	let runtime_dir = std::env::var("RAGOS_INSTALLER_RUNTIME")
		.map(PathBuf::from)
		.unwrap_or_else(|_| {
			let mut candidates: Vec<PathBuf> = vec![PathBuf::from("/run/ragos-installer")];
			if let Ok(xdg) = std::env::var("XDG_RUNTIME_DIR") {
				if !xdg.trim().is_empty() {
					candidates.push(PathBuf::from(xdg).join("ragos-installer"));
				}
			}
			candidates.push(PathBuf::from("./runtime"));

			for p in candidates {
				if std::fs::create_dir_all(&p).is_ok() {
					return p;
				}
			}

			PathBuf::from("./runtime")
		});

	let state = AppState {
		static_dir,
		imgs_dir,
		runtime_dir,
		install_lock: Arc::new(Mutex::new(())),
	};

		info!(
			static_dir = %state.static_dir.display(),
			imgs_dir = %state.imgs_dir.display(),
			runtime_dir = %state.runtime_dir.display(),
			"installer-ui paths"
		);
		ensure_runtime_dir(&state.runtime_dir).await?;

		let app = Router::new()
		.route("/", get(get_index))
		.nest_service("/imgs", ServeDir::new(state.imgs_dir.clone()))
		.route("/api/v1/disks", get(get_disks))
		.route("/api/v1/disk-layout", get(get_disk_layout))
		.route("/api/v1/netifs", get(get_netifs))
		.route("/api/v1/network-test", get(get_network_test))
		.route("/api/v1/timezones", get(get_timezones))
		.route("/api/v1/timezone-locations", get(get_timezone_locations))
		.route("/api/v1/keymaps", get(get_keymaps))
		.route("/api/v1/locales", get(get_locales))
		.route("/api/v1/countries", get(get_countries))
		.route("/api/v1/plan", post(post_plan))
		.route("/api/v1/install", post(post_install))
		.route("/api/v1/install-log", get(get_install_log))
		.route("/api/v1/status", get(get_status))
		.route("/api/v1/log", get(get_log))
		.route("/api/v1/reboot", post(post_reboot))
		.layer(SetResponseHeaderLayer::if_not_present(
			CACHE_CONTROL,
			HeaderValue::from_static("no-store"),
		))
		.layer(TraceLayer::new_for_http())
		.with_state(state.clone())
		.fallback_service(ServeDir::new(state.static_dir));

	info!(%addr, "ragos-installer-ui listening");
	let listener = tokio::net::TcpListener::bind(addr).await?;
	axum::serve(listener, app).await?;
	Ok(())
}
