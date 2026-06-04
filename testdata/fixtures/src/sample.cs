/**
 * sample.cs — comprehensive C# syntax fixture for parser testing.
 * Covers: records, interfaces, generics, LINQ, async/await, pattern matching,
 * extension methods, delegates, events, indexers, operator overloading,
 * nullable reference types, primary constructors (C#12), required members.
 */

#nullable enable

using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.CompilerServices;

namespace Sample;

// -------------------------------------------------------------------------- //
// Constants
// -------------------------------------------------------------------------- //

public static class Constants
{
    public const int MaxRetries = 3;
    public const string DefaultRole = "member";
}

// -------------------------------------------------------------------------- //
// Enums
// -------------------------------------------------------------------------- //

public enum Status
{
    Pending,
    Running,
    Done,
    Failed
}

public static class StatusExtensions
{
    public static bool IsTerminal(this Status s) =>
        s is Status.Done or Status.Failed;

    public static string Describe(this Status s) => s switch
    {
        Status.Pending => "Waiting to start",
        Status.Running => "In progress",
        Status.Done    => "Completed",
        Status.Failed  => "Failed",
        _              => throw new ArgumentOutOfRangeException(nameof(s), s, null)
    };
}

// -------------------------------------------------------------------------- //
// Records
// -------------------------------------------------------------------------- //

public record Point(double X, double Y)
{
    public double DistanceTo(Point other) =>
        Math.Sqrt(Math.Pow(X - other.X, 2) + Math.Pow(Y - other.Y, 2));

    public static Point Origin => new(0, 0);
}

public record struct Size(double Width, double Height)
{
    public double Area => Width * Height;
}

// -------------------------------------------------------------------------- //
// Interfaces
// -------------------------------------------------------------------------- //

public interface IRepository<T, TId>
{
    Task<T?> FindByIdAsync(TId id, CancellationToken ct = default);
    Task<IReadOnlyList<T>> ListAsync(CancellationToken ct = default);
    Task<T> SaveAsync(T entity, CancellationToken ct = default);
    Task<bool> DeleteAsync(TId id, CancellationToken ct = default);
}

public interface IValidator<T>
{
    bool Validate(T value, out IReadOnlyList<string> errors);
}

// -------------------------------------------------------------------------- //
// Abstract class
// -------------------------------------------------------------------------- //

public abstract class BaseEntity
{
    public required string Id { get; init; }
    public DateTime CreatedAt { get; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; private set; } = DateTime.UtcNow;

    protected void Touch() => UpdatedAt = DateTime.UtcNow;

    public override bool Equals(object? obj) =>
        obj is BaseEntity e && Id == e.Id;

    public override int GetHashCode() => Id.GetHashCode();
}

// -------------------------------------------------------------------------- //
// Domain entity
// -------------------------------------------------------------------------- //

public sealed class User : BaseEntity
{
    public required string Name { get; set; }
    public required string Email { get; set; }
    public string Role { get; set; } = Constants.DefaultRole;

    public void UpdateName(string name)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        Name = name;
        Touch();
    }
}

// -------------------------------------------------------------------------- //
// Generic in-memory repository
// -------------------------------------------------------------------------- //

public sealed class MemoryRepository<T> : IRepository<T, string>
    where T : BaseEntity
{
    private readonly Dictionary<string, T> _store = new();
    private readonly SemaphoreSlim _lock = new(1, 1);

    public async Task<T?> FindByIdAsync(string id, CancellationToken ct = default)
    {
        await _lock.WaitAsync(ct);
        try { return _store.TryGetValue(id, out var e) ? e : null; }
        finally { _lock.Release(); }
    }

    public async Task<IReadOnlyList<T>> ListAsync(CancellationToken ct = default)
    {
        await _lock.WaitAsync(ct);
        try { return _store.Values.ToList().AsReadOnly(); }
        finally { _lock.Release(); }
    }

    public async Task<T> SaveAsync(T entity, CancellationToken ct = default)
    {
        await _lock.WaitAsync(ct);
        try { _store[entity.Id] = entity; return entity; }
        finally { _lock.Release(); }
    }

    public async Task<bool> DeleteAsync(string id, CancellationToken ct = default)
    {
        await _lock.WaitAsync(ct);
        try { return _store.Remove(id); }
        finally { _lock.Release(); }
    }
}

// -------------------------------------------------------------------------- //
// LINQ & extension methods
// -------------------------------------------------------------------------- //

public static class EnumerableExtensions
{
    public static IEnumerable<T> WhereNotNull<T>(this IEnumerable<T?> source) where T : class =>
        source.Where(x => x is not null)!;

    public static IEnumerable<(T Item, int Index)> Indexed<T>(this IEnumerable<T> source) =>
        source.Select((item, i) => (item, i));

    public static IReadOnlyDictionary<TKey, IReadOnlyList<T>> GroupByReadOnly<T, TKey>(
        this IEnumerable<T> source, Func<T, TKey> keySelector) where TKey : notnull =>
        source.GroupBy(keySelector)
              .ToDictionary(g => g.Key, g => (IReadOnlyList<T>)g.ToList());
}

// -------------------------------------------------------------------------- //
// Delegates, events, lambdas
// -------------------------------------------------------------------------- //

public delegate TResult Transformer<in T, out TResult>(T input);

public sealed class EventBus
{
    private readonly Dictionary<Type, List<Delegate>> _handlers = new();

    public event EventHandler<Exception>? ErrorOccurred;

    public void Subscribe<T>(Action<T> handler)
    {
        var type = typeof(T);
        if (!_handlers.ContainsKey(type)) _handlers[type] = new();
        _handlers[type].Add(handler);
    }

    public void Publish<T>(T message)
    {
        if (!_handlers.TryGetValue(typeof(T), out var list)) return;
        foreach (var h in list)
        {
            try { ((Action<T>)h)(message); }
            catch (Exception ex) { ErrorOccurred?.Invoke(this, ex); }
        }
    }
}

// -------------------------------------------------------------------------- //
// Async streams (IAsyncEnumerable)
// -------------------------------------------------------------------------- //

public static class AsyncStreams
{
    public static async IAsyncEnumerable<int> FibonacciAsync(
        int count,
        [EnumeratorCancellation] CancellationToken ct = default)
    {
        int a = 0, b = 1;
        for (int i = 0; i < count; i++)
        {
            ct.ThrowIfCancellationRequested();
            yield return a;
            await Task.Yield();
            (a, b) = (b, a + b);
        }
    }
}

// -------------------------------------------------------------------------- //
// Pattern matching
// -------------------------------------------------------------------------- //

public static class Classifier
{
    public static string Classify(object? value) => value switch
    {
        null                   => "null",
        true                   => "boolean true",
        false                  => "boolean false",
        int n when n < 0       => $"negative int {n}",
        int n                  => $"non-negative int {n}",
        string { Length: 0 }   => "empty string",
        string s               => $"string of length {s.Length}",
        Point { X: 0, Y: 0 }  => "origin point",
        Point p                => $"point at ({p.X},{p.Y})",
        IEnumerable<int> list  => $"int collection with {list.Count()} items",
        _                      => $"unknown: {value.GetType().Name}"
    };
}

// -------------------------------------------------------------------------- //
// Operator overloading
// -------------------------------------------------------------------------- //

public readonly struct Money
{
    public decimal Amount { get; }
    public string Currency { get; }

    public Money(decimal amount, string currency)
    {
        if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount), amount, "must be non-negative");
        Amount = amount;
        Currency = currency;
    }

    public static Money operator +(Money a, Money b)
    {
        if (a.Currency != b.Currency)
            throw new InvalidOperationException($"Currency mismatch: {a.Currency} vs {b.Currency}");
        return new(a.Amount + b.Amount, a.Currency);
    }

    public static bool operator >(Money a, Money b)  => a.Amount > b.Amount;
    public static bool operator <(Money a, Money b)  => a.Amount < b.Amount;
    public static bool operator >=(Money a, Money b) => a.Amount >= b.Amount;
    public static bool operator <=(Money a, Money b) => a.Amount <= b.Amount;

    public override string ToString() => $"{Amount:F2} {Currency}";
}

// -------------------------------------------------------------------------- //
// Indexers
// -------------------------------------------------------------------------- //

public sealed class Matrix
{
    private readonly double[,] _data;

    public Matrix(int rows, int cols) => _data = new double[rows, cols];

    public double this[int row, int col]
    {
        get => _data[row, col];
        set => _data[row, col] = value;
    }

    public int Rows => _data.GetLength(0);
    public int Cols => _data.GetLength(1);
}

// -------------------------------------------------------------------------- //
// Error types
// -------------------------------------------------------------------------- //

public sealed class AppException : Exception
{
    public string Code { get; }

    public AppException(string message, string code, Exception? inner = null)
        : base(message, inner)
    {
        Code = code;
    }
}

// -------------------------------------------------------------------------- //
// Entry point
// -------------------------------------------------------------------------- //

public static class Program
{
    public static async Task Main()
    {
        var user = new User { Id = Guid.NewGuid().ToString(), Name = "Alice", Email = "alice@example.com" };
        Console.WriteLine(user.Name);

        var status = Status.Done;
        Console.WriteLine(status.Describe());

        await foreach (var n in AsyncStreams.FibonacciAsync(10))
        {
            Console.Write($"{n} ");
        }
        Console.WriteLine();

        var p = new Point(3, 4);
        Console.WriteLine($"Distance from origin: {p.DistanceTo(Point.Origin)}");

        var money = new Money(10.50m, "USD") + new Money(5.25m, "USD");
        Console.WriteLine(money);
    }
}
