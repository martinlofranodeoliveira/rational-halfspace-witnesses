module Main (main) where

import Control.Monad (unless)
import RationalHalfspace

-- Compiled from the source archive in an independent directory, using ONLY
-- an installed package environment, not -i paths into the source tree.
main :: IO ()
main = do
  let f n = Fraction n 1
      feasible = Input 1 [[f (-1)],[f 1]] [f (-1),f 2]
      impossible = Input 1 [[f 1],[f (-1)]] [f 0,f (-1)]
  unless (solve defaultBudget feasible == Feasible [1]) (fail "installed primal")
  unless (solve defaultBudget impossible == Infeasible [1,1]) (fail "installed dual")
  unless (verifyPoint defaultBudget feasible [1] == Right True) (fail "installed verifier")
  unless (solve (defaultBudget { pairLimit = 0 }) impossible == UnknownBudget PairLimit)
    (fail "installed budget")
  putStrLn "Independent installed-library consumer: PASS"
