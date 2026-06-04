"""
sample.py — comprehensive Python syntax fixture for parser testing.
Covers: imports, constants, type hints, classes, inheritance, decorators,
generators, context managers, async/await, error handling, comprehensions,
pattern matching.
"""

from __future__ import annotations

import asyncio
import functools
import os
from abc import ABC, abstractmethod
from collections.abc import Generator, Iterator
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import ClassVar, Generic, Protocol, TypeVar

# --------------------------------------------------------------------------- #
# Constants
# --------------------------------------------------------------------------- #

MAX_RETRIES: int = 3
DEFAULT_TIMEOUT: float = 30.0
GREETING: str = "hello"

T = TypeVar("T")

# --------------------------------------------------------------------------- #
# Protocols & Abstract Base Classes
# --------------------------------------------------------------------------- #


class Serializable(Protocol):
    def to_dict(self) -> dict[str, object]: ...


class Repository(ABC, Generic[T]):
    @abstractmethod
    def find_by_id(self, entity_id: str) -> T | None: ...

    @abstractmethod
    def save(self, entity: T) -> None: ...

    @abstractmethod
    def delete(self, entity_id: str) -> bool: ...


# --------------------------------------------------------------------------- #
# Dataclasses
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class Point:
    x: float
    y: float

    def distance_to(self, other: Point) -> float:
        return ((self.x - other.x) ** 2 + (self.y - other.y) ** 2) ** 0.5


@dataclass
class Config:
    host: str = "localhost"
    port: int = 8080
    tags: list[str] = field(default_factory=list)
    metadata: dict[str, str] = field(default_factory=dict)

    def base_url(self) -> str:
        return f"http://{self.host}:{self.port}"


# --------------------------------------------------------------------------- #
# Enumerations
# --------------------------------------------------------------------------- #


class Status(Enum):
    PENDING = auto()
    RUNNING = auto()
    DONE = auto()
    FAILED = auto()

    def is_terminal(self) -> bool:
        return self in (Status.DONE, Status.FAILED)


# --------------------------------------------------------------------------- #
# Decorators
# --------------------------------------------------------------------------- #


def retry(max_attempts: int = MAX_RETRIES):
    def decorator(fn):
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            last_exc: Exception | None = None
            for attempt in range(max_attempts):
                try:
                    return fn(*args, **kwargs)
                except Exception as exc:
                    last_exc = exc
            raise RuntimeError(
                f"{fn.__name__} failed after {max_attempts} attempts"
            ) from last_exc
        return wrapper
    return decorator


# --------------------------------------------------------------------------- #
# Classes with inheritance
# --------------------------------------------------------------------------- #


class Animal:
    species_count: ClassVar[int] = 0

    def __init__(self, name: str, weight_kg: float) -> None:
        self.name = name
        self.weight_kg = weight_kg
        Animal.species_count += 1

    def __repr__(self) -> str:
        return f"{type(self).__name__}(name={self.name!r})"

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Animal):
            return NotImplemented
        return self.name == other.name

    def speak(self) -> str:
        raise NotImplementedError

    @property
    def weight_lbs(self) -> float:
        return self.weight_kg * 2.205

    @classmethod
    def from_dict(cls, data: dict[str, object]) -> "Animal":
        return cls(name=str(data["name"]), weight_kg=float(data["weight_kg"]))  # type: ignore[arg-type]


class Dog(Animal):
    def __init__(self, name: str, weight_kg: float, breed: str) -> None:
        super().__init__(name, weight_kg)
        self.breed = breed

    def speak(self) -> str:
        return "woof"

    def fetch(self, item: str) -> str:
        return f"{self.name} fetched the {item}!"


# --------------------------------------------------------------------------- #
# Generators & comprehensions
# --------------------------------------------------------------------------- #


def fibonacci() -> Generator[int, None, None]:
    a, b = 0, 1
    while True:
        yield a
        a, b = b, a + b


def take(n: int, it: Iterator[T]) -> list[T]:
    return [next(it) for _ in range(n)]


def comprehension_examples() -> None:
    squares = [x**2 for x in range(10) if x % 2 == 0]
    word_lengths = {word: len(word) for word in ["alpha", "beta", "gamma"]}
    unique_chars = {ch for ch in "abracadabra"}
    lazy_cubes = (x**3 for x in range(100))
    _ = squares, word_lengths, unique_chars, lazy_cubes


# --------------------------------------------------------------------------- #
# Context managers
# --------------------------------------------------------------------------- #


class ManagedResource:
    def __enter__(self) -> "ManagedResource":
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> bool:
        return False  # do not suppress exceptions


# --------------------------------------------------------------------------- #
# Error handling
# --------------------------------------------------------------------------- #


class AppError(Exception):
    def __init__(self, message: str, code: int) -> None:
        super().__init__(message)
        self.code = code


class NotFoundError(AppError):
    def __init__(self, resource: str, resource_id: str) -> None:
        super().__init__(f"{resource} with id={resource_id!r} not found", code=404)
        self.resource_id = resource_id


@retry(max_attempts=3)
def load_config(path: str) -> Config:
    if not os.path.exists(path):
        raise NotFoundError("Config", path)
    return Config()


# --------------------------------------------------------------------------- #
# Async / await
# --------------------------------------------------------------------------- #


async def fetch_data(url: str, timeout: float = DEFAULT_TIMEOUT) -> bytes:
    await asyncio.sleep(0)
    return b"data"


async def gather_results(urls: list[str]) -> list[bytes]:
    return await asyncio.gather(*[fetch_data(url) for url in urls])


# --------------------------------------------------------------------------- #
# Pattern matching (Python 3.10+)
# --------------------------------------------------------------------------- #


def describe_status(status: Status) -> str:
    match status:
        case Status.PENDING:
            return "waiting to start"
        case Status.RUNNING:
            return "in progress"
        case Status.DONE:
            return "completed successfully"
        case Status.FAILED:
            return "ended with error"
        case _:
            return "unknown"


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #

if __name__ == "__main__":
    dog = Dog("Rex", 30.0, "Labrador")
    print(dog.speak())
    fibs = take(10, fibonacci())
    print(fibs)
    cfg = Config(host="example.com", port=443)
    print(cfg.base_url())
