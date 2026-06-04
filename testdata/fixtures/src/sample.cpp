/**
 * sample.cpp — comprehensive C++ syntax fixture for parser testing.
 * Covers: classes, templates, inheritance, virtual dispatch, lambdas,
 * smart pointers, move semantics, RAII, concepts (C++20), coroutines,
 * ranges, structured bindings, fold expressions, variadic templates,
 * operator overloading, exceptions, SFINAE, constexpr.
 */

#include <algorithm>
#include <concepts>
#include <coroutine>
#include <functional>
#include <iostream>
#include <memory>
#include <optional>
#include <ranges>
#include <span>
#include <stdexcept>
#include <string>
#include <tuple>
#include <type_traits>
#include <unordered_map>
#include <variant>
#include <vector>

// -------------------------------------------------------------------------- //
// Constants & type aliases
// -------------------------------------------------------------------------- //

inline constexpr int kMaxRetries = 3;
inline constexpr double kPi = 3.14159265358979323846;

using Uuid = std::string;
using Bytes = std::vector<std::byte>;

// -------------------------------------------------------------------------- //
// Concepts (C++20)
// -------------------------------------------------------------------------- //

template <typename T>
concept Numeric = std::integral<T> || std::floating_point<T>;

template <typename T>
concept Printable = requires(T t) {
    { std::cout << t } -> std::same_as<std::ostream&>;
};

template <typename C>
concept Container = requires(C c) {
    { c.begin() } -> std::input_iterator;
    { c.end() }   -> std::sentinel_for<decltype(c.begin())>;
    typename C::value_type;
};

// -------------------------------------------------------------------------- //
// Variadic templates & fold expressions
// -------------------------------------------------------------------------- //

template <Numeric... Args>
constexpr auto sum(Args... args) {
    return (args + ...);
}

template <typename T, typename... Ts>
void print_all(T first, Ts... rest) {
    std::cout << first;
    ((std::cout << ", " << rest), ...);
    std::cout << "\n";
}

// -------------------------------------------------------------------------- //
// RAII resource guard
// -------------------------------------------------------------------------- //

template <typename F>
class ScopeGuard {
    F cleanup_;
    bool active_ = true;
public:
    explicit ScopeGuard(F f) : cleanup_(std::move(f)) {}
    ~ScopeGuard() { if (active_) cleanup_(); }

    ScopeGuard(ScopeGuard&&) = default;
    ScopeGuard(const ScopeGuard&) = delete;
    ScopeGuard& operator=(const ScopeGuard&) = delete;

    void release() { active_ = false; }
};

template <typename F>
auto make_guard(F f) { return ScopeGuard<F>(std::move(f)); }

// -------------------------------------------------------------------------- //
// Custom exception hierarchy
// -------------------------------------------------------------------------- //

class AppError : public std::runtime_error {
    std::string code_;
public:
    AppError(std::string msg, std::string code)
        : std::runtime_error(std::move(msg)), code_(std::move(code)) {}

    const std::string& code() const noexcept { return code_; }
};

class NotFoundError : public AppError {
public:
    NotFoundError(const std::string& resource, const std::string& id)
        : AppError(resource + " with id=\"" + id + "\" not found", "NOT_FOUND") {}
};

// -------------------------------------------------------------------------- //
// Abstract base class & virtual dispatch
// -------------------------------------------------------------------------- //

class Shape {
public:
    virtual ~Shape() = default;
    [[nodiscard]] virtual double area() const = 0;
    [[nodiscard]] virtual double perimeter() const = 0;
    virtual void describe(std::ostream& os) const = 0;

    friend std::ostream& operator<<(std::ostream& os, const Shape& s) {
        s.describe(os);
        return os;
    }
};

class Circle final : public Shape {
    double radius_;
public:
    explicit Circle(double r) : radius_(r) {
        if (r <= 0) throw std::invalid_argument("radius must be positive, got " + std::to_string(r));
    }

    double area() const override { return kPi * radius_ * radius_; }
    double perimeter() const override { return 2 * kPi * radius_; }
    void describe(std::ostream& os) const override {
        os << "Circle(r=" << radius_ << ")";
    }
};

class Rectangle : public Shape {
protected:
    double width_, height_;
public:
    Rectangle(double w, double h) : width_(w), height_(h) {}
    double area() const override { return width_ * height_; }
    double perimeter() const override { return 2 * (width_ + height_); }
    void describe(std::ostream& os) const override {
        os << "Rectangle(" << width_ << "x" << height_ << ")";
    }
};

// -------------------------------------------------------------------------- //
// Templates with specialization
// -------------------------------------------------------------------------- //

template <typename T>
struct TypeTraits {
    static constexpr bool is_numeric = false;
    static std::string name() { return "unknown"; }
};

template <>
struct TypeTraits<int> {
    static constexpr bool is_numeric = true;
    static std::string name() { return "int"; }
};

template <>
struct TypeTraits<double> {
    static constexpr bool is_numeric = true;
    static std::string name() { return "double"; }
};

// -------------------------------------------------------------------------- //
// Generic container with move semantics
// -------------------------------------------------------------------------- //

template <typename T>
class Stack {
    std::vector<T> data_;
public:
    void push(T value) { data_.push_back(std::move(value)); }

    std::optional<T> pop() {
        if (data_.empty()) return std::nullopt;
        T top = std::move(data_.back());
        data_.pop_back();
        return top;
    }

    [[nodiscard]] const T& peek() const {
        if (data_.empty()) throw std::out_of_range("Stack is empty");
        return data_.back();
    }

    [[nodiscard]] bool empty() const noexcept { return data_.empty(); }
    [[nodiscard]] std::size_t size() const noexcept { return data_.size(); }
};

// -------------------------------------------------------------------------- //
// Structured bindings & std::variant
// -------------------------------------------------------------------------- //

using JsonValue = std::variant<std::nullptr_t, bool, int, double, std::string>;

std::string json_type(const JsonValue& v) {
    return std::visit([](auto&& arg) -> std::string {
        using T = std::decay_t<decltype(arg)>;
        if constexpr (std::is_same_v<T, std::nullptr_t>) return "null";
        else if constexpr (std::is_same_v<T, bool>)        return "boolean";
        else if constexpr (std::is_same_v<T, int>)         return "integer";
        else if constexpr (std::is_same_v<T, double>)      return "number";
        else                                                return "string";
    }, v);
}

// -------------------------------------------------------------------------- //
// Lambdas & std::function
// -------------------------------------------------------------------------- //

template <Container C, typename F>
auto transform(const C& c, F f) {
    using U = decltype(f(*c.begin()));
    std::vector<U> result;
    result.reserve(std::ranges::distance(c));
    std::ranges::transform(c, std::back_inserter(result), std::move(f));
    return result;
}

auto make_multiplier(int factor) {
    return [factor](int x) { return x * factor; };
}

// -------------------------------------------------------------------------- //
// Operator overloading
// -------------------------------------------------------------------------- //

struct Vec3 {
    double x, y, z;

    Vec3 operator+(const Vec3& o) const { return {x + o.x, y + o.y, z + o.z}; }
    Vec3 operator*(double s) const { return {x * s, y * s, z * s}; }
    double dot(const Vec3& o) const { return x * o.x + y * o.y + z * o.z; }
    double length() const { return std::sqrt(dot(*this)); }
    Vec3 normalized() const { auto l = length(); return {x/l, y/l, z/l}; }

    bool operator==(const Vec3&) const = default;

    friend std::ostream& operator<<(std::ostream& os, const Vec3& v) {
        return os << "Vec3(" << v.x << ", " << v.y << ", " << v.z << ")";
    }
};

// -------------------------------------------------------------------------- //
// Ranges (C++20)
// -------------------------------------------------------------------------- //

auto even_squares(int n) {
    return std::views::iota(0, n)
         | std::views::filter([](int x) { return x % 2 == 0; })
         | std::views::transform([](int x) { return x * x; });
}

// -------------------------------------------------------------------------- //
// Coroutine generator (C++20)
// -------------------------------------------------------------------------- //

template <typename T>
struct Generator {
    struct promise_type {
        T value_;
        auto get_return_object() { return Generator{std::coroutine_handle<promise_type>::from_promise(*this)}; }
        std::suspend_always initial_suspend() noexcept { return {}; }
        std::suspend_always final_suspend()   noexcept { return {}; }
        std::suspend_always yield_value(T v) { value_ = v; return {}; }
        void return_void() {}
        void unhandled_exception() { std::terminate(); }
    };

    std::coroutine_handle<promise_type> handle_;

    explicit Generator(std::coroutine_handle<promise_type> h) : handle_(h) {}
    ~Generator() { if (handle_) handle_.destroy(); }

    bool next() { handle_.resume(); return !handle_.done(); }
    T value() const { return handle_.promise().value_; }
};

Generator<int> fibonacci_coro() {
    int a = 0, b = 1;
    while (true) {
        co_yield a;
        auto c = a + b;
        a = b;
        b = c;
    }
}

// -------------------------------------------------------------------------- //
// Entry point
// -------------------------------------------------------------------------- //

int main() {
    // Shapes with polymorphism
    std::vector<std::unique_ptr<Shape>> shapes;
    shapes.push_back(std::make_unique<Circle>(5.0));
    shapes.push_back(std::make_unique<Rectangle>(4.0, 3.0));
    for (const auto& s : shapes) {
        std::cout << *s << " area=" << s->area() << "\n";
    }

    // Structured bindings
    std::unordered_map<std::string, int> scores{{"alice", 95}, {"bob", 87}};
    for (const auto& [name, score] : scores) {
        std::cout << name << ": " << score << "\n";
    }

    // Ranges
    for (int v : even_squares(10)) {
        std::cout << v << " ";
    }
    std::cout << "\n";

    // Coroutine
    auto gen = fibonacci_coro();
    for (int i = 0; i < 10 && gen.next(); ++i) {
        std::cout << gen.value() << " ";
    }
    std::cout << "\n";

    // Fold expression
    std::cout << sum(1, 2, 3, 4, 5) << "\n";

    return 0;
}
