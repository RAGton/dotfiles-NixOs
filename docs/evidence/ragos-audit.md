# Auditoria do Repositório `ragos-installer`

**Data:** 28 de Maio de 2026
**Alvo:** `https://github.com/RAGEnterprise/ragos-installer`
**Local de Clonagem:** `/tmp/audit-ragos`

## 1. Estrutura de Dependências Encontrada

A engine original operava em duas camadas distintas:
1. **Frontend (React + Vite):** Localizado na pasta `installer-ui/`. Utiliza Vite como bundler, React/React-DOM para interface e TailwindCSS para estilização. Também utiliza dependências como `ajv` para validação de schemas.
2. **Backend/Orquestração (Bash):** Uma complexa rede de scripts em bash (`bin/ragos-install`, arquivos na pasta `lib/` e `steps/`) que faziam a ponte entre as interações do usuário e o particionamento real (via CLI).

## 2. O que será removido (Outros Fins e Legados)

A governança do Kryonix prescreve que lógica de sistema e orquestração de hardware deve ser realizada pelo Backend Axum (Rust), garantindo isolamento e segurança, sendo assim, eliminaremos e repudiaremos:
- **Scripts em Bash:** Toda a infraestrutura na pasta `bin/`, `lib/` e `steps/` do repositório clonado. Ela entra em conflito direto com o `axum` Rust que acabou de ser implementado.
- **Identidade Visual e Marcas:** Remoção de imagens e nomes referentes ao "RAG Enterprise" e "RAGos" (ex: `imgs/ragton.png`, textos "Instalador RAGos", referências a `srv-rag` como hostname).
- **Hardcodes:** Qualquer hostname fixado, endpoints legados que apontem para IPs estáticos de nuvem ou configurações restritas. 

*Nota: Nenhuma telemetria externa obscura de terceiros foi detectada no código-fonte em React.*

## 3. O que será mantido (Lógica de Interface Web)

Preservaremos integralmente o Frontend Kiosk construído em React/Vite, mais especificamente o diretório `installer-ui/`:
- **UI de Páginas (Steps):** Componentes para configuração de localização, teclado, fuso horário, usuário e partição (Disks).
- **Configuração do Bundler:** A estrutura do `package.json`, Tailwind config e arquivos Vite.
- **Validação com `ajv`:** O schema JSON de `install-plan` gerado pela interface será preservado, pois se alinha com a segurança dos payloads recebidos no Axum (`POST /api/install`).

## 4. Plano de Conversão para Assets Estáticos 

Para unificar o instalador em uma única engine sólida sob os princípios do Kryonix, faremos o seguinte:

1. **Build Nativo com Nix:** Vamos portar o diretório `installer-ui` para `/etc/kryonix/packages/kryonix-installer/ui` ou manteremos no diretório temporário para integrá-lo ao source code Rust.
2. **Pacote Único:** Durante a derivação do pacote (`default.nix` do installer), o Nix realizará o comando `npm install` e `npm run build` gerando os assets estáticos no diretório `dist/`.
3. **Integração no Axum:** Alteraremos o servidor Rust do `kryonix-installer` para servir esses assets diretamente. Usaremos o crate `tower-http` (com a feature `fs`) para criar um `ServeDir::new("dist")` montado na raiz (`/`) da nossa API Rust, operando na porta `8080`.
4. **Endpoint Rewrites:** A UI enviará os requests para `http://localhost:8080/api/...`, que serão capturados pela nossa engine de particionamento/stream via Axum, isolando totalmente o frontend Kiosk Web de qualquer shell nocivo.

---
**Conclusão da Fase 1:** O repositório foi validado. O frontend está apto a ser integrado e servido pela nova engine Rust do Kryonix. Nenhuma dependência maliciosa ou incompatível foi encontrada no repositório.
