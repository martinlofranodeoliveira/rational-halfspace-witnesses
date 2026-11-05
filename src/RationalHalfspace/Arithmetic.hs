module RationalHalfspace.Arithmetic
  ( checkQ, addQ, subQ, mulQ, divQ, sumProducts ) where

import Control.Monad (foldM)
import Data.Bits (shiftL)
import Data.Ratio (numerator, denominator, (%))
import RationalHalfspace.Types

-- Every operator checks normalized operands BEFORE doing integer arithmetic.
-- For B-bit operands, products have at most 2B bits and an addition of
-- two such products has at most 2B+1 bits. No unbounded fold precedes a check.
within :: Int -> Integer -> Bool
within bits x = abs x < (1 `shiftL` bits)

checkQ :: Budget -> Rational -> Either Failure Rational
checkQ budget q
  | within b (numerator q) && within b (denominator q) = Right q
  | otherwise = Left (BudgetExceeded BitLimit)
  where b = componentBits budget

finish :: Budget -> Integer -> Integer -> Either Failure Rational
finish budget n d
  | d == 0 = Left InvariantFailure
  | not (within (2*b+1) n && within (2*b) d) = Left InvariantFailure
  | otherwise = checkQ budget (n % d)
  where b = componentBits budget

addQ :: Budget -> Rational -> Rational -> Either Failure Rational
addQ budget x y = do
  a <- checkQ budget x
  b <- checkQ budget y
  finish budget
    (numerator a * denominator b + numerator b * denominator a)
    (denominator a * denominator b)

subQ :: Budget -> Rational -> Rational -> Either Failure Rational
subQ budget a b = addQ budget a (negate b)

mulQ :: Budget -> Rational -> Rational -> Either Failure Rational
mulQ budget x y = do
  a <- checkQ budget x
  b <- checkQ budget y
  finish budget (numerator a * numerator b) (denominator a * denominator b)

divQ :: Budget -> Rational -> Rational -> Either Failure Rational
divQ budget x y = do
  a <- checkQ budget x
  b <- checkQ budget y
  if b == 0 then Left InvariantFailure else
    finish budget (numerator a * denominator b) (denominator a * numerator b)

sumProducts :: Budget -> [Rational] -> [Rational] -> Either Failure Rational
sumProducts budget xs ys
  | length xs /= length ys = Left InvariantFailure
  | otherwise = foldM step 0 (zip xs ys)
  where
    step acc (a,b) = mulQ budget a b >>= addQ budget acc
