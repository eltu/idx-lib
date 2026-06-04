<?php
/**
 * sample.php — comprehensive PHP syntax fixture for parser testing.
 * Covers: namespaces, interfaces, abstract classes, traits, enums, generics
 * via docblocks, first-class callables, fibers, match expressions, named args,
 * readonly properties, union/intersection types, nullsafe operator.
 */

declare(strict_types=1);

namespace Sample;

use DateTimeImmutable;
use Generator;
use InvalidArgumentException;
use RuntimeException;
use Throwable;

// -------------------------------------------------------------------------- //
// Constants
// -------------------------------------------------------------------------- //

const MAX_RETRIES = 3;
const DEFAULT_TIMEOUT = 30.0;

// -------------------------------------------------------------------------- //
// Enums (PHP 8.1+)
// -------------------------------------------------------------------------- //

enum Status: string
{
    case Pending = 'pending';
    case Running = 'running';
    case Done    = 'done';
    case Failed  = 'failed';

    public function isTerminal(): bool
    {
        return match ($this) {
            self::Done, self::Failed => true,
            default                 => false,
        };
    }

    public function label(): string
    {
        return match ($this) {
            self::Pending => 'Waiting to start',
            self::Running => 'In progress',
            self::Done    => 'Completed',
            self::Failed  => 'Failed',
        };
    }
}

// -------------------------------------------------------------------------- //
// Interfaces
// -------------------------------------------------------------------------- //

/** @template T */
interface Repository
{
    /** @return T|null */
    public function findById(string $id): mixed;

    /** @return list<T> */
    public function list(): array;

    /** @param T $entity @return T */
    public function save(mixed $entity): mixed;

    public function delete(string $id): bool;
}

interface Validatable
{
    /** @return list<string> */
    public function validationErrors(): array;

    public function isValid(): bool;
}

// -------------------------------------------------------------------------- //
// Traits
// -------------------------------------------------------------------------- //

trait HasTimestamps
{
    private DateTimeImmutable $createdAt;
    private DateTimeImmutable $updatedAt;

    public function initTimestamps(): void
    {
        $now = new DateTimeImmutable();
        $this->createdAt = $now;
        $this->updatedAt = $now;
    }

    public function getCreatedAt(): DateTimeImmutable
    {
        return $this->createdAt;
    }

    public function touch(): void
    {
        $this->updatedAt = new DateTimeImmutable();
    }
}

trait Serializable
{
    public function toArray(): array
    {
        return get_object_vars($this);
    }

    public function toJson(): string
    {
        return json_encode($this->toArray(), JSON_THROW_ON_ERROR);
    }
}

// -------------------------------------------------------------------------- //
// Abstract class
// -------------------------------------------------------------------------- //

abstract class BaseEntity
{
    use HasTimestamps;
    use Serializable;

    public function __construct(public readonly string $id)
    {
        $this->initTimestamps();
    }

    abstract public function validate(): void;
}

// -------------------------------------------------------------------------- //
// Readonly class (PHP 8.2+) / readonly properties
// -------------------------------------------------------------------------- //

class Point
{
    public function __construct(
        public readonly float $x,
        public readonly float $y,
    ) {}

    public static function origin(): self
    {
        return new self(0.0, 0.0);
    }

    public function distanceTo(self $other): float
    {
        return sqrt(($this->x - $other->x) ** 2 + ($this->y - $other->y) ** 2);
    }

    public function __toString(): string
    {
        return "({$this->x}, {$this->y})";
    }
}

// -------------------------------------------------------------------------- //
// Domain entity
// -------------------------------------------------------------------------- //

class User extends BaseEntity implements Validatable
{
    public function __construct(
        string $id,
        public string $name,
        public string $email,
        public string $role = 'member',
    ) {
        parent::__construct($id);
    }

    public function validate(): void
    {
        if (trim($this->name) === '') {
            throw new InvalidArgumentException("name must not be blank, got: {$this->name}");
        }
        if (!str_contains($this->email, '@')) {
            throw new InvalidArgumentException("email '{$this->email}' is invalid");
        }
    }

    public function validationErrors(): array
    {
        $errors = [];
        if (trim($this->name) === '') $errors[] = 'name is required';
        if (!str_contains($this->email, '@')) $errors[] = "email '{$this->email}' is invalid";
        return $errors;
    }

    public function isValid(): bool
    {
        return $this->validationErrors() === [];
    }
}

// -------------------------------------------------------------------------- //
// Generic-ish in-memory repository
// -------------------------------------------------------------------------- //

/** @template T of BaseEntity */
class MemoryRepository implements Repository
{
    /** @var array<string, T> */
    private array $store = [];

    public function findById(string $id): mixed
    {
        return $this->store[$id] ?? null;
    }

    public function list(): array
    {
        return array_values($this->store);
    }

    public function save(mixed $entity): mixed
    {
        $this->store[$entity->id] = $entity;
        return $entity;
    }

    public function delete(string $id): bool
    {
        if (!isset($this->store[$id])) return false;
        unset($this->store[$id]);
        return true;
    }

    /** @param callable(T): bool $predicate @return list<T> */
    public function findWhere(callable $predicate): array
    {
        return array_values(array_filter($this->store, $predicate));
    }
}

// -------------------------------------------------------------------------- //
// Exception hierarchy
// -------------------------------------------------------------------------- //

class AppException extends RuntimeException
{
    public function __construct(
        string $message,
        public readonly string $code,
        ?Throwable $previous = null,
    ) {
        parent::__construct($message, 0, $previous);
    }
}

class NotFoundException extends AppException
{
    public function __construct(string $resource, string $id)
    {
        parent::__construct("{$resource} with id='{$id}' not found", 'NOT_FOUND');
    }
}

class ValidationException extends AppException
{
    public function __construct(/** @param list<string> */ public readonly array $errors)
    {
        parent::__construct('Validation failed: ' . implode(', ', $errors), 'VALIDATION_ERROR');
    }
}

// -------------------------------------------------------------------------- //
// First-class callables & match
// -------------------------------------------------------------------------- //

function pipeline(mixed $value, callable ...$fns): mixed
{
    return array_reduce($fns, fn ($carry, $fn) => $fn($carry), $value);
}

function classify(mixed $value): string
{
    return match (true) {
        is_null($value)              => 'null',
        is_bool($value)              => 'boolean: ' . ($value ? 'true' : 'false'),
        is_int($value) && $value < 0 => 'negative int',
        is_int($value)               => 'non-negative int',
        is_string($value)            => 'string of length ' . strlen($value),
        is_array($value)             => 'array of ' . count($value),
        is_object($value)            => 'object ' . get_class($value),
        default                      => 'unknown',
    };
}

// -------------------------------------------------------------------------- //
// Generators
// -------------------------------------------------------------------------- //

function fibonacci(): Generator
{
    [$a, $b] = [0, 1];
    while (true) {
        yield $a;
        [$a, $b] = [$b, $a + $b];
    }
}

function take(int $n, Generator $gen): array
{
    $result = [];
    for ($i = 0; $i < $n; $i++) {
        $result[] = $gen->current();
        $gen->next();
    }
    return $result;
}

// -------------------------------------------------------------------------- //
// Fibers (PHP 8.1+)
// -------------------------------------------------------------------------- //

function makeAsyncTask(string $name): \Fiber
{
    return new \Fiber(function () use ($name): string {
        echo "Starting {$name}\n";
        $result = \Fiber::suspend("midpoint of {$name}");
        echo "Resumed {$name} with: {$result}\n";
        return "done: {$name}";
    });
}

// -------------------------------------------------------------------------- //
// Nullsafe operator & named arguments
// -------------------------------------------------------------------------- //

function formatUser(?User $user): string
{
    $name = $user?->name ?? 'Guest';
    $upper = mb_strtoupper(string: $name, encoding: 'UTF-8');
    return "Hello, {$upper}!";
}

// -------------------------------------------------------------------------- //
// Union & intersection types
// -------------------------------------------------------------------------- //

function acceptNumber(int|float $n): float
{
    return (float) $n;
}

interface Countable2 { public function count(): int; }
interface Iterable2  { public function toArray(): array; }

function processCollection(Countable2&Iterable2 $col): void
{
    echo $col->count(), "\n";
}

// -------------------------------------------------------------------------- //
// Entry point
// -------------------------------------------------------------------------- //

$user = new User(id: 'u1', name: 'Alice', email: 'alice@example.com');
$user->validate();

$repo = new MemoryRepository();
$repo->save($user);
echo $repo->findById('u1')?->name, "\n";

$fibs = take(10, fibonacci());
echo implode(', ', $fibs), "\n";

$p1 = Point::origin();
$p2 = new Point(3.0, 4.0);
echo "distance: ", $p2->distanceTo($p1), "\n";

$fiber = makeAsyncTask('task-1');
$mid = $fiber->start();
$fiber->resume('hello');
