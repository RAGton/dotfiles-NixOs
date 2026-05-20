from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field
from datetime import datetime

class MemoryType(str, Enum):
    IDEA = "idea"
    DECISION = "decision"
    PREFERENCE = "preference"
    TASK = "task"
    OPERATION = "operation"
    SESSION_SUMMARY = "session_summary"
    USER_PROFILE = "user_profile"
    COMMAND_AUDIT = "command_audit"

class MemoryCandidate(BaseModel):
    type: MemoryType
    title: str
    summary: str
    content: str
    tags: List[str] = Field(default_factory=list)
    source: str = "kora-chat"
    user: str = "unknown"
    confidence: float = 0.0
    sensitivity: str = "low" # low, medium, high
    should_save: bool = False
    requires_confirmation: bool = False
    verified: bool = False
    created_at: datetime = Field(default_factory=datetime.now)

class MemoryItem(BaseModel):
    id: str
    type: MemoryType
    title: str
    content: str
    metadata: Dict[str, Any]
    created_at: datetime
