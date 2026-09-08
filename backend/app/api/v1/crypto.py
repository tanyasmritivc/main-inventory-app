import asyncio
import re
import secrets

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

KEY_PATTERN = re.compile(r"findez_(live|test)_sk_[A-Za-z0-9_-]{32}\Z")
# Argon2id; limit concurrent memory-intensive operations per worker.
HASHER = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=1)
HASH_SLOTS = asyncio.Semaphore(4)


async def create_secret(environment: str) -> tuple[str, str, str]:
    if environment not in {"live", "test"}:
        raise ValueError("Invalid API-key environment")
    raw = f"findez_{environment}_sk_{secrets.token_urlsafe(24)}"
    async with HASH_SLOTS:
        hashed = await asyncio.to_thread(HASHER.hash, raw)
    return raw, raw[:20], hashed


async def verify_secret(raw: str, hashed: str) -> bool:
    def verify():
        try:
            # The Argon2 library verifies the derived hash in constant time.
            return HASHER.verify(hashed, raw)
        except (VerificationError, InvalidHashError):
            return False
    async with HASH_SLOTS:
        return await asyncio.to_thread(verify)
