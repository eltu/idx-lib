// sample.dart — comprehensive Dart syntax fixture for parser testing.
// Covers: classes, mixins, extensions, generics, async/await, streams,
// null safety, pattern matching, records, sealed classes, factory constructors,
// operator overloading, isolates (comment), typedef, late, const.

// ignore_for_file: unused_element, unused_local_variable

import 'dart:async';
import 'dart:math' as math;

// -------------------------------------------------------------------------- //
// Constants
// -------------------------------------------------------------------------- //

const int maxRetries = 3;
const Duration defaultTimeout = Duration(seconds: 30);
const String defaultRole = 'member';

// -------------------------------------------------------------------------- //
// Enums (enhanced, Dart 2.17+)
// -------------------------------------------------------------------------- //

enum Status {
  pending('Waiting'),
  running('In progress'),
  done('Completed'),
  failed('Failed');

  const Status(this.label);

  final String label;

  bool get isTerminal => this == Status.done || this == Status.failed;
}

// -------------------------------------------------------------------------- //
// Records (Dart 3.0+)
// -------------------------------------------------------------------------- //

typedef Point = ({double x, double y});
typedef UserRecord = ({String id, String name, String email});

extension PointExt on Point {
  double distanceTo(Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  Point operator +(Point other) => (x: x + other.x, y: y + other.y);
}

// -------------------------------------------------------------------------- //
// Sealed classes (Dart 3.0+)
// -------------------------------------------------------------------------- //

sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final Object error;
}

final class Loading<T> extends Result<T> {
  const Loading();
}

extension ResultX<T> on Result<T> {
  bool get isSuccess => this is Success<T>;

  T? getOrNull() => switch (this) {
    Success(:final value) => value,
    _ => null,
  };

  Result<R> map<R>(R Function(T) transform) => switch (this) {
    Success(:final value) => Success(transform(value)),
    Failure(:final error) => Failure(error),
    Loading() => Loading(),
  };
}

// -------------------------------------------------------------------------- //
// Abstract class & interface-like
// -------------------------------------------------------------------------- //

abstract class Repository<T> {
  Future<T?> findById(String id);
  Future<List<T>> list();
  Future<T> save(T entity);
  Future<bool> delete(String id);
}

// -------------------------------------------------------------------------- //
// Mixin
// -------------------------------------------------------------------------- //

mixin Timestamps {
  late final DateTime createdAt = DateTime.now().toUtc();
  DateTime updatedAt = DateTime.now().toUtc();

  void touch() => updatedAt = DateTime.now().toUtc();
}

mixin Validatable {
  List<String> get validationErrors;
  bool get isValid => validationErrors.isEmpty;
}

// -------------------------------------------------------------------------- //
// Classes with mixins, constructors, factory
// -------------------------------------------------------------------------- //

class User with Timestamps, Validatable {
  User({
    required this.id,
    required this.name,
    required this.email,
    this.role = defaultRole,
  });

  factory User.fromRecord(UserRecord r) =>
      User(id: r.id, name: r.name, email: r.email);

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String? ?? defaultRole,
      );

  final String id;
  String name;
  String email;
  String role;

  @override
  List<String> get validationErrors {
    final errors = <String>[];
    if (name.trim().isEmpty) errors.add('name is required');
    if (!email.contains('@')) errors.add('email is invalid');
    return errors;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
      };

  @override
  String toString() => 'User($name, $email)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is User && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// -------------------------------------------------------------------------- //
// Generic in-memory repository
// -------------------------------------------------------------------------- //

class MemoryRepository<T extends Object> implements Repository<T> {
  final _store = <String, T>{};
  final String Function(T) keyOf;

  MemoryRepository({required this.keyOf});

  @override
  Future<T?> findById(String id) async => _store[id];

  @override
  Future<List<T>> list() async => List.unmodifiable(_store.values);

  @override
  Future<T> save(T entity) async {
    _store[keyOf(entity)] = entity;
    return entity;
  }

  @override
  Future<bool> delete(String id) async => _store.remove(id) != null;
}

// -------------------------------------------------------------------------- //
// Extension methods
// -------------------------------------------------------------------------- //

extension StringX on String {
  bool get isValidEmail => contains('@') && contains('.');

  String get camelToSnake => replaceAllMapped(
        RegExp(r'([A-Z])'),
        (m) => '_${m.group(1)!.toLowerCase()}',
      ).replaceFirst(RegExp(r'^_'), '');
}

extension ListX<T extends Comparable<T>> on List<T> {
  T? get median {
    if (isEmpty) return null;
    final sorted = [...this]..sort();
    return sorted[length ~/ 2];
  }
}

// -------------------------------------------------------------------------- //
// Generics & higher-order functions
// -------------------------------------------------------------------------- //

R Function(T) compose<T, U, R>(R Function(U) f, U Function(T) g) =>
    (T x) => f(g(x));

List<R> mapList<T, R>(List<T> items, R Function(T) transform) =>
    items.map(transform).toList();

Map<K, List<T>> groupBy<T, K>(Iterable<T> items, K Function(T) keyFn) {
  final map = <K, List<T>>{};
  for (final item in items) {
    (map[keyFn(item)] ??= []).add(item);
  }
  return map;
}

// -------------------------------------------------------------------------- //
// Async / await & streams
// -------------------------------------------------------------------------- //

Future<T> withRetry<T>(
  Future<T> Function() operation, {
  int attempts = maxRetries,
  Duration delay = const Duration(milliseconds: 100),
}) async {
  Object? lastError;
  for (var i = 0; i < attempts; i++) {
    try {
      return await operation();
    } catch (e) {
      lastError = e;
      if (i < attempts - 1) await Future.delayed(delay * (i + 1));
    }
  }
  throw lastError!;
}

Stream<int> fibonacci() async* {
  var a = 0;
  var b = 1;
  while (true) {
    yield a;
    final c = a + b;
    a = b;
    b = c;
  }
}

Stream<List<T>> chunked<T>(Stream<T> source, int size) async* {
  final buffer = <T>[];
  await for (final item in source) {
    buffer.add(item);
    if (buffer.length >= size) {
      yield List.of(buffer);
      buffer.clear();
    }
  }
  if (buffer.isNotEmpty) yield buffer;
}

// -------------------------------------------------------------------------- //
// Pattern matching (switch expressions)
// -------------------------------------------------------------------------- //

String classify(Object? value) => switch (value) {
  null                     => 'null',
  bool b                   => 'boolean: $b',
  int n when n < 0         => 'negative int',
  int n                    => 'non-negative int $n',
  String s when s.isEmpty  => 'empty string',
  String s                 => 'string(${s.length})',
  [_, _, ...]              => 'list with 2+ items',
  []                       => 'empty list',
  _                        => 'unknown',
};

// -------------------------------------------------------------------------- //
// Late & const
// -------------------------------------------------------------------------- //

class Config {
  Config._();

  static final Config instance = Config._();

  late final String host;
  late final int port;
  late final bool debug;

  void initialize({
    required String host,
    required int port,
    bool debug = false,
  }) {
    this.host = host;
    this.port = port;
    this.debug = debug;
  }

  String get baseUrl => 'http://$host:$port';
}

// -------------------------------------------------------------------------- //
// Custom exceptions
// -------------------------------------------------------------------------- //

class AppException implements Exception {
  const AppException(this.message, this.code);

  final String message;
  final String code;

  @override
  String toString() => 'AppException[$code]: $message';
}

class NotFoundException extends AppException {
  NotFoundException(String resource, String id)
      : super('$resource with id="$id" not found', 'NOT_FOUND');
}

// -------------------------------------------------------------------------- //
// Entry point
// -------------------------------------------------------------------------- //

Future<void> main() async {
  final user = User(id: 'u1', name: 'Alice', email: 'alice@example.com');
  print(user);
  print('valid: ${user.isValid}');

  final fibs = await fibonacci().take(10).toList();
  print(fibs);

  final p1 = (x: 3.0, y: 4.0);
  final origin = (x: 0.0, y: 0.0);
  print('distance: ${p1.distanceTo(origin)}');

  final result = Success(42);
  print(result.map((n) => n * 2).getOrNull());

  Config.instance.initialize(host: 'api.example.com', port: 443);
  print(Config.instance.baseUrl);
}
