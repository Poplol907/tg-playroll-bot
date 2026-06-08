"""Domain-level exceptions raised by services.

Services NEVER raise `HTTPException` — that belongs to the HTTP layer.
A central FastAPI exception handler translates these to HTTP responses,
so business logic stays framework-agnostic and unit-testable.

This is the keystone of the Clean Architecture boundary in the backend:

    router (HTTP) → service (domain) → repository / SQLAlchemy

The router catches no exceptions — it just translates query params and
returns the model. The service knows about business rules. Domain
exceptions are the language they share.
"""

from typing import Any


class DomainError(Exception):
    """Base for all domain errors. Maps to 500 by default."""

    status_code: int = 500
    code: str = "internal_error"

    def __init__(self, message: str, *, details: Any | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.details = details


class NotFound(DomainError):
    """Resource does not exist or is invisible to the caller."""

    status_code = 404
    code = "not_found"


class Forbidden(DomainError):
    """Caller is authenticated but lacks permission."""

    status_code = 403
    code = "forbidden"


class ValidationError(DomainError):
    """Input data is structurally valid but semantically wrong.

    Examples: status value not in allowed set, attempting an operation
    in a state where it's meaningless (already-completed makeup, empty
    slot list, etc.).
    """

    status_code = 422
    code = "validation_error"


class Conflict(DomainError):
    """Operation cannot proceed because of state conflicts.

    Used for: time-slot already taken, duplicate resources, attempts to
    re-create something that already exists.
    """

    status_code = 409
    code = "conflict"


class BusinessRuleViolation(DomainError):
    """Generic 400 for business rules that don't fit other categories."""

    status_code = 400
    code = "business_rule_violation"
