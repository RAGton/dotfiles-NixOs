import os
import logging
import json
import re
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional
from .models import MemoryCandidate, MemoryType

logger = logging.getLogger(__name__)

class ObsidianWriter:
    def __init__(self, vault_dir: Optional[str] = None):
        if vault_dir:
            self.vault_dir = Path(vault_dir)
        else:
            # Canonical search for vault path
            # 1. Env LIGHTRAG_VAULT_DIR (Primary)
            # 2. Env KORA_VAULT_DIR
            # 3. Fallback to common declarative path
            v_dir = os.getenv("LIGHTRAG_VAULT_DIR") or os.getenv("KORA_VAULT_DIR") or "/var/lib/kryonix/vault"
            self.vault_dir = Path(v_dir)

    def _ensure_dir(self, path: Path):
        """Ensure a directory exists with proper permissions."""
        if not path.exists():
            try:
                # Create parents as well
                path.mkdir(parents=True, exist_ok=True)
                # Try to set permissions to 0770 if possible
                # (May fail if we are not root or owner)
                try:
                    path.chmod(0o770)
                except:
                    pass
            except Exception as e:
                logger.error("Could not create directory %s: %s", path, e)

    def _get_category_dir(self, memory_type: MemoryType) -> Path:
        """Map memory type to vault directory structure."""
        mapping = {
            MemoryType.IDEA: "Kora/Ideas",
            MemoryType.DECISION: "Kora/Decisions",
            MemoryType.PREFERENCE: "Kora/User",
            MemoryType.TASK: "Kora/Inbox",
            MemoryType.OPERATION: "Kora/Operations",
            MemoryType.SESSION_SUMMARY: "Kora/Sessions",
            MemoryType.USER_PROFILE: "Kora/User",
            MemoryType.COMMAND_AUDIT: "Kora/Audit",
        }
        rel_path = mapping.get(memory_type, "Kora/Inbox")
        full_path = self.vault_dir / rel_path
        full_path.mkdir(parents=True, exist_ok=True)
        return full_path

    def _slugify(self, text: str) -> str:
        import re
        text = text.lower()
        text = re.sub(r'[^\w\s-]', '', text)
        return re.sub(r'[-\s]+', '-', text).strip('-')

    def write(self, candidate: MemoryCandidate) -> str:
        """Write a memory candidate as a Markdown note in Obsidian."""
        category_dir = self._get_category_dir(candidate.type)

        # Create filename: date-slug.md
        date_str = candidate.created_at.strftime("%Y-%m-%d")
        slug = self._slugify(candidate.title)
        filename = f"{date_str}-{slug}.md"
        file_path = category_dir / filename

        # Prepare YAML frontmatter
        tags_str = "\n".join([f"  - {tag}" for tag in candidate.tags])
        if tags_str:
            tags_str = f"tags:\n{tags_str}"

        frontmatter = f"""---
type: {candidate.type.value}
source: {candidate.source}
created: {candidate.created_at.isoformat()}
user: {candidate.user}
confidence: {candidate.confidence}
verified: {str(getattr(candidate, 'verified', False)).lower()}
{tags_str}
status: active
---

"""
        content = f"""# {candidate.title}

## Resumo
{candidate.summary}

## Conteúdo
{candidate.content}

## Origem
{candidate.source}
"""

        try:
            with open(file_path, "w") as f:
                f.write(frontmatter + content)
            logger.info("Memory saved to Obsidian: %s", file_path)
            return str(file_path)
        except Exception as e:
            logger.error("Failed to write to Obsidian: %s", e)
            raise
