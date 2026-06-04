# sample.r — comprehensive R syntax fixture for parser testing.
# Covers: vectors, lists, data frames, functions, closures, S3/S4/R5 classes,
# environments, apply family, pipe operators, error handling, regex,
# tidyverse-style patterns, generics, recursion, metaprogramming.

# --------------------------------------------------------------------------- #
# Vectors & basic operations
# --------------------------------------------------------------------------- #

int_vec    <- 1:20
dbl_vec    <- c(1.5, 2.7, 3.14, NA, Inf)
chr_vec    <- c("alpha", "beta", "gamma")
lgl_vec    <- c(TRUE, FALSE, TRUE, NA)
cplx_vec   <- c(1+2i, 3-4i)

MAX_RETRIES <- 3L
PI_APPROX   <- 22 / 7

# Named vector
scores <- c(alice = 95, bob = 87, carol = 92)

# Sequence helpers
evens   <- seq(0, 100, by = 2)
five_pts <- seq(0, 1, length.out = 5)

# Vectorised operations (no loops needed)
normalized <- (int_vec - mean(int_vec)) / sd(int_vec)
above_mean <- int_vec[int_vec > mean(int_vec)]

# --------------------------------------------------------------------------- #
# Lists & nested structures
# --------------------------------------------------------------------------- #

person <- list(
  name    = "Alice",
  age     = 30L,
  hobbies = c("reading", "cycling"),
  address = list(city = "Berlin", country = "DE")
)

person$address$city        # $ accessor
person[["name"]]           # [[ accessor
person["age"]              # single-bracket returns list

# --------------------------------------------------------------------------- #
# Functions & closures
# --------------------------------------------------------------------------- #

make_adder <- function(n) {
  force(n)           # capture n now (avoid lazy-eval pitfall)
  function(x) x + n
}

add5 <- make_adder(5)

safe_log <- function(x, base = exp(1)) {
  if (any(x <= 0, na.rm = TRUE)) stop(paste0("x must be positive, got: ", x))
  log(x, base)
}

retry <- function(fn, times = MAX_RETRIES, ...) {
  last_err <- NULL
  for (i in seq_len(times)) {
    tryCatch(
      return(fn(...)),
      error = function(e) { last_err <<- e }
    )
  }
  stop(paste0("failed after ", times, " attempts: ", conditionMessage(last_err)))
}

# Recursive function
fibonacci <- function(n) {
  if (n <= 1L) return(n)
  fibonacci(n - 1L) + fibonacci(n - 2L)
}

fibonacci_vec <- Vectorize(fibonacci)

# --------------------------------------------------------------------------- #
# Apply family
# --------------------------------------------------------------------------- #

squares      <- sapply(1:10, function(x) x^2)
cube_list    <- lapply(1:5, function(x) x^3)
row_means    <- apply(matrix(1:12, nrow = 3), 1, mean)
named_double <- vapply(chr_vec, nchar, integer(1))

# --------------------------------------------------------------------------- #
# Data frames
# --------------------------------------------------------------------------- #

df <- data.frame(
  id     = 1:5,
  name   = c("Alice", "Bob", "Carol", "Dave", "Eve"),
  score  = c(92, 85, 78, 95, 88),
  passed = c(TRUE, TRUE, FALSE, TRUE, TRUE),
  stringsAsFactors = FALSE
)

# Subsetting
top_scorers   <- df[df$score >= 90, ]
name_and_score <- df[, c("name", "score")]

# Adding columns
df$grade <- ifelse(df$score >= 90, "A",
              ifelse(df$score >= 80, "B", "C"))

# Aggregate
avg_by_grade <- aggregate(score ~ grade, data = df, FUN = mean)

# --------------------------------------------------------------------------- #
# Pipe operator (|> native, R 4.1+)
# --------------------------------------------------------------------------- #

result <- c(3, 1, 4, 1, 5, 9, 2, 6) |>
  sort() |>
  unique() |>
  rev()

# --------------------------------------------------------------------------- #
# String manipulation
# --------------------------------------------------------------------------- #

greeting  <- sprintf("Hello, %s! You scored %d.", "Alice", 95)
upper     <- toupper(greeting)
words     <- strsplit("one two three", " ")[[1]]
matched   <- regmatches("2026-06-04", regexpr("\\d{4}-\\d{2}-\\d{2}", "2026-06-04"))
replaced  <- gsub("([aeiou])", "[\\1]", "hello world", perl = TRUE)

# --------------------------------------------------------------------------- #
# S3 Classes
# --------------------------------------------------------------------------- #

new_point <- function(x, y) {
  structure(list(x = x, y = y), class = "Point")
}

print.Point <- function(p, ...) {
  cat(sprintf("Point(%.2f, %.2f)\n", p$x, p$y))
}

distance.Point <- function(p, other) {
  sqrt((p$x - other$x)^2 + (p$y - other$y)^2)
}

`+.Point` <- function(a, b) new_point(a$x + b$x, a$y + b$y)

is_origin <- function(p) UseMethod("is_origin")
is_origin.Point <- function(p) p$x == 0 && p$y == 0

p1 <- new_point(3, 4)
p2 <- new_point(0, 0)

# --------------------------------------------------------------------------- #
# S4 Classes
# --------------------------------------------------------------------------- #

setClass("Animal", representation(
  name      = "character",
  weight_kg = "numeric",
  status    = "character"
))

setGeneric("speak", function(animal, ...) standardGeneric("speak"))
setGeneric("weight_lbs", function(animal) standardGeneric("weight_lbs"))

setMethod("speak", "Animal", function(animal, ...) {
  cat(animal@name, "says ...\n")
})

setMethod("weight_lbs", "Animal", function(animal) {
  animal@weight_kg * 2.205
})

setClass("Dog", contains = "Animal", representation(breed = "character"))

setMethod("speak", "Dog", function(animal, ...) {
  cat(animal@name, "says woof!\n")
})

rex <- new("Dog", name = "Rex", weight_kg = 30, status = "active", breed = "Lab")

# --------------------------------------------------------------------------- #
# R5 / Reference Classes
# --------------------------------------------------------------------------- #

Counter <- setRefClass("Counter",
  fields = list(count = "numeric"),
  methods = list(
    initialize = function(start = 0) {
      count <<- start
    },
    increment = function(by = 1) {
      count <<- count + by
    },
    reset = function() {
      count <<- 0
    },
    show = function() {
      cat("Counter:", count, "\n")
    }
  )
)

ctr <- Counter$new(10)

# --------------------------------------------------------------------------- #
# Environments & metaprogramming
# --------------------------------------------------------------------------- #

e <- new.env(parent = emptyenv())
assign("x", 42, envir = e)
get("x", envir = e)

# Quote & eval
expr <- quote(1 + 2 * 3)
eval(expr)

substitute_demo <- function(x) {
  deparse(substitute(x))
}

# --------------------------------------------------------------------------- #
# Error handling
# --------------------------------------------------------------------------- #

safe_divide <- function(a, b) {
  tryCatch(
    {
      if (b == 0) stop(paste0("division by zero: ", a, " / ", b))
      a / b
    },
    error   = function(e) { warning(conditionMessage(e)); NA_real_ },
    warning = function(w) { message("warn: ", conditionMessage(w)); NA_real_ },
    finally = { /* always runs */ }
  )
}

withCallingHandlers(
  log(-1),
  warning = function(w) {
    message("Caught warning: ", conditionMessage(w))
    invokeRestart("muffleWarning")
  }
)

# --------------------------------------------------------------------------- #
# Entry point (when run as script)
# --------------------------------------------------------------------------- #

if (!interactive()) {
  cat("Fibonacci(10) =", fibonacci(10), "\n")
  print(p1)
  cat("Distance:", distance.Point(p1, p2), "\n")
  speak(rex)
  ctr$increment(5)
  ctr$show()
}
