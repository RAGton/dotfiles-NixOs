# RAGOS Installer UI

Este repositório contém a interface moderna do instalador do RAGOS.

Ao contrário do placeholder inicial, o diretório já reúne uma aplicação funcional dividida em duas camadas:

- **frontend em React + Vite**;
- **backend local em Rust + Axum**.

---

## O que esta UI faz hoje

O wizard atual cobre o fluxo principal de instalação do servidor RAGOS, incluindo:

- boas-vindas e aceite explícito;
- localização, locale e teclado;
- seleção de fuso horário;
- parâmetros de rede e hostname, com WAN opcional;
- particionamento por layout explícito (`single`, `split`, `raid`) em vez de ordem implícita de seleção;
- criação do usuário administrador;
- resumo final;
- execução da instalação com acompanhamento de status.

O backend local também oferece endpoints auxiliares para:

- listar discos;
- listar interfaces de rede;
- testar conectividade;
- gerar plano de instalação;
- acompanhar status da instalação.

---

## Estrutura do repositório

```text
.
├── Cargo.toml
├── package.json
├── vite.config.js
├── tailwind.config.js
├── src/
│   ├── App.jsx
│   ├── main.jsx
│   ├── main.rs
│   ├── components/
│   ├── pages/
│   ├── data/
│   └── utils/
├── static/
└── imgs/
```

---

## Arquitetura da aplicação

### Frontend

O frontend usa:

- React 18;
- Vite;
- Tailwind CSS.

O arquivo principal é `src/App.jsx`, que mantém o estado do wizard e controla a navegação entre as etapas.

### Backend local

O backend usa:

- Rust 2024;
- Axum;
- Tokio;
- `tower-http`;
- `serde`.

O arquivo principal é `src/main.rs`. Ele expõe a API local usada pela interface para inspeção do ambiente e execução controlada da instalação.

---

## Relação com o instalador shell

Esta UI não substitui o fluxo shell de forma conceitual; ela o organiza.

Quando este projeto for consumido pelo monorepo principal do RAGOS, o backend e a interface precisam continuar coerentes com:

- `installer/bin/ragos-install`;
- `installer/params.nix`;
- o fluxo final de `nixos-install`.

Se a UI coletar um dado novo, o backend e o contrato de parâmetros também precisam ser atualizados.

---

## Desenvolvimento local

### Frontend

```bash
npm install
npm run dev
```

### Build web

```bash
npm run build
```

### Backend Rust

```bash
cargo run
```

---

## Diretrizes para evolução

Ao modificar esta UI, preserve:

- fluxo de instalação linear e compreensível;
- validação forte dos campos críticos;
- mensagens claras em operações destrutivas;
- consistência entre frontend, backend e `params.nix`;
- comportamento previsível em caso de erro.

Mudanças nesta pasta devem ser refletidas também na documentação principal quando impactarem o processo de instalação.
