module RationalHalfspace.Types
  ( Fraction(..), Input(..), Budget(..), defaultBudget
  , InputError(..), BudgetReason(..), Failure(..), Result(..)
  , Checked(..), validateInput, validateBudget
  ) where

import Data.Ratio ((%))

data Fraction = Fraction Integer Integer deriving (Eq, Show)
data Input = Input
  { variables :: Int
  , coefficients :: [[Fraction]]
  , bounds :: [Fraction]
  } deriving (Eq, Show)

data Budget = Budget
  { rowLimit :: Int
  , pairLimit :: Int
  , componentBits :: Int
  } deriving (Eq, Show)

defaultBudget :: Budget
defaultBudget = Budget 4096 200000 4096

data InputError
  = VariableCount | InequalityCount | DimensionMismatch
  | InvalidNumerator | InvalidDenominator | InvalidBudget
  | InvalidJSON | InputTooLarge | InvalidArguments
  deriving (Eq, Show)

data BudgetReason = RowLimit | PairLimit | BitLimit | OutputLimit
  deriving (Eq, Show)

data Failure = BadInput InputError | BudgetExceeded BudgetReason | InvariantFailure
  deriving (Eq, Show)

data Result
  = Feasible [Rational]
  | Infeasible [Rational]
  | UnknownBudget BudgetReason
  | InvalidInput InputError
  | CalculationError
  deriving (Eq, Show)

-- Checked input retains the original row order; it is not an elimination state.
data Checked = Checked Int [[Rational]] [Rational] deriving (Eq, Show)

validateBudget :: Budget -> Either Failure ()
validateBudget (Budget r p b)
  | r < 0 || r > 4096 || p < 0 || p > 200000 || b < 1 || b > 4096 =
      Left (BadInput InvalidBudget)
  | otherwise = Right ()

validateInput :: Input -> Either Failure Checked
validateInput (Input n a b)
  | n < 0 || n > 8 = Left (BadInput VariableCount)
  | length (take 33 a) > 32 || length (take 33 b) > 32 =
      Left (BadInput InequalityCount)
  | length a /= length b || any ((/= n) . length . take 9) a =
      Left (BadInput DimensionMismatch)
  | otherwise = Checked n <$> traverse (traverse fraction) a <*> traverse fraction b
  where
    fraction (Fraction x d)
      | d < 1 || d > 1000000 = Left (BadInput InvalidDenominator)
      | abs x > 1000000 = Left (BadInput InvalidNumerator)
      | otherwise = Right (x % d)
