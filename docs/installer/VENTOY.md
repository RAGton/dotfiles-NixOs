# Suporte a Ventoy

**Status Inicial:** ROADMAP / PENDING

## Objetivo
Garantir que a ISO do Kryonix inicialize e funcione perfeitamente quando carregada através da ferramenta Ventoy (boot multiboot USB), suportando tanto UEFI quanto BIOS (CSM) se possível.

## Requisitos e Critérios de Aceite
- **Boot Físico via Ventoy:** A imagem ISO deve ser capaz de ser selecionada e iniciar sem kernel panic no ambiente Ventoy.
- **Detecção do Root Filesystem:** A etapa `stage-1` (initrd) deve ser capaz de montar a raiz do squashfs com base na label (`root=LABEL=KRYONIX`), ou através de configurações como `copytoram` ou block devices lógicos exportados pelo Ventoy (`/dev/mapper/ventoy...` ou loopback).
- **Relatório de Boot:** Screenshots ou logs provando o boot físico via Ventoy devem ser fornecidos antes da declaração de suporte oficial.

## Aspectos Técnicos e Riscos Conhecidos
- **Isohybrid Format:** O NixOS geralmente provê um sistema de disco `isohybrid` com partições EFI, mas a forma como o Ventoy engana o firmware UEFI pode exigir atenção aos parâmetros de boot `makeEfiBootable` e `makeUsbBootable`.
- **Labels:** O Ventoy utiliza os nomes dos labels para localizar e expor as estruturas internas, tornando imperativo o respeito ao volume ID.
- **Secure Boot:** O uso do Ventoy com Secure Boot pode quebrar a cadeia de confiança; deve-se documentar a necessidade de desativá-lo, ou explorar a compatibilidade das chaves enrolladas.
