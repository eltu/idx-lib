# frozen_string_literal: true

# sample.rb — comprehensive Ruby syntax fixture for parser testing.
# Covers: modules, classes, mixins, blocks, procs, lambdas, method_missing,
# metaprogramming, open classes, Comparable, Enumerable, Struct, Data,
# pattern matching, error handling, fibers, ractors comment, frozen strings.

require "forwardable"
require "set"

# --------------------------------------------------------------------------- #
# Constants & frozen literals
# --------------------------------------------------------------------------- #

MAX_RETRIES = 3
DEFAULT_TIMEOUT = 30.0
EMPTY_ARRAY = [].freeze
GREETING = "hello"

# --------------------------------------------------------------------------- #
# Modules (mixins)
# --------------------------------------------------------------------------- #

module Serializable
  def to_h
    instance_variables.each_with_object({}) do |var, hash|
      hash[var.to_s.delete_prefix("@").to_sym] = instance_variable_get(var)
    end
  end

  def to_json
    require "json"
    JSON.generate(to_h)
  end
end

module Validatable
  def self.included(base)
    base.extend(ClassMethods)
    base.instance_variable_set(:@validations, [])
  end

  module ClassMethods
    def validates(attr, **options)
      @validations ||= []
      @validations << { attr: attr, **options }
    end

    def validations = @validations || []
  end

  def valid?
    self.class.validations.all? do |rule|
      val = send(rule[:attr])
      !rule[:presence] || (val && !val.to_s.empty?)
    end
  end
end

# --------------------------------------------------------------------------- #
# Struct & Data (Ruby 3.2+)
# --------------------------------------------------------------------------- #

Point = Data.define(:x, :y) do
  def distance_to(other)
    Math.sqrt((x - other.x)**2 + (y - other.y)**2)
  end

  def origin? = x.zero? && y.zero?
end

Config = Struct.new(:host, :port, :debug, keyword_init: true) do
  def base_url = "http://#{host}:#{port}"
end

# --------------------------------------------------------------------------- #
# Enumerations via Symbol
# --------------------------------------------------------------------------- #

module Status
  ALL = %i[pending running done failed].freeze

  def self.terminal?(status)
    status == :done || status == :failed
  end

  def self.valid?(status)
    ALL.include?(status)
  end
end

# --------------------------------------------------------------------------- #
# Classes with inheritance & Comparable
# --------------------------------------------------------------------------- #

class Animal
  include Comparable
  include Serializable

  attr_reader :name, :weight_kg

  @@count = 0

  def initialize(name, weight_kg)
    @name = name.freeze
    @weight_kg = weight_kg.to_f
    @@count += 1
  end

  def self.count = @@count

  def speak
    raise NotImplementedError, "#{self.class} must implement #speak"
  end

  def weight_lbs = @weight_kg * 2.205

  def <=>(other)
    return nil unless other.is_a?(Animal)

    weight_kg <=> other.weight_kg
  end

  def to_s = "#{self.class.name}(#{@name})"
  def inspect = "#<#{self.class.name} name=#{@name.inspect} weight=#{@weight_kg}>"
end

class Dog < Animal
  include Validatable
  validates :name, presence: true

  attr_reader :breed

  def initialize(name, weight_kg, breed:)
    super(name, weight_kg)
    @breed = breed.freeze
    @tricks = []
  end

  def speak = "woof"

  def learn(trick)
    @tricks << trick.to_sym
    self
  end

  def perform = @tricks.map { |t| "#{name} performs #{t}" }
end

# --------------------------------------------------------------------------- #
# Blocks, procs, lambdas
# --------------------------------------------------------------------------- #

def retry_block(attempts: MAX_RETRIES)
  attempts.times do |i|
    return yield i
  rescue StandardError => e
    raise if i == attempts - 1

    sleep(0.01 * 2**i)
  end
end

square = ->(x) { x**2 }
cube   = proc { |x| x**3 }
add    = method(:puts).to_proc

pipeline = ->(val, *fns) { fns.reduce(val) { |v, f| f.call(v) } }

# --------------------------------------------------------------------------- #
# Enumerables & lazy enumerators
# --------------------------------------------------------------------------- #

module EnumerableHelpers
  def self.fibonacci
    Enumerator.new do |yielder|
      a, b = 0, 1
      loop do
        yielder << a
        a, b = b, a + b
      end
    end.lazy
  end

  def self.group_by_first_char(words)
    words.group_by { |w| w[0]&.downcase }
         .transform_values(&:sort)
  end
end

# --------------------------------------------------------------------------- #
# Method missing & respond_to_missing?
# --------------------------------------------------------------------------- #

class FlexiStruct
  def initialize(**attrs)
    @data = attrs
  end

  def method_missing(name, *args)
    key = name.to_s.chomp("=").to_sym
    if name.to_s.end_with?("=")
      @data[key] = args.first
    elsif @data.key?(key)
      @data[key]
    else
      super
    end
  end

  def respond_to_missing?(name, include_private = false)
    @data.key?(name.to_s.chomp("=").to_sym) || super
  end
end

# --------------------------------------------------------------------------- #
# Open classes (monkey patching)
# --------------------------------------------------------------------------- #

class Integer
  def factorial
    return 1 if zero?

    (1..self).reduce(:*)
  end

  def times_map(&block)
    Array.new(self) { |i| block.call(i) }
  end
end

class String
  def camel_to_snake
    gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .downcase
  end
end

# --------------------------------------------------------------------------- #
# Exception hierarchy
# --------------------------------------------------------------------------- #

class AppError < StandardError
  attr_reader :code

  def initialize(message, code:)
    super(message)
    @code = code
  end
end

class NotFoundError < AppError
  def initialize(resource, id)
    super("#{resource} with id=#{id.inspect} not found", code: "NOT_FOUND")
  end
end

class ValidationError < AppError
  attr_reader :field

  def initialize(field, detail)
    super("#{field}: #{detail}", code: "VALIDATION_ERROR")
    @field = field
  end
end

# --------------------------------------------------------------------------- #
# Fibers
# --------------------------------------------------------------------------- #

def fibonacci_fiber
  Fiber.new do
    a, b = 0, 1
    loop do
      Fiber.yield(a)
      a, b = b, a + b
    end
  end
end

# --------------------------------------------------------------------------- #
# Pattern matching (Ruby 3+)
# --------------------------------------------------------------------------- #

def classify_response(response)
  case response
  in { status: 200, body: String => body }
    "OK: #{body[..20]}"
  in { status: (400..499), error: String => msg }
    "Client error: #{msg}"
  in { status: (500..), error: }
    "Server error: #{error}"
  in { status: Integer => code }
    "HTTP #{code}"
  else
    "Unknown response"
  end
end

# --------------------------------------------------------------------------- #
# Forwardable
# --------------------------------------------------------------------------- #

class Stack
  extend Forwardable

  def_delegators :@data, :size, :empty?, :last

  def initialize
    @data = []
  end

  def push(item)
    @data.push(item)
    self
  end

  def pop = @data.pop
end

# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #

if __FILE__ == $PROGRAM_NAME
  dog = Dog.new("Rex", 30, breed: "Labrador")
  puts dog.speak
  puts dog.learn(:sit).learn(:shake).perform

  fibs = EnumerableHelpers.fibonacci.take(10)
  p fibs

  fib = fibonacci_fiber
  10.times { print "#{fib.resume} " }
  puts

  puts 10.factorial
  puts "CamelCase".camel_to_snake

  p Point.new(x: 3, y: 4).distance_to(Point.new(x: 0, y: 0))
end
