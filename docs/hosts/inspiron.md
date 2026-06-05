# Host: Inspiron

Este documento descreve o papel do host **Inspiron** na arquitetura Kryonix.

## Função
O Inspiron atua como a **Workstation principal (Client)** do projeto. É a interface do usuário primária com a inteligência do sistema, acessando o Glacier remotamente.

## Onde vive o código real
> [!WARNING]
> O arquivo final de hardware, disco, e a amarração do sistema operacional (`hosts/inspiron/default.nix` que injeta seu usuário) vivem **exclusivamente no repositório Downstream (`/etc/kryonixos`)**.
> O repositório Upstream (`/etc/kryonix`) possui a pasta `hosts/inspiron/` apenas como documentação de referência de hardware base, para ser consumida e injetada no superflake Downstream.

## Serviços e Features Esperadas (Profile)
- **Profile:** Utiliza `profiles/laptop.nix` e `profiles/workstation-gamer.nix`
- **Ambiente Gráfico:** Caelestia (Hyprland rice) via Wayland.
- **Integração IA:** Acessa o Kryonix Brain no Glacier como **client** puro. Usa um túnel SSH (gerenciado pelo módulo home-manager de brain-tunnel).
- **VRAM/GPU:** Configurado com balanceamento térmico (Intel CPU/GPU genérica para laptops).

## O que está implementado vs Roadmap
- Ambiente gráfico Caelestia e wrappers: Implementado.
- Túnel SSH p/ Brain no Glacier: Implementado.
- Configuração de áudio isolado Kora: Roadmap/Legado.
