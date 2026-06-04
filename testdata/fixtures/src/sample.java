/**
 * sample.java — comprehensive Java syntax fixture for parser testing.
 * Covers: classes, interfaces, generics, enums, records, sealed types,
 * lambdas, streams, switch expressions, try-with-resources, annotations,
 * inner classes, varargs, optional, pattern matching instanceof.
 */

import java.util.*;
import java.util.concurrent.*;
import java.util.function.*;
import java.util.stream.*;

// -------------------------------------------------------------------------- //
// Annotations
// -------------------------------------------------------------------------- //

@interface Validated {
    String message() default "Validation failed";
    Class<?>[] groups() default {};
}

@interface NotBlank {
    String message() default "Must not be blank";
}

// -------------------------------------------------------------------------- //
// Enums
// -------------------------------------------------------------------------- //

enum Status {
    PENDING("Waiting to start"),
    RUNNING("In progress"),
    DONE("Completed"),
    FAILED("Ended with error");

    private final String description;

    Status(String description) {
        this.description = description;
    }

    public String description() { return description; }

    public boolean isTerminal() {
        return this == DONE || this == FAILED;
    }
}

// -------------------------------------------------------------------------- //
// Records (Java 16+)
// -------------------------------------------------------------------------- //

record Point(double x, double y) {
    // compact constructor
    Point {
        if (Double.isNaN(x) || Double.isNaN(y))
            throw new IllegalArgumentException("Coordinates must be finite, got (%s, %s)".formatted(x, y));
    }

    public double distanceTo(Point other) {
        double dx = this.x - other.x;
        double dy = this.y - other.y;
        return Math.sqrt(dx * dx + dy * dy);
    }

    public static Point origin() { return new Point(0, 0); }
}

// -------------------------------------------------------------------------- //
// Sealed interfaces & permits (Java 17+)
// -------------------------------------------------------------------------- //

sealed interface Shape permits Circle, Rectangle, Triangle {
    double area();
    double perimeter();
}

record Circle(double radius) implements Shape {
    public double area() { return Math.PI * radius * radius; }
    public double perimeter() { return 2 * Math.PI * radius; }
}

record Rectangle(double width, double height) implements Shape {
    public double area() { return width * height; }
    public double perimeter() { return 2 * (width + height); }
}

final class Triangle implements Shape {
    private final double a, b, c;

    Triangle(double a, double b, double c) {
        if (a + b <= c || b + c <= a || a + c <= b)
            throw new IllegalArgumentException(
                "Invalid triangle sides: %s, %s, %s".formatted(a, b, c));
        this.a = a; this.b = b; this.c = c;
    }

    public double area() {
        double s = (a + b + c) / 2;
        return Math.sqrt(s * (s - a) * (s - b) * (s - c));
    }

    public double perimeter() { return a + b + c; }
}

// -------------------------------------------------------------------------- //
// Generic interfaces & classes
// -------------------------------------------------------------------------- //

interface Repository<T, ID> {
    Optional<T> findById(ID id);
    List<T> findAll();
    T save(T entity);
    void deleteById(ID id);
}

abstract class BaseEntity {
    protected final String id;
    protected final Date createdAt;

    protected BaseEntity(String id) {
        this.id = Objects.requireNonNull(id, "id must not be null");
        this.createdAt = new Date();
    }

    public String getId() { return id; }
    public Date getCreatedAt() { return createdAt; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof BaseEntity e)) return false;
        return id.equals(e.id);
    }

    @Override
    public int hashCode() { return id.hashCode(); }
}

// -------------------------------------------------------------------------- //
// Classes with generics & bounded wildcards
// -------------------------------------------------------------------------- //

class InMemoryRepository<T extends BaseEntity> implements Repository<T, String> {
    private final Map<String, T> store = new ConcurrentHashMap<>();

    @Override
    public Optional<T> findById(String id) {
        return Optional.ofNullable(store.get(id));
    }

    @Override
    public List<T> findAll() { return List.copyOf(store.values()); }

    @Override
    public T save(T entity) {
        store.put(entity.getId(), entity);
        return entity;
    }

    @Override
    public void deleteById(String id) { store.remove(id); }

    public List<T> findWhere(Predicate<T> predicate) {
        return store.values().stream().filter(predicate).collect(Collectors.toList());
    }
}

// -------------------------------------------------------------------------- //
// Lambdas, method references, streams
// -------------------------------------------------------------------------- //

class StreamExamples {
    public static <T extends Comparable<T>> Optional<T> max(List<T> items) {
        return items.stream().max(Comparator.naturalOrder());
    }

    public static Map<String, Long> wordFrequency(List<String> words) {
        return words.stream()
            .map(String::toLowerCase)
            .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()));
    }

    public static <T, R> List<R> flatMap(List<List<T>> nested, Function<T, R> mapper) {
        return nested.stream()
            .flatMap(Collection::stream)
            .map(mapper)
            .collect(Collectors.toUnmodifiableList());
    }

    public static IntStream fibonacci() {
        return Stream.iterate(
            new int[]{0, 1},
            s -> new int[]{s[1], s[0] + s[1]}
        ).mapToInt(s -> s[0]);
    }
}

// -------------------------------------------------------------------------- //
// Switch expressions (Java 14+)
// -------------------------------------------------------------------------- //

class Formatter {
    static String describe(Shape shape) {
        return switch (shape) {
            case Circle c -> "Circle with radius %.2f".formatted(c.radius());
            case Rectangle r -> "Rectangle %sx%s".formatted(r.width(), r.height());
            case Triangle t -> "Triangle with perimeter %.2f".formatted(t.perimeter());
        };
    }

    static int httpStatusCategory(int code) {
        return switch (code / 100) {
            case 1 -> 1;
            case 2 -> 2;
            case 3 -> 3;
            case 4 -> 4;
            case 5 -> 5;
            default -> throw new IllegalArgumentException("Unknown HTTP code: " + code);
        };
    }
}

// -------------------------------------------------------------------------- //
// Custom exceptions
// -------------------------------------------------------------------------- //

class AppException extends RuntimeException {
    private final String errorCode;

    AppException(String message, String errorCode) {
        super(message);
        this.errorCode = errorCode;
    }

    AppException(String message, String errorCode, Throwable cause) {
        super(message, cause);
        this.errorCode = errorCode;
    }

    public String getErrorCode() { return errorCode; }
}

// -------------------------------------------------------------------------- //
// Try-with-resources & multi-catch
// -------------------------------------------------------------------------- //

class ResourceHandler {
    static String readFile(String path) throws Exception {
        try (var reader = new java.io.BufferedReader(new java.io.FileReader(path))) {
            return reader.lines().collect(Collectors.joining("\n"));
        } catch (java.io.FileNotFoundException | java.io.IOException e) {
            throw new AppException("Failed to read: " + path, "IO_ERROR", e);
        }
    }
}

// -------------------------------------------------------------------------- //
// Inner classes & builder pattern
// -------------------------------------------------------------------------- //

class HttpRequest {
    private final String method;
    private final String url;
    private final Map<String, String> headers;
    private final byte[] body;

    private HttpRequest(Builder builder) {
        this.method = builder.method;
        this.url = builder.url;
        this.headers = Collections.unmodifiableMap(builder.headers);
        this.body = builder.body;
    }

    public String getMethod() { return method; }
    public String getUrl() { return url; }
    public Map<String, String> getHeaders() { return headers; }
    public byte[] getBody() { return body; }

    public static Builder builder(String method, String url) {
        return new Builder(method, url);
    }

    static class Builder {
        private final String method;
        private final String url;
        private final Map<String, String> headers = new LinkedHashMap<>();
        private byte[] body = new byte[0];

        Builder(String method, String url) {
            this.method = method;
            this.url = url;
        }

        public Builder header(String name, String value) {
            headers.put(name, value);
            return this;
        }

        public Builder body(byte[] body) {
            this.body = body;
            return this;
        }

        public HttpRequest build() { return new HttpRequest(this); }
    }
}

// -------------------------------------------------------------------------- //
// Varargs & annotations on parameters
// -------------------------------------------------------------------------- //

class Assertions {
    @SafeVarargs
    static <T> List<T> listOf(T... items) { return List.of(items); }

    static void requireNotBlank(@NotBlank String value, String fieldName) {
        if (value == null || value.isBlank())
            throw new IllegalArgumentException(fieldName + " must not be blank, got: " + value);
    }
}

// -------------------------------------------------------------------------- //
// Functional interfaces & composition
// -------------------------------------------------------------------------- //

@FunctionalInterface
interface Transformer<A, B> {
    B transform(A input);

    default <C> Transformer<A, C> andThen(Transformer<B, C> after) {
        return input -> after.transform(this.transform(input));
    }
}

// -------------------------------------------------------------------------- //
// Entry point
// -------------------------------------------------------------------------- //

public class sample {
    public static void main(String[] args) {
        var repo = new InMemoryRepository<BaseEntity>();

        var c = new Circle(5.0);
        System.out.println(Formatter.describe(c));
        System.out.println("area = " + c.area());

        var p1 = new Point(0, 0);
        var p2 = new Point(3, 4);
        System.out.println("distance = " + p1.distanceTo(p2));

        var req = HttpRequest.builder("GET", "https://api.example.com/users")
            .header("Accept", "application/json")
            .build();
        System.out.println(req.getMethod() + " " + req.getUrl());

        StreamExamples.fibonacci().limit(10).forEach(n -> System.out.print(n + " "));
        System.out.println();
    }
}
