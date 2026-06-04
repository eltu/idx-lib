{- |
  sample.hs — comprehensive Haskell syntax fixture for parser testing.
  Covers: ADTs, typeclasses, instances, records, monads, do-notation,
  functors, applicatives, type families, GADTs, deriving, lenses,
  concurrency primitives, pattern matching, guards, where/let clauses.
-}

{-# LANGUAGE DeriveFunctor         #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RecordWildCards       #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TupleSections         #-}
{-# LANGUAGE TypeFamilies          #-}

module Sample where

import Control.Concurrent       (MVar, newMVar, modifyMVar_, readMVar)
import Control.Exception        (SomeException, try, throwIO, Exception)
import Control.Monad            (forM, guard, when, unless)
import Control.Monad.IO.Class   (MonadIO, liftIO)
import Control.Monad.State      (StateT, evalStateT, get, modify, put)
import Control.Monad.Trans      (lift)
import Data.Char                (isAlpha, toUpper)
import Data.List                (foldl', group, isPrefixOf, nub, sort, sortOn)
import Data.Map.Strict          (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe               (fromMaybe, mapMaybe)
import Data.Set                 (Set)
import qualified Data.Set as Set

-- -------------------------------------------------------------------------- --
-- Constants
-- -------------------------------------------------------------------------- --

maxRetries :: Int
maxRetries = 3

-- -------------------------------------------------------------------------- --
-- Algebraic Data Types
-- -------------------------------------------------------------------------- --

data Status = Pending | Running | Done | Failed
  deriving (Show, Eq, Ord, Enum, Bounded)

isTerminal :: Status -> Bool
isTerminal s = s `elem` [Done, Failed]

data Result a
  = Success a
  | Failure String
  | Loading
  deriving (Show, Eq, Functor)

instance Applicative Result where
  pure = Success
  Success f <*> Success x = Success (f x)
  Failure e <*> _         = Failure e
  _         <*> Failure e = Failure e
  Loading   <*> _         = Loading
  _         <*> Loading   = Loading

instance Monad Result where
  Success x >>= f = f x
  Failure e >>= _ = Failure e
  Loading   >>= _ = Loading

-- -------------------------------------------------------------------------- --
-- Records
-- -------------------------------------------------------------------------- --

data User = User
  { userId    :: String
  , userName  :: String
  , userEmail :: String
  , userRole  :: String
  } deriving (Show, Eq)

mkUser :: String -> String -> String -> Either String User
mkUser uid name email
  | null name        = Left $ "name must not be empty"
  | '@' `notElem` email = Left $ "invalid email: " <> email
  | otherwise        = Right User
      { userId    = uid
      , userName  = name
      , userEmail = email
      , userRole  = "member"
      }

-- -------------------------------------------------------------------------- --
-- Typeclasses
-- -------------------------------------------------------------------------- --

class Describable a where
  describe :: a -> String

class (Show a) => Validate a where
  validate :: a -> Either String a

instance Describable Status where
  describe Pending = "Waiting to start"
  describe Running = "In progress"
  describe Done    = "Completed"
  describe Failed  = "Failed"

instance Validate User where
  validate u
    | null (userName u)        = Left "name is empty"
    | '@' `notElem` userEmail u = Left "invalid email"
    | otherwise                = Right u

-- -------------------------------------------------------------------------- --
-- GADTs
-- -------------------------------------------------------------------------- --

data Expr a where
  Lit  :: Int          -> Expr Int
  Bool :: Bool         -> Expr Bool
  Add  :: Expr Int -> Expr Int -> Expr Int
  Mul  :: Expr Int -> Expr Int -> Expr Int
  If   :: Expr Bool -> Expr a -> Expr a -> Expr a
  Eq   :: (Eq a) => Expr a -> Expr a -> Expr Bool

eval :: Expr a -> a
eval (Lit n)      = n
eval (Bool b)     = b
eval (Add e1 e2)  = eval e1 + eval e2
eval (Mul e1 e2)  = eval e1 * eval e2
eval (If c t e)   = if eval c then eval t else eval e
eval (Eq e1 e2)   = eval e1 == eval e2

-- -------------------------------------------------------------------------- --
-- Type families
-- -------------------------------------------------------------------------- --

type family Elem c where
  Elem [a]     = a
  Elem (Set a) = a
  Elem (Map k v) = v

class Container f where
  empty  :: f a
  insert :: a -> f a -> f a
  toList :: f a -> [a]

-- -------------------------------------------------------------------------- --
-- Monadic code & do-notation
-- -------------------------------------------------------------------------- --

type AppState = Map String Int
type App m a = StateT AppState m a

incrementKey :: Monad m => String -> App m ()
incrementKey key = modify (Map.insertWith (+) key 1)

getCount :: Monad m => String -> App m Int
getCount key = fromMaybe 0 . Map.lookup key <$> get

runWordCount :: [String] -> AppState
runWordCount words = execStateT (mapM_ incrementKey words) Map.empty
  where execStateT action s = snd <$> undefined -- placeholder

-- -------------------------------------------------------------------------- --
-- Pattern matching & guards
-- -------------------------------------------------------------------------- --

classify :: (Ord a, Num a, Show a) => a -> String
classify n
  | n < 0     = "negative"
  | n == 0    = "zero"
  | n < 10    = "small"
  | n < 100   = "medium"
  | otherwise = "large"

describeList :: Show a => [a] -> String
describeList xs = case xs of
  []     -> "empty list"
  [x]    -> "singleton: " <> show x
  [x, y] -> "pair: " <> show x <> ", " <> show y
  (x:_)  -> "list starting with " <> show x

-- -------------------------------------------------------------------------- --
-- Higher-order functions
-- -------------------------------------------------------------------------- --

fibonacci :: [Integer]
fibonacci = 0 : 1 : zipWith (+) fibonacci (tail fibonacci)

applyTwice :: (a -> a) -> a -> a
applyTwice f = f . f

mapMaybe2 :: (a -> Maybe b) -> [a] -> [b]
mapMaybe2 _ [] = []
mapMaybe2 f (x:xs) = case f x of
  Nothing -> mapMaybe2 f xs
  Just v  -> v : mapMaybe2 f xs

groupBy2 :: Ord k => (a -> k) -> [a] -> Map k [a]
groupBy2 f = foldl' step Map.empty
  where step acc x = Map.insertWith (++) (f x) [x] acc

-- -------------------------------------------------------------------------- --
-- Concurrency
-- -------------------------------------------------------------------------- --

newtype Counter = Counter (MVar Int)

newCounter :: IO Counter
newCounter = Counter <$> newMVar 0

increment :: Counter -> IO ()
increment (Counter v) = modifyMVar_ v (pure . (+1))

getCount2 :: Counter -> IO Int
getCount2 (Counter v) = readMVar v

-- -------------------------------------------------------------------------- --
-- Exception handling
-- -------------------------------------------------------------------------- --

data AppException = NotFound String | ValidationFailed String
  deriving (Show)

instance Exception AppException

safeDivide :: Int -> Int -> Either String Int
safeDivide _ 0 = Left "division by zero"
safeDivide a b = Right (a `div` b)

tryIO :: IO a -> IO (Either SomeException a)
tryIO = try

-- -------------------------------------------------------------------------- --
-- List comprehensions & monadic list
-- -------------------------------------------------------------------------- --

pythagorean :: Int -> [(Int, Int, Int)]
pythagorean n = do
  c <- [1..n]
  b <- [1..c]
  a <- [1..b]
  guard (a*a + b*b == c*c)
  return (a, b, c)

combinations :: [a] -> [b] -> [(a, b)]
combinations xs ys = [(x, y) | x <- xs, y <- ys]

-- -------------------------------------------------------------------------- --
-- Where & let
-- -------------------------------------------------------------------------- --

bmi :: Double -> Double -> String
bmi weight height =
  let bmiVal = weight / height ^ (2 :: Int)
  in classify' bmiVal
  where
    classify' b
      | b < 18.5  = "underweight"
      | b < 25.0  = "normal"
      | b < 30.0  = "overweight"
      | otherwise = "obese"

-- -------------------------------------------------------------------------- --
-- Entry point
-- -------------------------------------------------------------------------- --

main :: IO ()
main = do
  let user = mkUser "u1" "Alice" "alice@example.com"
  print user

  let fibs = take 10 fibonacci
  print fibs

  let triples = pythagorean 20
  print triples

  counter <- newCounter
  increment counter
  increment counter
  n <- getCount2 counter
  putStrLn $ "count = " <> show n

  let result = safeDivide 10 0
  case result of
    Left err -> putStrLn $ "error: " <> err
    Right v  -> print v
