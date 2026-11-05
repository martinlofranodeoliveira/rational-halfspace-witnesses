{-# LANGUAGE BangPatterns #-}
module RationalHalfspace.Solver (solve) where

import Control.Monad (zipWithM)
import qualified Data.Map.Strict as M
import Data.List (find)
import RationalHalfspace.Arithmetic
import RationalHalfspace.JSON (resultFits)
import RationalHalfspace.Types
import RationalHalfspace.Verify

data Row = Row { lhs :: [Rational], rhs :: Rational, witness :: [Rational] }
type Table = M.Map ([Rational], Rational) Row
data Stage = Rows [Row] | Contradiction [Rational]

reserve :: Budget -> Int -> Int -> Either Failure ()
reserve b retained staging
  | retained + staging > rowLimit b = Left (BudgetExceeded RowLimit)
  | otherwise = Right ()

-- Only positive scaling is used. The witness is scaled by the SAME factor.
normalize :: Budget -> Row -> Either Failure Row
normalize b (Row a z w) = case find (/= 0) a of
  Nothing -> Left InvariantFailure
  Just first -> do
    let scale = abs first
    a' <- traverse (\x -> divQ b x scale) a
    z' <- divQ b z scale
    w' <- traverse (\x -> divQ b x scale) w
    pure (Row a' z' w')

insertRow :: Budget -> Row -> Table -> Either Failure (Either [Rational] Table)
insertRow b r table = do
  mapM_ (checkQ b) (lhs r)
  _ <- checkQ b (rhs r)
  mapM_ (checkQ b) (witness r)
  if all (== 0) (lhs r)
    then pure (if rhs r < 0 then Left (witness r) else Right table)
    else do
      normalized <- normalize b r
      let key = (lhs normalized, rhs normalized)
      -- First witness wins: traversal order, not hash iteration, decides ties.
      pure (Right (M.insertWith (\_ old -> old) key normalized table))

initial :: Budget -> Checked -> Either Failure Stage
initial b (Checked _ a zs) = go 0 M.empty (zip a zs)
  where
    m = length a
    go _ table [] = pure (Rows (M.elems table))
    go i table ((as,z):rest) = do
      -- Two slots cover a raw row and its normalized replacement, including
      -- the instant before duplicate reduction. The input matrix is not a
      -- second elimination-row collection.
      reserve b 0 (M.size table + 2)
      let r = Row as z [if j == i then 1 else 0 | j <- [0 .. m-1]]
      inserted <- insertRow b r table
      case inserted of
        Left cert -> pure (Contradiction cert)
        Right table' -> go (i+1) table' rest

combine :: Budget -> Int -> Row -> Row -> Either Failure Row
combine b k positive negative = do
  let p = lhs positive !! k
      q = negate (lhs negative !! k)
      component x y = do
        u <- mulQ b q x
        v <- mulQ b p y
        addQ b u v
  as <- zipWithM component (lhs positive) (lhs negative)
  z <- component (rhs positive) (rhs negative)
  ws <- zipWithM component (witness positive) (witness negative)
  pure (Row as z ws)

next :: Budget -> Int -> Int -> Int -> [Row] -> Either Failure (Stage, Int)
next b k retained pairs rows = do
  let positive = filter ((> 0) . (!! k) . lhs) rows
      negative = filter ((< 0) . (!! k) . lhs) rows
      zero = filter ((== 0) . (!! k) . lhs) rows
      count = length positive * length negative
  -- Reserve the whole deterministic pair batch BEFORE allocating candidates.
  if count > pairLimit b - pairs then Left (BudgetExceeded PairLimit) else do
    let candidates = map Left zero ++ [Right (p,q) | p <- positive, q <- negative]
    result <- go M.empty candidates
    pure (result, pairs + count)
  where
    go table [] = pure (Rows (M.elems table))
    go table (candidate:rest) = do
      reserve b retained (M.size table + 2)
      r <- case candidate of
        Left old -> pure old
        Right (p,q) -> combine b k p q
      inserted <- insertRow b r table
      case inserted of
        Left cert -> pure (Contradiction cert)
        Right table' -> go table' rest

backSubstitute :: Budget -> Int -> [(Int,[Row])] -> Either Failure [Rational]
backSubstitute b n history = go (replicate n 0) history
  where
    go point [] = pure point
    go point ((k,rows):rest) = do
      (lower,upper) <- interval point k rows Nothing Nothing
      case (lower,upper) of
        (Just l,Just u) | l > u -> Left InvariantFailure
        _ -> do
          let value = case lower of
                Just l | l > 0 -> l
                _ -> case upper of
                  Just u | u < 0 -> u
                  _ -> 0
          _ <- checkQ b value
          let point' = [if j == k then value else x | (j,x) <- zip [0..] point]
          go point' rest
    interval _ _ [] lo hi = pure (lo,hi)
    interval point k (r:rest) lo hi = do
      let c = lhs r !! k
      if c == 0 then interval point k rest lo hi else do
        others <- sumProducts b
          [if j == k then 0 else x | (j,x) <- zip [0..] (lhs r)] point
        available <- subQ b (rhs r) others
        edge <- divQ b available c
        if c > 0
          then interval point k rest lo (Just (maybe edge (min edge) hi))
          else interval point k rest (Just (maybe edge (max edge) lo)) hi

eliminate :: Budget -> Int -> [Row] -> Either Failure Result
eliminate b n first = go 0 first [] (length first) 0
  where
    go k active history !retained !pairs
      | k == n = Feasible <$> backSubstitute b n history
      | otherwise = do
          (stage,pairs') <- next b k retained pairs active
          case stage of
            Contradiction cert -> pure (Infeasible cert)
            Rows following -> go (k+1) following ((k,active):history)
              (retained + length following) pairs'

solve :: Budget -> Input -> Result
solve budget input = either failure id $ do
  validateBudget budget
  checked@(Checked n _ _) <- validateInput input
  stage <- initial budget checked
  candidate <- case stage of
    Contradiction cert -> pure (Infeasible cert)
    Rows rows -> eliminate budget n rows
  valid <- case candidate of
    Feasible point -> verifyPoint budget input point
    Infeasible cert -> verifyCertificate budget input cert
    _ -> Left InvariantFailure
  if not valid then Left InvariantFailure else
    pure (if resultFits candidate then candidate else UnknownBudget OutputLimit)
  where
    failure (BadInput err) = InvalidInput err
    failure (BudgetExceeded why) = UnknownBudget why
    failure InvariantFailure = CalculationError
