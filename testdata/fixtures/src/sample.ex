# sample.ex — comprehensive Elixir syntax fixture for parser testing.
# Covers: modules, structs, protocols, behaviours, macros, pattern matching,
# pipe operator, recursion, comprehensions, processes, GenServer, tasks,
# typespecs, guards, with expressions, streams, ETS.

defmodule Sample do
  @moduledoc """
  Comprehensive Elixir syntax fixture covering idiomatic patterns.
  """

  # -------------------------------------------------------------------------- #
  # Module attributes (constants)
  # -------------------------------------------------------------------------- #

  @max_retries 3
  @default_timeout_ms 30_000
  @version "1.0.0"

  # -------------------------------------------------------------------------- #
  # Typespecs
  # -------------------------------------------------------------------------- #

  @type uuid :: String.t()
  @type status :: :pending | :running | :done | :failed
  @type result(t) :: {:ok, t} | {:error, String.t()}

  # -------------------------------------------------------------------------- #
  # Structs
  # -------------------------------------------------------------------------- #

  defmodule User do
    @moduledoc "Domain entity representing an application user."

    @enforce_keys [:id, :name, :email]
    defstruct [:id, :name, :email, role: "member", status: :pending]

    @type t :: %__MODULE__{
            id:     String.t(),
            name:   String.t(),
            email:  String.t(),
            role:   String.t(),
            status: Sample.status()
          }

    @spec new(String.t(), String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
    def new(id, name, email) do
      cond do
        String.trim(name) == "" -> {:error, "name must not be blank"}
        not String.contains?(email, "@") -> {:error, "email '#{email}' is invalid"}
        true -> {:ok, %__MODULE__{id: id, name: name, email: email}}
      end
    end
  end

  defmodule Point do
    @moduledoc "2-D geometric point."

    defstruct [:x, :y]

    @type t :: %__MODULE__{x: float(), y: float()}

    def origin, do: %__MODULE__{x: 0.0, y: 0.0}

    def distance(%__MODULE__{x: x1, y: y1}, %__MODULE__{x: x2, y: y2}) do
      :math.sqrt(:math.pow(x1 - x2, 2) + :math.pow(y1 - y2, 2))
    end

    defimpl String.Chars do
      def to_string(%{x: x, y: y}), do: "(#{x}, #{y})"
    end
  end

  # -------------------------------------------------------------------------- #
  # Protocols
  # -------------------------------------------------------------------------- #

  defprotocol Describable do
    @doc "Returns a human-readable description of the value."
    @spec describe(t()) :: String.t()
    def describe(value)
  end

  defimpl Describable, for: User do
    def describe(%User{name: name, email: email}),
      do: "User(#{name}, #{email})"
  end

  defimpl Describable, for: Point do
    def describe(%Point{x: x, y: y}), do: "Point(#{x}, #{y})"
  end

  # -------------------------------------------------------------------------- #
  # Behaviours
  # -------------------------------------------------------------------------- #

  defmodule Repository do
    @moduledoc "Repository port for persistence."

    @callback find_by_id(id :: String.t()) :: {:ok, term()} | {:error, :not_found}
    @callback list() :: list(term())
    @callback save(entity :: term()) :: {:ok, term()} | {:error, String.t()}
    @callback delete(id :: String.t()) :: :ok | {:error, :not_found}
  end

  # -------------------------------------------------------------------------- #
  # Pattern matching & guards
  # -------------------------------------------------------------------------- #

  @spec classify(term()) :: String.t()
  def classify(nil),                           do: "null"
  def classify(b) when is_boolean(b),          do: "boolean: #{b}"
  def classify(n) when is_integer(n) and n < 0, do: "negative int #{n}"
  def classify(n) when is_integer(n),           do: "non-negative int #{n}"
  def classify(s) when is_binary(s) and s == "", do: "empty string"
  def classify(s) when is_binary(s),            do: "string of length #{String.length(s)}"
  def classify([]),                             do: "empty list"
  def classify(l) when is_list(l),              do: "list of #{length(l)}"
  def classify(%{__struct__: mod}),             do: "struct #{mod}"
  def classify(_),                              do: "unknown"

  # -------------------------------------------------------------------------- #
  # Recursion & tail-call optimisation
  # -------------------------------------------------------------------------- #

  @spec factorial(non_neg_integer()) :: non_neg_integer()
  def factorial(n) when n >= 0, do: factorial(n, 1)

  defp factorial(0, acc), do: acc
  defp factorial(n, acc), do: factorial(n - 1, n * acc)

  @spec fibonacci(non_neg_integer()) :: [non_neg_integer()]
  def fibonacci(n), do: fib_acc(n, 0, 1, [])

  defp fib_acc(0, _, _, acc), do: Enum.reverse(acc)
  defp fib_acc(n, a, b, acc), do: fib_acc(n - 1, b, a + b, [a | acc])

  # -------------------------------------------------------------------------- #
  # Pipe operator & Enum
  # -------------------------------------------------------------------------- #

  @spec word_frequency(String.t()) :: %{String.t() => non_neg_integer()}
  def word_frequency(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> Enum.frequencies()
  end

  @spec top_n(map(), non_neg_integer()) :: [{String.t(), non_neg_integer()}]
  def top_n(freq, n) do
    freq
    |> Enum.sort_by(fn {_k, v} -> v end, :desc)
    |> Enum.take(n)
  end

  # -------------------------------------------------------------------------- #
  # For comprehensions
  # -------------------------------------------------------------------------- #

  @spec pythagorean(pos_integer()) :: [{pos_integer(), pos_integer(), pos_integer()}]
  def pythagorean(limit) do
    for c <- 1..limit,
        b <- 1..c,
        a <- 1..b,
        a * a + b * b == c * c,
        do: {a, b, c}
  end

  # -------------------------------------------------------------------------- #
  # with expression
  # -------------------------------------------------------------------------- #

  @spec process_user(map()) :: result(User.t())
  def process_user(params) do
    with {:ok, id}    <- Map.fetch(params, "id"),
         {:ok, name}  <- Map.fetch(params, "name"),
         {:ok, email} <- Map.fetch(params, "email"),
         {:ok, user}  <- User.new(id, name, email) do
      {:ok, user}
    else
      :error          -> {:error, "missing required field"}
      {:error, msg}   -> {:error, msg}
    end
  end

  # -------------------------------------------------------------------------- #
  # Streams (lazy evaluation)
  # -------------------------------------------------------------------------- #

  @spec fibonacci_stream() :: Enumerable.t()
  def fibonacci_stream do
    Stream.unfold({0, 1}, fn {a, b} -> {a, {b, a + b}} end)
  end

  @spec process_large_file(String.t()) :: Enumerable.t()
  def process_large_file(path) do
    path
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.with_index(1)
  end

  # -------------------------------------------------------------------------- #
  # Macros
  # -------------------------------------------------------------------------- #

  defmacro assert_ok(expr) do
    quote do
      case unquote(expr) do
        {:ok, value} -> value
        {:error, reason} -> raise "Expected {:ok, _}, got {:error, #{inspect(reason)}}"
      end
    end
  end

  # -------------------------------------------------------------------------- #
  # GenServer
  # -------------------------------------------------------------------------- #

  defmodule Counter do
    @moduledoc "Simple stateful counter implemented as a GenServer."

    use GenServer

    @spec start_link(non_neg_integer()) :: GenServer.on_start()
    def start_link(initial \\ 0) do
      GenServer.start_link(__MODULE__, initial, name: __MODULE__)
    end

    @spec increment(pid() | atom()) :: :ok
    def increment(pid \\ __MODULE__), do: GenServer.cast(pid, :increment)

    @spec value(pid() | atom()) :: non_neg_integer()
    def value(pid \\ __MODULE__),     do: GenServer.call(pid, :value)

    @spec reset(pid() | atom()) :: :ok
    def reset(pid \\ __MODULE__),     do: GenServer.cast(pid, :reset)

    # --- callbacks ---

    @impl true
    def init(initial), do: {:ok, initial}

    @impl true
    def handle_cast(:increment, count), do: {:noreply, count + 1}
    def handle_cast(:reset, _),         do: {:noreply, 0}

    @impl true
    def handle_call(:value, _from, count), do: {:reply, count, count}
  end

  # -------------------------------------------------------------------------- #
  # Tasks (async)
  # -------------------------------------------------------------------------- #

  @spec fetch_all(list(String.t())) :: list(term())
  def fetch_all(urls) do
    urls
    |> Enum.map(&Task.async(fn -> fetch_one(&1) end))
    |> Task.await_many(@default_timeout_ms)
  end

  defp fetch_one(url) do
    {:ok, "data from #{url}"}
  end

  # -------------------------------------------------------------------------- #
  # ETS (Erlang Term Storage)
  # -------------------------------------------------------------------------- #

  @spec create_cache(atom()) :: :ets.tid()
  def create_cache(name) do
    :ets.new(name, [:set, :public, :named_table, read_concurrency: true])
  end

  @spec cache_put(:ets.tid(), term(), term()) :: true
  def cache_put(table, key, value) do
    :ets.insert(table, {key, value, System.monotonic_time()})
  end

  @spec cache_get(:ets.tid(), term()) :: {:ok, term()} | :miss
  def cache_get(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value, _ts}] -> {:ok, value}
      [] -> :miss
    end
  end

  # -------------------------------------------------------------------------- #
  # Exception handling
  # -------------------------------------------------------------------------- #

  @spec safe_divide(number(), number()) :: result(float())
  def safe_divide(_, 0), do: {:error, "division by zero"}
  def safe_divide(a, b), do: {:ok, a / b}

  def with_rescue(fun) do
    try do
      {:ok, fun.()}
    rescue
      e in [ArithmeticError, ArgumentError] -> {:error, Exception.message(e)}
    catch
      :throw, reason -> {:error, "thrown: #{inspect(reason)}"}
    end
  end
end

# -------------------------------------------------------------------------- #
# Entry point (when run as script)
# -------------------------------------------------------------------------- #

case Sample.User.new("u1", "Alice", "alice@example.com") do
  {:ok, user}    -> IO.inspect(user, label: "user")
  {:error, msg}  -> IO.puts("Error: #{msg}")
end

IO.inspect(Sample.fibonacci(10), label: "fibonacci")
IO.inspect(Sample.pythagorean(20), label: "pythagorean")

p1 = %Sample.Point{x: 3.0, y: 4.0}
p2 = Sample.Point.origin()
IO.puts("Distance: #{Sample.Point.distance(p1, p2)}")
