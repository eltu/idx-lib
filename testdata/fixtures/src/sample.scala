/**
 * sample.scala — comprehensive Scala 3 syntax fixture for parser testing.
 * Covers: case classes, enums, traits, given/using, extension methods,
 * type classes, opaque types, union/intersection types, match types,
 * for-comprehensions, futures, pattern matching, higher-kinded types.
 */

import scala.concurrent.{ExecutionContext, Future}
import scala.util.{Failure, Success, Try}

// -------------------------------------------------------------------------- //
// Opaque types
// -------------------------------------------------------------------------- //

opaque type Uuid = String
object Uuid:
  def apply(s: String): Uuid = s
  extension (id: Uuid) def value: String = id

opaque type PositiveInt <: Int = Int
object PositiveInt:
  def apply(n: Int): Either[String, PositiveInt] =
    if n > 0 then Right(n) else Left(s"Expected positive, got $n")

// -------------------------------------------------------------------------- //
// Enums (Scala 3)
// -------------------------------------------------------------------------- //

enum Status:
  case Pending, Running, Done, Failed

  def isTerminal: Boolean = this == Done || this == Failed
  def label: String = this match
    case Pending => "Waiting"
    case Running => "In progress"
    case Done    => "Completed"
    case Failed  => "Failed"

enum Result[+T]:
  case Success(value: T)
  case Failure(error: Throwable)
  case Loading

  def map[U](f: T => U): Result[U] = this match
    case Success(v) => Success(f(v))
    case Failure(e) => Failure(e)
    case Loading    => Loading

  def getOrElse[U >: T](default: => U): U = this match
    case Success(v) => v
    case _          => default

// -------------------------------------------------------------------------- //
// Case classes & companion objects
// -------------------------------------------------------------------------- //

case class Point(x: Double, y: Double):
  def distanceTo(other: Point): Double =
    math.sqrt(math.pow(x - other.x, 2) + math.pow(y - other.y, 2))

  def +(other: Point): Point = Point(x + other.x, y + other.y)
  def *(scale: Double): Point = Point(x * scale, y * scale)

object Point:
  val origin: Point = Point(0, 0)

case class User(
  id: Uuid,
  name: String,
  email: String,
  role: String = "member"
)

// -------------------------------------------------------------------------- //
// Traits & type classes
// -------------------------------------------------------------------------- //

trait Repository[F[_], T]:
  def findById(id: Uuid): F[Option[T]]
  def list: F[List[T]]
  def save(entity: T): F[T]
  def delete(id: Uuid): F[Boolean]

trait Show[T]:
  def show(value: T): String

trait Eq[T]:
  def eqv(a: T, b: T): Boolean

trait Ord[T] extends Eq[T]:
  def compare(a: T, b: T): Int
  def eqv(a: T, b: T): Boolean = compare(a, b) == 0
  def lt(a: T, b: T): Boolean  = compare(a, b) < 0
  def gt(a: T, b: T): Boolean  = compare(a, b) > 0

// -------------------------------------------------------------------------- //
// Given instances (type class instances)
// -------------------------------------------------------------------------- //

given Show[Int] with
  def show(n: Int): String = n.toString

given Show[String] with
  def show(s: String): String = s""""$s""""

given Show[User] with
  def show(u: User): String = s"User(${u.name}, ${u.email})"

given [T: Show]: Show[List[T]] with
  def show(xs: List[T]): String =
    xs.map(summon[Show[T]].show).mkString("[", ", ", "]")

given Ord[Int] with
  def compare(a: Int, b: Int): Int = java.lang.Integer.compare(a, b)

given Ord[String] with
  def compare(a: String, b: String): Int = a.compareTo(b)

// -------------------------------------------------------------------------- //
// Extension methods
// -------------------------------------------------------------------------- //

extension [T: Show](value: T)
  def display: String = summon[Show[T]].show(value)

extension (s: String)
  def isValidEmail: Boolean = s.contains('@') && s.contains('.')
  def camelToSnake: String =
    "[A-Z]".r.replaceAllIn(s, m => s"_${m.matched.toLowerCase}").stripPrefix("_")

extension [T](xs: List[T])
  def safeHead: Option[T] = xs.headOption
  def safeLast: Option[T] = xs.lastOption
  def groupByKey[K](f: T => K): Map[K, List[T]] = xs.groupBy(f)

// -------------------------------------------------------------------------- //
// Context functions (using parameters)
// -------------------------------------------------------------------------- //

def showAll[T: Show](items: List[T]): String =
  items.map(_.display).mkString(", ")

def sortWith[T: Ord](xs: List[T]): List[T] =
  val ord = summon[Ord[T]]
  xs.sortWith((a, b) => ord.lt(a, b))

// -------------------------------------------------------------------------- //
// Union & intersection types
// -------------------------------------------------------------------------- //

type StringOrInt = String | Int
type Named = { def name: String }

def stringify(v: StringOrInt): String = v match
  case s: String => s
  case n: Int    => n.toString

// -------------------------------------------------------------------------- //
// Match types
// -------------------------------------------------------------------------- //

type Elem[T] = T match
  case List[t]  => t
  case Option[t] => t
  case _         => T

// -------------------------------------------------------------------------- //
// For-comprehensions & Option/Either
// -------------------------------------------------------------------------- //

def safeDivide(a: Int, b: Int): Either[String, Int] =
  if b == 0 then Left(s"Division by zero: $a / $b")
  else Right(a / b)

def computeRatio(x: Int, y: Int, z: Int): Either[String, Double] =
  for
    sum  <- safeDivide(x + y, 2)
    prod <- safeDivide(sum, z)
  yield prod.toDouble

// -------------------------------------------------------------------------- //
// Pattern matching (advanced)
// -------------------------------------------------------------------------- //

def describe(value: Any): String = value match
  case null              => "null"
  case n: Int if n < 0  => s"negative int $n"
  case n: Int           => s"non-negative int $n"
  case s: String        => s"string(${s.length})"
  case Point(0, 0)      => "origin"
  case Point(x, y)      => s"point($x, $y)"
  case xs: List[?]      => s"list of ${xs.size} items"
  case Some(v)          => s"some($v)"
  case None             => "none"
  case _                => s"unknown: ${value.getClass.getSimpleName}"

// -------------------------------------------------------------------------- //
// Futures
// -------------------------------------------------------------------------- //

def fetchData(url: String)(using ec: ExecutionContext): Future[String] =
  Future { s"data from $url" }

def fetchAll(urls: List[String])(using ec: ExecutionContext): Future[List[String]] =
  Future.sequence(urls.map(fetchData))

// -------------------------------------------------------------------------- //
// Lazy val & higher-kinded
// -------------------------------------------------------------------------- //

lazy val expensiveValue: Int = {
  println("computed!")
  42
}

def lift[F[_], A, B](f: A => B)(using ev: F[A] => F[B]): F[A] => F[B] = ev

// -------------------------------------------------------------------------- //
// Fibonacci via infinite LazyList
// -------------------------------------------------------------------------- //

lazy val fibonacci: LazyList[Long] =
  def go(a: Long, b: Long): LazyList[Long] = a #:: go(b, a + b)
  go(0, 1)

// -------------------------------------------------------------------------- //
// Entry point
// -------------------------------------------------------------------------- //

@main def run(): Unit =
  val user = User(Uuid("u1"), "Alice", "alice@example.com")
  println(user.display)

  val fibs = fibonacci.take(10).toList
  println(fibs.display)

  val p = Point(3, 4)
  println(s"Distance: ${p.distanceTo(Point.origin)}")

  println(sortWith(List(3, 1, 4, 1, 5, 9, 2)))

  computeRatio(10, 20, 5) match
    case Right(v)  => println(s"ratio = $v")
    case Left(err) => println(s"error: $err")
