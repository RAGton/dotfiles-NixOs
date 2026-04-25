# ADR-0004: Winbox via XWayland Isolado

Data: 2026-04-25

## Estado

Aceita.

## Contexto

O desktop principal do Kryonix roda em Hyprland/Wayland. O Winbox e uma
aplicacao GUI externa que pode falhar quando tenta usar backend grafico Wayland
nativo.

## Decisao

O modulo `programs.winbox` instala o pacote por um wrapper que define:

- `QT_QPA_PLATFORM=xcb`
- `GDK_BACKEND=x11`

O ajuste e isolado no executavel `WinBox`/`winbox` e depende do XWayland ja
habilitado no stack Hyprland.

## Consequencias

- O Winbox usa o caminho mais compativel no desktop Wayland.
- A sessao e os demais apps continuam usando Wayland normalmente.
- A descoberta MNDP segue controlada por `programs.winbox.openFirewall`.
