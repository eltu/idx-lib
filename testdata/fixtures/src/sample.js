/**
 * sample.js — comprehensive JavaScript syntax fixture for parser testing.
 * Covers: variables, functions, classes, prototypes, async/await, generators,
 * destructuring, spread, modules (ESM style comments), Proxy, Symbol, WeakMap,
 * tagged templates, closures, error handling, iterators.
 */

'use strict';

// -------------------------------------------------------------------------- //
// Constants & primitive types
// -------------------------------------------------------------------------- //

const MAX_SIZE = 100;
const PI = Math.PI;
const GREETING = 'hello';
const NULL_VAL = null;
const UNDEF_VAL = undefined;
const BIG = 9007199254740991n; // BigInt

// -------------------------------------------------------------------------- //
// Variables & destructuring
// -------------------------------------------------------------------------- //

let counter = 0;

const [first, second, ...rest] = [1, 2, 3, 4, 5];
const { name: personName, age = 18, address: { city } = {} } = {
  name: 'Alice',
  address: { city: 'Berlin' },
};

// -------------------------------------------------------------------------- //
// Functions — declarations, expressions, arrows
// -------------------------------------------------------------------------- //

function add(a, b) {
  return a + b;
}

const multiply = function namedExpr(x, y) {
  return x * y;
};

const square = (n) => n * n;

const clamp = (value, min = 0, max = MAX_SIZE) =>
  Math.min(Math.max(value, min), max);

function sum(...nums) {
  return nums.reduce((acc, n) => acc + n, 0);
}

// -------------------------------------------------------------------------- //
// Closures & higher-order functions
// -------------------------------------------------------------------------- //

function makeCounter(start = 0) {
  let count = start;
  return {
    increment() { count += 1; },
    decrement() { count -= 1; },
    value() { return count; },
  };
}

const pipe = (...fns) => (x) => fns.reduce((v, f) => f(v), x);

// -------------------------------------------------------------------------- //
// Classes & inheritance
// -------------------------------------------------------------------------- //

class EventEmitter {
  #listeners = new Map();

  on(event, handler) {
    if (!this.#listeners.has(event)) this.#listeners.set(event, []);
    this.#listeners.get(event).push(handler);
    return this;
  }

  emit(event, ...args) {
    (this.#listeners.get(event) ?? []).forEach((h) => h(...args));
  }

  off(event, handler) {
    const handlers = this.#listeners.get(event) ?? [];
    this.#listeners.set(event, handlers.filter((h) => h !== handler));
  }
}

class Animal extends EventEmitter {
  static #count = 0;

  constructor(name, sound) {
    super();
    this.name = name;
    this.sound = sound;
    Animal.#count += 1;
  }

  speak() {
    const msg = `${this.name} says ${this.sound}`;
    this.emit('speak', msg);
    return msg;
  }

  static totalCreated() {
    return Animal.#count;
  }

  get label() {
    return `[Animal: ${this.name}]`;
  }

  set label(value) {
    this.name = value.replace(/^\[Animal: /, '').replace(/\]$/, '');
  }

  [Symbol.toPrimitive](hint) {
    if (hint === 'number') return Animal.#count;
    return this.name;
  }
}

class Dog extends Animal {
  #tricks = [];

  constructor(name) {
    super(name, 'woof');
  }

  learn(trick) {
    this.#tricks.push(trick);
    return this;
  }

  perform() {
    return this.#tricks.map((t) => `${this.name} performs ${t}`);
  }
}

// -------------------------------------------------------------------------- //
// Symbols & Well-known symbols
// -------------------------------------------------------------------------- //

const kId = Symbol('id');
const kTag = Symbol.for('app.tag');

class Tagged {
  constructor(id) {
    this[kId] = id;
  }

  get [Symbol.toStringTag]() {
    return 'Tagged';
  }
}

// -------------------------------------------------------------------------- //
// Iterators & Generators
// -------------------------------------------------------------------------- //

function* range(start, end, step = 1) {
  for (let i = start; i < end; i += step) yield i;
}

function* fibonacci() {
  let [a, b] = [0, 1];
  while (true) {
    yield a;
    [a, b] = [b, a + b];
  }
}

class InfiniteCounter {
  [Symbol.iterator]() {
    let n = 0;
    return { next: () => ({ value: n++, done: false }) };
  }
}

// -------------------------------------------------------------------------- //
// Async / await & Promises
// -------------------------------------------------------------------------- //

async function fetchJson(url, signal) {
  const response = await fetch(url, { signal });
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${url}`);
  return response.json();
}

async function withTimeout(promise, ms) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await promise;
  } finally {
    clearTimeout(timer);
  }
}

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function retryAsync(fn, attempts = 3) {
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (err) {
      if (i === attempts - 1) throw err;
      await delay(100 * 2 ** i);
    }
  }
}

// -------------------------------------------------------------------------- //
// Error handling
// -------------------------------------------------------------------------- //

class AppError extends Error {
  constructor(message, code) {
    super(message);
    this.name = 'AppError';
    this.code = code;
  }
}

function safeDivide(a, b) {
  if (b === 0) throw new AppError('Division by zero', 'DIV_ZERO');
  return a / b;
}

// -------------------------------------------------------------------------- //
// Proxy & Reflect
// -------------------------------------------------------------------------- //

function makeReadOnly(target) {
  return new Proxy(target, {
    set(obj, prop) {
      throw new TypeError(`Property "${String(prop)}" is read-only`);
    },
    deleteProperty(obj, prop) {
      throw new TypeError(`Cannot delete "${String(prop)}"`);
    },
  });
}

// -------------------------------------------------------------------------- //
// Tagged template literals
// -------------------------------------------------------------------------- //

function sql(strings, ...values) {
  return strings.reduce((query, str, i) => {
    const val = values[i - 1];
    return query + (val !== undefined ? `$${i}` : '') + str;
  });
}

const userId = 42;
const query = sql`SELECT * FROM users WHERE id = ${userId} LIMIT 1`;

// -------------------------------------------------------------------------- //
// WeakMap / WeakRef
// -------------------------------------------------------------------------- //

const privateData = new WeakMap();

class SecureHolder {
  constructor(secret) {
    privateData.set(this, { secret });
  }

  reveal() {
    return privateData.get(this).secret;
  }
}

// -------------------------------------------------------------------------- //
// Module-like export pattern (CommonJS)
// -------------------------------------------------------------------------- //

module.exports = {
  add,
  multiply,
  square,
  clamp,
  sum,
  makeCounter,
  pipe,
  Animal,
  Dog,
  range,
  fibonacci,
  fetchJson,
  AppError,
  safeDivide,
  makeReadOnly,
  SecureHolder,
};
