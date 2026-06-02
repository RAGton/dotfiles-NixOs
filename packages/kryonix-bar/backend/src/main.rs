// =============================================================================
// Kryonix Bar — Backend (D-Bus)
//
// Expõe a interface `org.kryonix.Bar` no barramento de sessão.
// Coleta métricas de sistema (CPU, RAM, Uptime) e publica via D-Bus para
// consumo pelo frontend QML.
// =============================================================================
use std::error::Error;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;
use zbus::{connection, interface};
use serde::{Serialize, Deserialize};
use sysinfo::{CpuRefreshKind, RefreshKind, System};

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
struct SystemState {
    cpu_usage: f32,
    ram_used: u64,
    ram_total: u64,
    hostname: String,
    uptime: u64,
}

struct KryonixBar {
    state: Arc<RwLock<SystemState>>,
    version: String,
}

#[interface(name = "org.kryonix.Bar")]
impl KryonixBar {
    /// Retorna o estado completo do sistema em formato JSON.
    async fn get_system_state(&self) -> String {
        let state = self.state.read().await;
        serde_json::to_string(&*state).unwrap_or_else(|_| "{}".to_string())
    }

    /// Retorna apenas o hostname.
    async fn get_hostname(&self) -> String {
        self.state.read().await.hostname.clone()
    }

    /// Retorna a versão do motor Kryonix Bar.
    async fn get_version(&self) -> &str {
        &self.version
    }

    /// Método legado para compatibilidade inicial.
    async fn status(&self) -> &str {
        "Kryonix Engine Online"
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let version = env!("CARGO_PKG_VERSION").to_string();
    let state = Arc::new(RwLock::new(SystemState::default()));
    
    // Inicializa sysinfo com hostname fixo
    {
        let mut sys = System::new_all();
        sys.refresh_all();
        let mut s = state.write().await;
        s.hostname = System::host_name().unwrap_or_else(|| "kryonix".to_string());
        s.ram_total = sys.total_memory();
    }

    let bar = KryonixBar {
        state: Arc::clone(&state),
        version,
    };

    // Publica a interface no D-Bus
    let _conn = connection::Builder::session()?
        .name("org.kryonix.Bar")?
        .serve_at("/org/kryonix/Bar", bar)?
        .build()
        .await?;

    println!("Kryonix Bar Backend Rodando (D-Bus: org.kryonix.Bar)");

    // Loop de atualização de métricas (cada 2 segundos)
    let update_state = Arc::clone(&state);
    tokio::spawn(async move {
        let mut sys = System::new_with_specifics(
            RefreshKind::new()
                .with_cpu(CpuRefreshKind::everything())
                .with_memory(MemoryRefreshKind::everything())
        );

        loop {
            tokio::time::sleep(Duration::from_secs(2)).await;
            
            sys.refresh_cpu_usage();
            sys.refresh_memory();
            
            let cpu_usage = sys.global_cpu_info().cpu_usage();
            let ram_used = sys.used_memory();
            let uptime = System::uptime();

            let mut s = update_state.write().await;
            s.cpu_usage = cpu_usage;
            s.ram_used = ram_used;
            s.uptime = uptime;
        }
    });

    // Mantém o processo vivo
    std::future::pending::<()>().await;
    Ok(())
}
