/**
 * sample.ts — comprehensive TypeScript syntax fixture for parser testing.
 * Covers: interfaces, type aliases, generics, enums, decorators, mapped types,
 * conditional types, template literal types, utility types, namespaces,
 * declaration merging, overloads, abstract classes, satisfies operator.
 */

// -------------------------------------------------------------------------- //
// Primitive & literal types
// -------------------------------------------------------------------------- //

type Uuid = string & { readonly _brand: 'Uuid' };
type Positive = number & { readonly _brand: 'Positive' };
type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
type StatusCode = 200 | 201 | 400 | 401 | 403 | 404 | 500;

// -------------------------------------------------------------------------- //
// Enums
// -------------------------------------------------------------------------- //

enum Direction {
  North = 'NORTH',
  South = 'SOUTH',
  East = 'EAST',
  West = 'WEST',
}

const enum LogLevel {
  Debug = 0,
  Info = 1,
  Warn = 2,
  Error = 3,
}

// -------------------------------------------------------------------------- //
// Interfaces & declaration merging
// -------------------------------------------------------------------------- //

interface Entity {
  readonly id: Uuid;
  createdAt: Date;
  updatedAt: Date;
}

interface Auditable extends Entity {
  createdBy: string;
  updatedBy: string;
}

// Declaration merging
interface Window {
  appVersion: string;
}

// -------------------------------------------------------------------------- //
// Generic interfaces & type aliases
// -------------------------------------------------------------------------- //

interface Repository<T extends Entity> {
  findById(id: Uuid): Promise<T | null>;
  findAll(filter?: Partial<T>): Promise<T[]>;
  save(entity: T): Promise<T>;
  delete(id: Uuid): Promise<boolean>;
}

type Result<T, E extends Error = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

type AsyncResult<T, E extends Error = Error> = Promise<Result<T, E>>;

// -------------------------------------------------------------------------- //
// Mapped & conditional types
// -------------------------------------------------------------------------- //

type Nullable<T> = { [K in keyof T]: T[K] | null };
type ReadonlyDeep<T> = { readonly [K in keyof T]: ReadonlyDeep<T[K]> };
type PickByValue<T, V> = { [K in keyof T as T[K] extends V ? K : never]: T[K] };

type Flatten<T> = T extends Array<infer U> ? U : T;
type Awaited2<T> = T extends Promise<infer U> ? Awaited2<U> : T;
type NonNullableKeys<T> = { [K in keyof T]-?: NonNullable<T[K]> };

// -------------------------------------------------------------------------- //
// Template literal types
// -------------------------------------------------------------------------- //

type EventName<T extends string> = `on${Capitalize<T>}`;
type CssVar<T extends string> = `--${T}`;
type ApiPath<T extends string> = `/api/v1/${T}`;

type UserEvents = EventName<'click' | 'focus' | 'blur'>;
// => 'onClick' | 'onFocus' | 'onBlur'

// -------------------------------------------------------------------------- //
// Abstract classes
// -------------------------------------------------------------------------- //

abstract class BaseService<T extends Entity> {
  constructor(protected readonly repo: Repository<T>) {}

  abstract validate(entity: T): boolean;

  async getOrThrow(id: Uuid): Promise<T> {
    const entity = await this.repo.findById(id);
    if (entity === null) throw new NotFoundError('Entity', id);
    return entity;
  }
}

// -------------------------------------------------------------------------- //
// Classes with access modifiers
// -------------------------------------------------------------------------- //

class UserService extends BaseService<User> {
  validate(user: User): boolean {
    return user.email.includes('@') && user.name.length > 0;
  }

  async createUser(name: string, email: string): Promise<Result<User>> {
    try {
      const user: User = {
        id: generateId(),
        name,
        email,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      if (!this.validate(user)) {
        return { ok: false, error: new ValidationError('Invalid user data') };
      }
      const saved = await this.repo.save(user);
      return { ok: true, value: saved };
    } catch (err) {
      return { ok: false, error: err as Error };
    }
  }
}

// -------------------------------------------------------------------------- //
// Domain types
// -------------------------------------------------------------------------- //

interface User extends Entity {
  name: string;
  email: string;
  role?: 'admin' | 'member' | 'guest';
}

// -------------------------------------------------------------------------- //
// Custom errors
// -------------------------------------------------------------------------- //

class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: StatusCode = 500,
  ) {
    super(message);
    this.name = this.constructor.name;
  }
}

class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super(`${resource} with id="${id}" not found`, 'NOT_FOUND', 404);
  }
}

class ValidationError extends AppError {
  constructor(detail: string) {
    super(`Validation failed: ${detail}`, 'VALIDATION_ERROR', 400);
  }
}

// -------------------------------------------------------------------------- //
// Function overloads
// -------------------------------------------------------------------------- //

function parse(input: string): number;
function parse(input: number): string;
function parse(input: string | number): string | number {
  if (typeof input === 'string') return parseInt(input, 10);
  return input.toString();
}

// -------------------------------------------------------------------------- //
// Generics with constraints
// -------------------------------------------------------------------------- //

function pick<T, K extends keyof T>(obj: T, keys: K[]): Pick<T, K> {
  return keys.reduce((acc, key) => ({ ...acc, [key]: obj[key] }), {} as Pick<T, K>);
}

function groupBy<T, K extends string>(
  items: T[],
  keyFn: (item: T) => K,
): Record<K, T[]> {
  return items.reduce(
    (acc, item) => {
      const key = keyFn(item);
      (acc[key] ??= []).push(item);
      return acc;
    },
    {} as Record<K, T[]>,
  );
}

// -------------------------------------------------------------------------- //
// Decorators (experimental)
// -------------------------------------------------------------------------- //

function log(target: unknown, key: string, descriptor: PropertyDescriptor) {
  const original = descriptor.value as (...args: unknown[]) => unknown;
  descriptor.value = function (...args: unknown[]) {
    console.log(`[${key}] called with`, args);
    return original.apply(this, args);
  };
  return descriptor;
}

// -------------------------------------------------------------------------- //
// Namespace
// -------------------------------------------------------------------------- //

namespace Validation {
  export interface Rule<T> {
    name: string;
    validate(value: T): boolean;
    message(value: T): string;
  }

  export class MinLength implements Rule<string> {
    name = 'minLength';
    constructor(private readonly min: number) {}
    validate(value: string): boolean { return value.length >= this.min; }
    message(value: string): string {
      return `Expected length >= ${this.min}, got ${value.length}`;
    }
  }
}

// -------------------------------------------------------------------------- //
// Satisfies operator
// -------------------------------------------------------------------------- //

const config = {
  host: 'localhost',
  port: 8080,
  debug: false,
} satisfies Record<string, string | number | boolean>;

// -------------------------------------------------------------------------- //
// Utility helpers
// -------------------------------------------------------------------------- //

function generateId(): Uuid {
  return crypto.randomUUID() as Uuid;
}

function assertNever(value: never): never {
  throw new Error(`Unexpected value: ${JSON.stringify(value)}`);
}

function isResult<T>(value: unknown): value is Result<T> {
  return (
    typeof value === 'object' &&
    value !== null &&
    'ok' in value &&
    typeof (value as { ok: unknown }).ok === 'boolean'
  );
}

// -------------------------------------------------------------------------- //
// Exports
// -------------------------------------------------------------------------- //

export {
  Direction,
  LogLevel,
  UserService,
  AppError,
  NotFoundError,
  ValidationError,
  Validation,
  pick,
  groupBy,
  parse,
  generateId,
  assertNever,
  isResult,
};

export type {
  Uuid,
  HttpMethod,
  StatusCode,
  Entity,
  Auditable,
  Repository,
  Result,
  AsyncResult,
  Nullable,
  ReadonlyDeep,
  User,
};
