//! sample.rs — comprehensive Rust syntax fixture for parser testing.
//! Covers: structs, enums, traits, generics, lifetimes, closures, iterators,
//! pattern matching, error handling, async/await, macros, trait objects,
//! smart pointers, unsafe blocks, modules, derive macros.

#![allow(dead_code, unused_variables)]

use std::{
    collections::HashMap,
    fmt,
    future::Future,
    ops::{Add, Mul},
    pin::Pin,
    sync::{Arc, Mutex},
};

// -------------------------------------------------------------------------- //
// Constants
// -------------------------------------------------------------------------- //

const MAX_RETRIES: u32 = 3;
const PI: f64 = std::f64::consts::PI;

// -------------------------------------------------------------------------- //
// Enums
// -------------------------------------------------------------------------- //

#[derive(Debug, Clone, PartialEq, Eq)]
enum Status {
    Pending,
    Running { started_at: u64 },
    Done(String),
    Failed { code: i32, reason: String },
}

impl Status {
    fn is_terminal(&self) -> bool {
        matches!(self, Status::Done(_) | Status::Failed { .. })
    }
}

impl fmt::Display for Status {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Status::Pending => write!(f, "pending"),
            Status::Running { started_at } => write!(f, "running since {started_at}"),
            Status::Done(msg) => write!(f, "done: {msg}"),
            Status::Failed { code, reason } => write!(f, "failed({code}): {reason}"),
        }
    }
}

// -------------------------------------------------------------------------- //
// Custom error type
// -------------------------------------------------------------------------- //

#[derive(Debug)]
enum AppError {
    NotFound { resource: String, id: String },
    Validation(String),
    Io(std::io::Error),
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AppError::NotFound { resource, id } => {
                write!(f, "{resource} with id={id:?} not found")
            }
            AppError::Validation(msg) => write!(f, "validation error: {msg}"),
            AppError::Io(e) => write!(f, "io error: {e}"),
        }
    }
}

impl std::error::Error for AppError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            AppError::Io(e) => Some(e),
            _ => None,
        }
    }
}

impl From<std::io::Error> for AppError {
    fn from(e: std::io::Error) -> Self {
        AppError::Io(e)
    }
}

type Result<T> = std::result::Result<T, AppError>;

// -------------------------------------------------------------------------- //
// Traits
// -------------------------------------------------------------------------- //

trait Repository<T, ID> {
    fn find_by_id(&self, id: &ID) -> Option<&T>;
    fn save(&mut self, entity: T);
    fn delete(&mut self, id: &ID) -> bool;
    fn list(&self) -> Vec<&T>;
}

trait Validate {
    fn validate(&self) -> Result<()>;
}

trait Describable: fmt::Display + fmt::Debug {}

// -------------------------------------------------------------------------- //
// Structs
// -------------------------------------------------------------------------- //

#[derive(Debug, Clone)]
struct User {
    id: String,
    name: String,
    email: String,
}

impl User {
    fn new(id: impl Into<String>, name: impl Into<String>, email: impl Into<String>) -> Self {
        User {
            id: id.into(),
            name: name.into(),
            email: email.into(),
        }
    }
}

impl Validate for User {
    fn validate(&self) -> Result<()> {
        if self.name.is_empty() {
            return Err(AppError::Validation("name must not be empty".into()));
        }
        if !self.email.contains('@') {
            return Err(AppError::Validation(
                format!("email {:?} is invalid", self.email),
            ));
        }
        Ok(())
    }
}

impl fmt::Display for User {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "User({}, {})", self.name, self.email)
    }
}

impl Describable for User {}

// -------------------------------------------------------------------------- //
// In-memory repository
// -------------------------------------------------------------------------- //

struct MemStore<T> {
    data: HashMap<String, T>,
}

impl<T> MemStore<T> {
    fn new() -> Self {
        MemStore { data: HashMap::new() }
    }
}

impl<T: Clone> Repository<T, String> for MemStore<T> {
    fn find_by_id(&self, id: &String) -> Option<&T> {
        self.data.get(id)
    }

    fn save(&mut self, entity: T) where T: Clone {
        // key extraction not available generically — example placeholder
    }

    fn delete(&mut self, id: &String) -> bool {
        self.data.remove(id).is_some()
    }

    fn list(&self) -> Vec<&T> {
        self.data.values().collect()
    }
}

// -------------------------------------------------------------------------- //
// Generics with multiple bounds & where clauses
// -------------------------------------------------------------------------- //

fn largest<T>(list: &[T]) -> &T
where
    T: PartialOrd,
{
    let mut max = &list[0];
    for item in list.iter() {
        if item > max {
            max = item;
        }
    }
    max
}

fn zip_with<A, B, C, F>(a: Vec<A>, b: Vec<B>, f: F) -> Vec<C>
where
    F: Fn(A, B) -> C,
{
    a.into_iter().zip(b).map(|(x, y)| f(x, y)).collect()
}

// -------------------------------------------------------------------------- //
// Lifetimes
// -------------------------------------------------------------------------- //

struct StrSplit<'a, 'b> {
    haystack: &'a str,
    delimiter: &'b str,
}

impl<'a, 'b> Iterator for StrSplit<'a, 'b> {
    type Item = &'a str;

    fn next(&mut self) -> Option<Self::Item> {
        if let Some(pos) = self.haystack.find(self.delimiter) {
            let part = &self.haystack[..pos];
            self.haystack = &self.haystack[pos + self.delimiter.len()..];
            Some(part)
        } else if self.haystack.is_empty() {
            None
        } else {
            let rest = self.haystack;
            self.haystack = "";
            Some(rest)
        }
    }
}

fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() >= y.len() { x } else { y }
}

// -------------------------------------------------------------------------- //
// Closures & iterators
// -------------------------------------------------------------------------- //

fn fibonacci() -> impl Iterator<Item = u64> {
    let mut state = (0u64, 1u64);
    std::iter::from_fn(move || {
        let next = state.0;
        state = (state.1, state.0.saturating_add(state.1));
        Some(next)
    })
}

fn pipeline_example(data: Vec<i32>) -> Vec<i32> {
    data.into_iter()
        .filter(|&x| x > 0)
        .map(|x| x * 2)
        .take_while(|&x| x < 100)
        .collect()
}

// -------------------------------------------------------------------------- //
// Smart pointers
// -------------------------------------------------------------------------- //

type SharedCounter = Arc<Mutex<u64>>;

fn make_counter() -> SharedCounter {
    Arc::new(Mutex::new(0))
}

fn increment(counter: &SharedCounter) {
    let mut guard = counter.lock().unwrap();
    *guard += 1;
}

// -------------------------------------------------------------------------- //
// Trait objects (dynamic dispatch)
// -------------------------------------------------------------------------- //

fn print_all(items: &[Box<dyn fmt::Display>]) {
    for item in items {
        println!("{item}");
    }
}

fn make_adder(x: i32) -> Box<dyn Fn(i32) -> i32> {
    Box::new(move |y| x + y)
}

// -------------------------------------------------------------------------- //
// Async / await
// -------------------------------------------------------------------------- //

async fn fetch(url: &str) -> Result<Vec<u8>> {
    // Simulated async I/O
    Ok(url.as_bytes().to_vec())
}

async fn fetch_all(urls: Vec<&str>) -> Vec<Result<Vec<u8>>> {
    let mut results = Vec::with_capacity(urls.len());
    for url in urls {
        results.push(fetch(url).await);
    }
    results
}

// -------------------------------------------------------------------------- //
// Operator overloading
// -------------------------------------------------------------------------- //

#[derive(Debug, Clone, Copy, PartialEq)]
struct Vec2 {
    x: f64,
    y: f64,
}

impl Vec2 {
    fn new(x: f64, y: f64) -> Self { Vec2 { x, y } }
    fn length(self) -> f64 { (self.x * self.x + self.y * self.y).sqrt() }
    fn dot(self, other: Vec2) -> f64 { self.x * other.x + self.y * other.y }
}

impl Add for Vec2 {
    type Output = Vec2;
    fn add(self, rhs: Vec2) -> Vec2 { Vec2::new(self.x + rhs.x, self.y + rhs.y) }
}

impl Mul<f64> for Vec2 {
    type Output = Vec2;
    fn mul(self, rhs: f64) -> Vec2 { Vec2::new(self.x * rhs, self.y * rhs) }
}

impl fmt::Display for Vec2 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "({:.2}, {:.2})", self.x, self.y)
    }
}

// -------------------------------------------------------------------------- //
// Macros
// -------------------------------------------------------------------------- //

macro_rules! hash_map {
    ($($key:expr => $val:expr),* $(,)?) => {{
        let mut map = HashMap::new();
        $(map.insert($key, $val);)*
        map
    }};
}

macro_rules! assert_ok {
    ($expr:expr) => {
        match $expr {
            Ok(v) => v,
            Err(e) => panic!("expected Ok, got Err({e:?})"),
        }
    };
}

// -------------------------------------------------------------------------- //
// Unsafe
// -------------------------------------------------------------------------- //

fn raw_pointer_demo() {
    let mut val = 42i32;
    let raw = &mut val as *mut i32;
    unsafe {
        *raw += 1;
        assert_eq!(*raw, 43);
    }
}

// -------------------------------------------------------------------------- //
// Pattern matching advanced
// -------------------------------------------------------------------------- //

fn classify(n: i64) -> &'static str {
    match n {
        i64::MIN..=-1 => "negative",
        0 => "zero",
        1..=9 => "single digit",
        10..=99 => "double digit",
        _ if n % 2 == 0 => "large even",
        _ => "large odd",
    }
}

// -------------------------------------------------------------------------- //
// Entry point
// -------------------------------------------------------------------------- //

fn main() {
    let user = User::new("u1", "Alice", "alice@example.com");
    println!("{user}");
    assert_ok!(user.validate());

    let fibs: Vec<u64> = fibonacci().take(10).collect();
    println!("{fibs:?}");

    let v1 = Vec2::new(1.0, 0.0);
    let v2 = Vec2::new(0.0, 1.0);
    println!("v1 + v2 = {}", v1 + v2);

    let counter = make_counter();
    increment(&counter);
    println!("counter = {}", counter.lock().unwrap());

    let m = hash_map!["one" => 1, "two" => 2, "three" => 3];
    println!("{m:?}");
}
