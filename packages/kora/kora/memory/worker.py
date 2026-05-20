import time
import logging
import asyncio
from typing import Optional
from .queue import MemoryQueue
from .obsidian import ObsidianWriter
from .indexer import MemoryIndexer

logger = logging.getLogger(__name__)

class MemoryWorker:
    def __init__(self, queue_path: Optional[str] = None, vault_dir: Optional[str] = None):
        self.queue = MemoryQueue(queue_path)
        self.writer = ObsidianWriter(vault_dir)
        self.indexer = MemoryIndexer(vault_dir=vault_dir) if vault_dir else MemoryIndexer()

    async def run_once(self):
        """Process all pending items in the queue and then index the vault."""
        candidates = self.queue.pop_all()
        processed_count = 0

        if candidates:
            for candidate in candidates:
                if not getattr(candidate, "verified", False):
                    logger.warning("Skipping unverified memory candidate: %s", candidate.title)
                    continue
                try:
                    self.writer.write(candidate)
                    processed_count += 1
                except Exception as e:
                    logger.error("Worker failed to process candidate %s: %s", candidate.title, e)

        if processed_count > 0:
            logger.info("Worker processed %d new items. Starting incremental indexing...", processed_count)

        # Always run indexer to ensure consistency, even if no new items were popped
        # (e.g. manual edits in Vault)
        try:
            indexed_count = await self.indexer.index_all()
            if indexed_count > 0:
                logger.info("Indexer successfully processed %d items.", indexed_count)
        except Exception as e:
            logger.error("Worker failed to run indexer: %s", e)

        return processed_count

    def run_loop(self, interval: int = 60):
        """Run the worker in a loop."""
        logger.info("Memory worker started (interval: %ds)", interval)
        try:
            while True:
                count = self.run_once()
                if count > 0:
                    logger.info("Worker processed %d items", count)
                time.sleep(interval)
        except KeyboardInterrupt:
            logger.info("Memory worker stopped")


def main():
    import os
    import sys

    # Configure logging to stdout for systemd
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        stream=sys.stdout
    )

    # Use environment variables or defaults
    queue_path = os.getenv("KORA_MEMORY_QUEUE")
    vault_dir = os.getenv("KORA_VAULT_DIR")

    worker = MemoryWorker(queue_path=queue_path, vault_dir=vault_dir)

    # Check if we should run once or loop
    if "--once" in sys.argv:
        processed = asyncio.run(worker.run_once())
        print(f"Processed {processed} items.")
    else:
        # Loop mode
        asyncio.run(worker.run_once())


if __name__ == "__main__":
    main()
