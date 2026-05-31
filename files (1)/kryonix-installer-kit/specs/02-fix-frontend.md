# Spec 02 — Fix: Frontend Vite

Implementar após diagnóstico apontar o erro no frontend.

## Problemas comuns
- **package-lock.json desatualizado**: npm ci vs npm install.
- **TypeScript errors**: imports, types, JSX syntax.
- **Vite config**: publicPath errado, build output não em dist/.
- **Assets faltando**: CSS, imagens não copiadas.

## Implementação
1. Diagnosticar exato (ver Spec 00).
2. Ler vite.config.ts e src/main.tsx (capture atual).
3. Corrigir — npm run build depois cada mudança.
4. Validar build: `ls -lah frontend/dist/` (index.html, assets/).

## Validação
```bash
npm run build && echo "✓ Builda"
ls -lah dist/index.html && echo "✓ HTML gerado"
# Depois em VM com backend rodando: browser em http://localhost:8080
```
