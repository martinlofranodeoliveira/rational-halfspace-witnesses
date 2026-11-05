module RationalHalfspace.Verify (verifyPoint, verifyCertificate) where

import Control.Monad (forM, zipWithM)
import RationalHalfspace.Arithmetic
import RationalHalfspace.Types

-- This module does not import Solver, its rows, normalization, elimination,
-- history or back-substitution. It evaluates the original matrix directly.
prepare :: Budget -> Input -> Either Failure Checked
prepare budget input = do
  validateBudget budget
  checked@(Checked _ a b) <- validateInput input
  mapM_ (mapM_ (checkQ budget)) a
  mapM_ (checkQ budget) b
  pure checked

verifyPoint :: Budget -> Input -> [Rational] -> Either Failure Bool
verifyPoint budget input point = do
  Checked n a b <- prepare budget input
  if length (take 9 point) /= n then pure False else do
    mapM_ (checkQ budget) point
    values <- traverse (\row -> sumProducts budget row point) a
    pure (and (zipWith (<=) values b))

verifyCertificate :: Budget -> Input -> [Rational] -> Either Failure Bool
verifyCertificate budget input weights = do
  Checked n a b <- prepare budget input
  if length (take 33 weights) /= length a then pure False else do
    mapM_ (checkQ budget) weights
    if any (< 0) weights then pure False else do
      -- Column evaluation deliberately uses the ORIGINAL rows, including
      -- discarded duplicates and constant rows.
      columns <- forM [0 .. n-1] $ \j ->
        sumProducts budget weights [row !! j | row <- a]
      rhsTerms <- zipWithM (mulQ budget) weights b
      rhs <- sumProducts budget rhsTerms (replicate (length rhsTerms) 1)
      pure (all (== 0) columns && rhs < 0)
