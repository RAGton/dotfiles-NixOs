# Technical Constraints

- **NixOS:** Alterações no sistema devem ser declarativas.
- **Rollback:** Nunca quebrar a capacidade de boot ou acesso SSH.
- **Segurança:** Secrets não devem ser expostos em logs ou no repo.
- **Grounding:** Agentes não devem inventar estados não documentados.
- **Vibecode:** Permitido para acelerar, mas proibido para merge sem evidência.
