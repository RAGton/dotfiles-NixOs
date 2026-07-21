// MIGRATION STATUS:
// - ALL CHECKS NATIVE (Rust)
// - LEGACY FALLBACKS REMOVED

use colored::Colorize;
use std::fs;
use std::process::Command;

pub struct DoctorContext {
    pub pass: u32,
    pub warn: u32,
    pub fail: u32,
}

impl DoctorContext {
    pub fn new() -> Self {
        Self {
            pass: 0,
            warn: 0,
            fail: 0,
        }
    }
    pub fn ok(&mut self, msg: &str) {
        println!("{} {}", "[PASS]".green(), msg);
        self.pass += 1;
    }
    pub fn warn(&mut self, msg: &str) {
        println!("{} {}", "[WARN]".yellow(), msg);
        self.warn += 1;
    }
    pub fn fail(&mut self, msg: &str) {
        println!("{} {}", "[FAIL]".red(), msg);
        self.fail += 1;
    }
    pub fn info(&self, msg: &str) {
        println!("{} {}", "[INFO]".cyan(), msg);
    }
}

pub fn run_doctor() -> Result<(), String> {
    let mut ctx = DoctorContext::new();
    println!("================================================================");
    println!("GLACIER DOCTOR (Kryx Native Full)");
    println!("================================================================");

    check_identity(&mut ctx);
    check_systemd(&mut ctx);
    check_brain_health(&mut ctx);
    check_tailscale(&mut ctx);
    check_storage(&mut ctx);
    check_bridge(&mut ctx);

    println!("\n================================================================");
    println!("RESUMO NATIVO");
    println!("================================================================");
    println!("PASS: {}", ctx.pass);
    println!("WARN: {}", ctx.warn);
    println!("FAIL: {}", ctx.fail);

    if ctx.fail > 0 {
        return Err("O sistema tem falhas críticas (Nativo) para corrigir.".to_string());
    }
    Ok(())
}

fn check_identity(ctx: &mut DoctorContext) {
    if let Ok(host) = fs::read_to_string("/etc/hostname") {
        let host = host.trim();
        if host == "RVE-GLACIER" || host == "glacier" {
            ctx.ok(&format!("hostname está correto: {}", host));
        } else {
            ctx.warn(&format!("hostname não é o esperado: {}", host));
        }
    } else {
        ctx.fail("Não foi possível ler /etc/hostname");
    }
}

fn check_systemd(ctx: &mut DoctorContext) {
    let output = Command::new("systemctl")
        .arg("--failed")
        .arg("--no-pager")
        .output();

    if let Ok(out) = output {
        let stdout = String::from_utf8_lossy(&out.stdout);
        if stdout.contains("0 loaded units listed") {
            ctx.ok("Sem units failed no systemd");
        } else {
            ctx.fail("Existem units falhadas no systemd");
        }
    } else {
        ctx.fail("Não foi possível executar o systemctl");
    }
}

fn check_brain_health(ctx: &mut DoctorContext) {
    let brain_url = "http://127.0.0.1:8000/health";
    match ureq::get(brain_url)
        .timeout(std::time::Duration::from_secs(5))
        .call()
    {
        Ok(response) if response.status() == 200 => {
            ctx.ok("Brain API /health respondeu via HTTP ureq");
        }
        _ => {
            ctx.fail("Brain API /health não respondeu. Serviço pode estar inativo.");
        }
    }
}

fn check_tailscale(ctx: &mut DoctorContext) {
    let output = Command::new("tailscale").arg("status").output();

    if let Ok(out) = output {
        if out.status.success() {
            ctx.ok("Tailscale está ativo e conectado");
        } else {
            ctx.fail("Tailscale status reportou erro");
        }
    } else {
        ctx.warn("Tailscale não está instalado ou executável indisponível");
    }
}

fn check_storage(ctx: &mut DoctorContext) {
    let output = Command::new("zpool").arg("status").output();

    if let Ok(out) = output {
        let stdout = String::from_utf8_lossy(&out.stdout);
        if stdout.contains("state: ONLINE") {
            ctx.ok("ZFS Pools estão ONLINE");
        } else if stdout.contains("no pools available") {
            ctx.warn("Nenhum ZFS pool configurado");
        } else {
            ctx.fail("ZFS Pools com estado degradado ou erro");
        }
    } else {
        ctx.warn("ZFS Utils não encontrados (zpool)");
    }
}

fn check_bridge(ctx: &mut DoctorContext) {
    let output = Command::new("ip")
        .arg("link")
        .arg("show")
        .arg("br0")
        .output();

    if let Ok(out) = output {
        if out.status.success() {
            ctx.ok("Interface Bridge br0 está presente");
        } else {
            ctx.warn("Interface Bridge br0 não configurada");
        }
    } else {
        ctx.warn("Comando ip link indisponível");
    }
}
