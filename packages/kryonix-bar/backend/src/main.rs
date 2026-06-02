// =============================================================================
// Kryonix Bar — Backend (D-Bus)
//
// Expõe a interface `org.kryonix.Bar` no barramento de sessão. Por enquanto é um
// scaffold mínimo (método `status`); evoluirá para publicar CPU, workspaces,
// etc., que o frontend QML da Kryonix Bar irá consumir.
// =============================================================================
use std::error::Error;
use std::future::pending;

use zbus::{connection, interface};

struct KryonixBarStatus;

#[interface(name = "org.kryonix.Bar")]
impl KryonixBarStatus {
    async fn status(&self) -> &str {
        "Kryonix Engine Online"
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let _conn = connection::Builder::session()?
        .name("org.kryonix.Bar")?
        .serve_at("/org/kryonix/Bar", KryonixBarStatus)?
        .build()
        .await?;

    println!("Kryonix Bar Backend Rodando. Pressione Ctrl+C para sair.");
    pending::<()>().await;
    Ok(())
}
