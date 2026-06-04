/**
 * sample.kt — comprehensive Kotlin syntax fixture for parser testing.
 * Covers: data classes, sealed classes, objects, companion objects,
 * extension functions, coroutines, flow, higher-order functions, delegation,
 * null safety, destructuring, when expressions, inline/reified generics.
 */

package sample

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.sqrt
import kotlin.properties.Delegates
import kotlin.reflect.KClass

// -------------------------------------------------------------------------- //
// Constants & type aliases
// -------------------------------------------------------------------------- //

const val MAX_RETRIES = 3
const val DEFAULT_TIMEOUT = 30_000L

typealias Uuid = String
typealias Handler<T> = suspend (T) -> Unit

// -------------------------------------------------------------------------- //
// Enums
// -------------------------------------------------------------------------- //

enum class Status(val label: String) {
    PENDING("Waiting"),
    RUNNING("In progress"),
    DONE("Completed"),
    FAILED("Failed");

    val isTerminal: Boolean
        get() = this == DONE || this == FAILED
}

// -------------------------------------------------------------------------- //
// Sealed classes (ADT)
// -------------------------------------------------------------------------- //

sealed class Result<out T> {
    data class Success<T>(val value: T) : Result<T>()
    data class Failure(val error: Throwable) : Result<Nothing>()
    object Loading : Result<Nothing>()

    val isSuccess get() = this is Success
    val isFailure get() = this is Failure

    fun getOrNull(): T? = (this as? Success)?.value
    fun getOrThrow(): T = when (this) {
        is Success -> value
        is Failure -> throw error
        Loading -> error("Still loading")
    }

    fun <R> map(transform: (T) -> R): Result<R> = when (this) {
        is Success -> Success(transform(value))
        is Failure -> this
        Loading -> Loading
    }
}

// -------------------------------------------------------------------------- //
// Data classes
// -------------------------------------------------------------------------- //

data class Point(val x: Double, val y: Double) {
    companion object {
        val ORIGIN = Point(0.0, 0.0)
        fun of(x: Number, y: Number) = Point(x.toDouble(), y.toDouble())
    }

    fun distanceTo(other: Point): Double {
        val dx = x - other.x
        val dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    operator fun plus(other: Point) = Point(x + other.x, y + other.y)
    operator fun times(scale: Double) = Point(x * scale, y * scale)
}

data class User(
    val id: Uuid,
    val name: String,
    val email: String,
    val role: String = "member",
) {
    init {
        require(name.isNotBlank()) { "name must not be blank" }
        require('@' in email) { "email '$email' is invalid" }
    }
}

// -------------------------------------------------------------------------- //
// Interfaces
// -------------------------------------------------------------------------- //

interface Repository<T, ID> {
    suspend fun findById(id: ID): T?
    suspend fun list(): List<T>
    suspend fun save(entity: T): T
    suspend fun delete(id: ID): Boolean
}

interface Validator<T> {
    fun validate(value: T): List<String>
    fun isValid(value: T) = validate(value).isEmpty()
}

// -------------------------------------------------------------------------- //
// Object & companion object
// -------------------------------------------------------------------------- //

object AppConfig {
    var host: String = "localhost"
        private set
    var port: Int = 8080
        private set

    fun configure(host: String, port: Int) {
        this.host = host
        this.port = port
    }

    val baseUrl get() = "http://$host:$port"
}

// -------------------------------------------------------------------------- //
// Abstract class with delegation
// -------------------------------------------------------------------------- //

abstract class BaseService<T, ID>(protected val repo: Repository<T, ID>) {
    abstract fun validate(entity: T): List<String>

    suspend fun getOrThrow(id: ID): T =
        repo.findById(id) ?: throw NoSuchElementException("Entity $id not found")
}

// -------------------------------------------------------------------------- //
// Extension functions
// -------------------------------------------------------------------------- //

fun String.isValidEmail() = contains('@') && contains('.')

fun <T> List<T>.second() = this[1]

fun <T, R> Iterable<T>.mapNotNullIndexed(transform: (Int, T) -> R?): List<R> =
    mapIndexedNotNull { i, v -> transform(i, v) }

fun <T : Comparable<T>> List<T>.median(): T {
    require(isNotEmpty()) { "List must not be empty" }
    return sorted()[size / 2]
}

fun Int.factorial(): Long = if (this <= 1) 1L else this * (this - 1).factorial()

// -------------------------------------------------------------------------- //
// Higher-order functions & lambdas
// -------------------------------------------------------------------------- //

fun <A, B, C> compose(f: (A) -> B, g: (B) -> C): (A) -> C = { g(f(it)) }

fun <T> memoize(fn: (T) -> T): (T) -> T {
    val cache = mutableMapOf<T, T>()
    return { cache.getOrPut(it) { fn(it) } }
}

fun <T> retry(times: Int = MAX_RETRIES, block: () -> T): T {
    repeat(times - 1) {
        try { return block() } catch (_: Exception) { /* continue */ }
    }
    return block()
}

// -------------------------------------------------------------------------- //
// Coroutines & Flow
// -------------------------------------------------------------------------- //

fun fibonacci(): Flow<Long> = flow {
    var a = 0L
    var b = 1L
    while (true) {
        emit(a)
        val c = a + b
        a = b
        b = c
    }
}

suspend fun <T> withRetry(
    times: Int = MAX_RETRIES,
    delayMs: Long = 100,
    block: suspend () -> T,
): T {
    repeat(times - 1) {
        try { return block() } catch (_: Exception) { delay(delayMs * (it + 1)) }
    }
    return block()
}

fun <T> Flow<T>.chunked(size: Int): Flow<List<T>> = flow {
    val buffer = mutableListOf<T>()
    collect { item ->
        buffer += item
        if (buffer.size >= size) {
            emit(buffer.toList())
            buffer.clear()
        }
    }
    if (buffer.isNotEmpty()) emit(buffer.toList())
}

// -------------------------------------------------------------------------- //
// Destructuring & when expression
// -------------------------------------------------------------------------- //

fun describePoint(p: Point): String {
    val (x, y) = p
    return when {
        x == 0.0 && y == 0.0 -> "origin"
        x == 0.0              -> "on Y-axis at $y"
        y == 0.0              -> "on X-axis at $x"
        else                  -> "at ($x, $y)"
    }
}

fun classify(value: Any?): String = when (value) {
    null          -> "null"
    is Boolean    -> "boolean: $value"
    is Int        -> if (value >= 0) "non-negative int" else "negative int"
    is String     -> "string of length ${value.length}"
    is List<*>    -> "list of ${value.size} items"
    is Point      -> describePoint(value)
    else          -> "unknown: ${value::class.simpleName}"
}

// -------------------------------------------------------------------------- //
// Inline & reified generics
// -------------------------------------------------------------------------- //

inline fun <reified T> List<*>.filterIsInstance2(): List<T> =
    filterIsInstance<T>()

inline fun <reified T : Any> KClass<T>.create(): T =
    T::class.java.getDeclaredConstructor().newInstance()

// -------------------------------------------------------------------------- //
// Property delegation
// -------------------------------------------------------------------------- //

class ObservableUser {
    var name: String by Delegates.observable("<none>") { _, old, new ->
        println("name changed: $old -> $new")
    }

    var age: Int by Delegates.vetoable(0) { _, _, new ->
        new >= 0
    }
}

// -------------------------------------------------------------------------- //
// Custom exceptions
// -------------------------------------------------------------------------- //

sealed class AppException(message: String, val code: String) : Exception(message)

class NotFoundException(resource: String, id: String) :
    AppException("$resource with id='$id' not found", "NOT_FOUND")

class ValidationException(details: List<String>) :
    AppException("Validation failed: ${details.joinToString()}", "VALIDATION_ERROR")

// -------------------------------------------------------------------------- //
// Entry point
// -------------------------------------------------------------------------- //

fun main() = runBlocking {
    val user = User(id = "u1", name = "Alice", email = "alice@example.com")
    println(user)

    val fibs = fibonacci().take(10).toList()
    println(fibs)

    val p = Point.of(3, 4)
    println("Distance: ${p.distanceTo(Point.ORIGIN)}")
    println(describePoint(p))

    AppConfig.configure("api.example.com", 443)
    println(AppConfig.baseUrl)

    val result: Result<Int> = Result.Success(42)
    println(result.map { it * 2 }.getOrThrow())
}
