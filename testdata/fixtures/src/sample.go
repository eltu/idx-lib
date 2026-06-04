//go:build ignore

// sample.go — comprehensive Go syntax fixture for parser testing.
// Covers: packages, imports, constants, iota, structs, interfaces, embedding,
// generics, goroutines, channels, select, defer, panic/recover, closures,
// type assertions, type switches, init functions, build constraints.

package sample

import (
	"context"
	"errors"
	"fmt"
	"io"
	"iter"
	"log/slog"
	"math"
	"sync"
	"time"
)

// -------------------------------------------------------------------------- //
// Constants & iota
// -------------------------------------------------------------------------- //

const (
	MaxRetries      = 3
	DefaultTimeout  = 30 * time.Second
	KiB        int64 = 1 << (10 * (iota + 1))
	MiB
	GiB
)

type Status int

const (
	StatusPending Status = iota
	StatusRunning
	StatusDone
	StatusFailed
)

func (s Status) String() string {
	switch s {
	case StatusPending:
		return "pending"
	case StatusRunning:
		return "running"
	case StatusDone:
		return "done"
	case StatusFailed:
		return "failed"
	default:
		return fmt.Sprintf("Status(%d)", int(s))
	}
}

func (s Status) IsTerminal() bool {
	return s == StatusDone || s == StatusFailed
}

// -------------------------------------------------------------------------- //
// Errors
// -------------------------------------------------------------------------- //

var (
	ErrNotFound   = errors.New("not found")
	ErrValidation = errors.New("validation error")
)

type AppError struct {
	Code    string
	Message string
	Cause   error
}

func (e *AppError) Error() string { return fmt.Sprintf("[%s] %s", e.Code, e.Message) }
func (e *AppError) Unwrap() error { return e.Cause }

func newNotFound(resource, id string) *AppError {
	return &AppError{
		Code:    "NOT_FOUND",
		Message: fmt.Sprintf("%s with id=%q not found", resource, id),
		Cause:   ErrNotFound,
	}
}

// -------------------------------------------------------------------------- //
// Interfaces
// -------------------------------------------------------------------------- //

// Writer is the single-method write port.
type Writer[T any] interface {
	Write(ctx context.Context, value T) error
}

// Reader is the single-method read port.
type Reader[T any] interface {
	Read(ctx context.Context, id string) (T, error)
}

// Repository combines read and write operations for an entity.
type Repository[T any] interface {
	Reader[T]
	Writer[T]
	Delete(ctx context.Context, id string) error
	List(ctx context.Context) ([]T, error)
}

// -------------------------------------------------------------------------- //
// Structs & embedding
// -------------------------------------------------------------------------- //

type BaseEntity struct {
	ID        string
	CreatedAt time.Time
	UpdatedAt time.Time
}

func newBase(id string) BaseEntity {
	now := time.Now().UTC()
	return BaseEntity{ID: id, CreatedAt: now, UpdatedAt: now}
}

type User struct {
	BaseEntity
	Name  string
	Email string
	Role  string
}

func NewUser(id, name, email string) (*User, error) {
	if id == "" {
		return nil, fmt.Errorf("user id: %w", ErrValidation)
	}
	if name == "" || email == "" {
		return nil, fmt.Errorf("user name/email: %w", ErrValidation)
	}
	return &User{BaseEntity: newBase(id), Name: name, Email: email, Role: "member"}, nil
}

// -------------------------------------------------------------------------- //
// Generics
// -------------------------------------------------------------------------- //

type Number interface {
	~int | ~int8 | ~int16 | ~int32 | ~int64 |
		~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 |
		~float32 | ~float64
}

func Sum[T Number](vals []T) T {
	var total T
	for _, v := range vals {
		total += v
	}
	return total
}

func Map[T, U any](slice []T, fn func(T) U) []U {
	result := make([]U, len(slice))
	for i, v := range slice {
		result[i] = fn(v)
	}
	return result
}

func Filter[T any](slice []T, pred func(T) bool) []T {
	var out []T
	for _, v := range slice {
		if pred(v) {
			out = append(out, v)
		}
	}
	return out
}

// -------------------------------------------------------------------------- //
// In-memory repository
// -------------------------------------------------------------------------- //

type MemoryStore[T any] struct {
	mu    sync.RWMutex
	items map[string]T
	keyFn func(T) string
}

func NewMemoryStore[T any](keyFn func(T) string) *MemoryStore[T] {
	return &MemoryStore[T]{items: make(map[string]T), keyFn: keyFn}
}

func (s *MemoryStore[T]) Write(_ context.Context, value T) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.items[s.keyFn(value)] = value
	return nil
}

func (s *MemoryStore[T]) Read(_ context.Context, id string) (T, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	v, ok := s.items[id]
	if !ok {
		return v, ErrNotFound
	}
	return v, nil
}

func (s *MemoryStore[T]) Delete(_ context.Context, id string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.items, id)
	return nil
}

func (s *MemoryStore[T]) List(_ context.Context) ([]T, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	out := make([]T, 0, len(s.items))
	for _, v := range s.items {
		out = append(out, v)
	}
	return out, nil
}

// -------------------------------------------------------------------------- //
// Goroutines, channels, select
// -------------------------------------------------------------------------- //

func FanOut[T any](ctx context.Context, in <-chan T, n int) []<-chan T {
	outs := make([]chan T, n)
	for i := range outs {
		outs[i] = make(chan T)
	}
	go func() {
		defer func() {
			for _, ch := range outs {
				close(ch)
			}
		}()
		i := 0
		for {
			select {
			case <-ctx.Done():
				return
			case v, ok := <-in:
				if !ok {
					return
				}
				outs[i%n] <- v
				i++
			}
		}
	}()
	result := make([]<-chan T, n)
	for i, ch := range outs {
		result[i] = ch
	}
	return result
}

func Merge[T any](ctx context.Context, chans ...<-chan T) <-chan T {
	out := make(chan T)
	var wg sync.WaitGroup
	forward := func(ch <-chan T) {
		defer wg.Done()
		for {
			select {
			case <-ctx.Done():
				return
			case v, ok := <-ch:
				if !ok {
					return
				}
				out <- v
			}
		}
	}
	wg.Add(len(chans))
	for _, ch := range chans {
		go forward(ch)
	}
	go func() {
		wg.Wait()
		close(out)
	}()
	return out
}

// -------------------------------------------------------------------------- //
// Defer, panic, recover
// -------------------------------------------------------------------------- //

func safeExec(fn func()) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("panic: %v", r)
		}
	}()
	fn()
	return nil
}

// -------------------------------------------------------------------------- //
// Closures
// -------------------------------------------------------------------------- //

func fibonacci() func() int {
	a, b := 0, 1
	return func() int {
		v := a
		a, b = b, a+b
		return v
	}
}

func memoize[T comparable, U any](fn func(T) U) func(T) U {
	cache := make(map[T]U)
	var mu sync.Mutex
	return func(arg T) U {
		mu.Lock()
		defer mu.Unlock()
		if v, ok := cache[arg]; ok {
			return v
		}
		v := fn(arg)
		cache[arg] = v
		return v
	}
}

// -------------------------------------------------------------------------- //
// Type assertions & type switches
// -------------------------------------------------------------------------- //

func describe(v any) string {
	switch x := v.(type) {
	case nil:
		return "nil"
	case bool:
		return fmt.Sprintf("bool(%v)", x)
	case int:
		return fmt.Sprintf("int(%d)", x)
	case float64:
		return fmt.Sprintf("float64(%g)", x)
	case string:
		return fmt.Sprintf("string(%q)", x)
	case error:
		return fmt.Sprintf("error(%s)", x.Error())
	case fmt.Stringer:
		return fmt.Sprintf("stringer(%s)", x.String())
	default:
		return fmt.Sprintf("unknown(%T)", v)
	}
}

// -------------------------------------------------------------------------- //
// Iterators (Go 1.23 range-over-func)
// -------------------------------------------------------------------------- //

func Pairs[T any](slice []T) iter.Seq2[int, T] {
	return func(yield func(int, T) bool) {
		for i, v := range slice {
			if !yield(i, v) {
				return
			}
		}
	}
}

// -------------------------------------------------------------------------- //
// Struct methods with value & pointer receivers
// -------------------------------------------------------------------------- //

type Vector struct {
	X, Y, Z float64
}

func (v Vector) Length() float64 {
	return math.Sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z)
}

func (v Vector) Add(other Vector) Vector {
	return Vector{v.X + other.X, v.Y + other.Y, v.Z + other.Z}
}

func (v *Vector) Scale(factor float64) {
	v.X *= factor
	v.Y *= factor
	v.Z *= factor
}

func (v Vector) String() string {
	return fmt.Sprintf("Vector(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
}

// -------------------------------------------------------------------------- //
// io interfaces
// -------------------------------------------------------------------------- //

type nopCloser struct{ io.Reader }

func (nopCloser) Close() error { return nil }

// NopCloser wraps a Reader adding a no-op Close method.
func NopCloser(r io.Reader) io.ReadCloser { return nopCloser{r} }

// -------------------------------------------------------------------------- //
// init
// -------------------------------------------------------------------------- //

var defaultLogger *slog.Logger

func init() {
	defaultLogger = slog.Default()
}
