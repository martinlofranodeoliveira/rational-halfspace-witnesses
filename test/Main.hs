{-# LANGUAGE ForeignFunctionInterface #-}
module Main (main) where

import Control.Monad (forM_, unless)
import qualified Data.ByteString.Char8 as B
import Data.Ratio ((%), numerator, denominator)
import Foreign.C.String (CString, withCString)
import Foreign.C.Types (CInt(..))
import Foreign.Marshal.Array (withArray)
import Foreign.Marshal.Utils (withMany)
import Foreign.Ptr (Ptr)
import RationalHalfspace
import RationalHalfspace.JSON
import RationalHalfspace.Types (Checked(..), validateInput)

foreign import ccall safe "rhw_oracle"
  nativeOracle :: CInt -> CInt -> Ptr CString -> IO CInt

assert :: String -> Bool -> IO ()
assert label ok = unless ok (fail label)

eq :: (Eq a, Show a) => a -> a -> IO ()
eq expected actual = assert ("expected " ++ show expected ++ ", got " ++ show actual) (expected == actual)

f :: Integer -> Fraction
f x = Fraction x 1

system :: Int -> [[Integer]] -> [Integer] -> Input
system n a b = Input n (map (map f) a) (map f b)

oracle :: Input -> IO Int
oracle input = case validateInput input of
  Left err -> fail ("invalid oracle fixture: " ++ show err)
  Right (Checked n a b) -> do
    let text q = show (numerator q) ++ "/" ++ show (denominator q)
        values = map text (concat (zipWith (\row z -> row ++ [z]) a b))
    result <- withMany withCString values $ \strings ->
      withArray strings (nativeOracle (fromIntegral n) (fromIntegral (length a)))
    case result of
      1 -> pure 1
      -1 -> pure (-1)
      0 -> fail "oracle UNKNOWN: not SAT, UNSAT, or a passing negative test"
      _ -> fail "oracle rejected its fixed bounded fixture"

agreement :: Input -> IO ()
agreement input = do
  verdict <- oracle input
  case solve defaultBudget input of
    Feasible p -> do
      eq 1 verdict
      eq (Right True) (verifyPoint defaultBudget input p)
    Infeasible w -> do
      eq (-1) verdict
      eq (Right True) (verifyCertificate defaultBudget input w)
    other -> fail ("unexpected solver result: " ++ show other)

parallel :: Input
parallel = Input 1 [[f 1],[f (-1)]] [Fraction 1 3,Fraction (-1) 2]

triangle :: Input
triangle = system 2 [[1,1],[-1,0],[0,-1]] [1,-1,-1]

fixtures :: [Input]
fixtures =
  [ system 0 [] []
  , system 0 [[]] [0]
  , system 0 [[]] [-1]
  , system 3 [] []
  , system 1 [[1],[2],[-1]] [2,4,0]
  , parallel
  , triangle
  , system 2 [[-1,0],[0,-1],[1,1]] [0,0,1]
  ]

regressions :: [(String, IO ())]
regressions =
  [ ("empty point", eq (Feasible []) (solve defaultBudget (system 0 [] [])))
  , ("zero-dimensional contradiction", eq (Infeasible [1]) (solve defaultBudget (system 0 [[]] [-1])))
  , ("unconstrained coordinates", eq (Feasible [0,0,0]) (solve defaultBudget (system 3 [] [])))
  , ("negative coefficient lower bound", eq (Feasible [3%2])
      (solve defaultBudget (Input 1 [[f (-2)]] [f (-3)])))
  , ("positive normalization preserves dual scaling", eq (Infeasible [1%2,1%3])
      (solve defaultBudget (system 1 [[2],[-3]] [0,-3])))
  , ("duplicate first witness", eq (Infeasible [1,0,1])
      (solve defaultBudget (system 1 [[1],[2],[-1]] [0,0,-1])))
  , ("discarded tautological initial row preserves witness indices", eq (Infeasible [0,1,1])
      (solve defaultBudget (system 1 [[0],[1],[-1]] [1,0,-1])))
  , ("fraction normalization", eq (Feasible [1%2])
      (solve defaultBudget (Input 1 [[Fraction (-2) 4]] [Fraction (-2) 8])))
  , ("independent primal fixture", eq (Right True)
      (verifyPoint defaultBudget (last fixtures) [1%3,2%3]))
  , ("independent dual fixture", eq (Right True) (verifyCertificate defaultBudget triangle [1,1,1]))
  , ("reject false primal", eq (Right False) (verifyPoint defaultBudget triangle [0,0]))
  , ("reject positive noncancelling dual", eq (Right False) (verifyCertificate defaultBudget triangle [1,0,0]))
  , ("reject negative dual", eq (Right False) (verifyCertificate defaultBudget triangle [1,-1,1]))
  , ("reject zero dual", eq (Right False) (verifyCertificate defaultBudget triangle [0,0,0]))
  , ("reject wrong point arity", eq (Right False) (verifyPoint defaultBudget triangle [1]))
  , ("reject wrong certificate arity", eq (Right False) (verifyCertificate defaultBudget triangle [1]))
  , ("infinite row spine rejected", eq (InvalidInput InequalityCount)
      (solve defaultBudget (Input 0 (repeat []) [])))
  , ("infinite bound spine rejected", eq (InvalidInput InequalityCount)
      (solve defaultBudget (Input 0 [] (repeat (f 0)))))
  , ("infinite row width spine rejected", eq (InvalidInput DimensionMismatch)
      (solve defaultBudget (Input 1 [repeat (f 1)] [f 0])))
  , ("infinite point spine rejected", eq (Right False)
      (verifyPoint defaultBudget (system 1 [[1]] [0]) (repeat 0)))
  , ("infinite certificate spine rejected", eq (Right False)
      (verifyCertificate defaultBudget triangle (repeat 1)))
  , ("zero denominator", eq (InvalidInput InvalidDenominator)
      (solve defaultBudget (Input 1 [[Fraction 1 0]] [f 0])))
  , ("negative denominator", eq (InvalidInput InvalidDenominator)
      (solve defaultBudget (Input 1 [[Fraction 1 (-2)]] [f 0])))
  , ("oversize denominator", eq (InvalidInput InvalidDenominator)
      (solve defaultBudget (Input 0 [[]] [Fraction 0 1000001])))
  , ("oversize numerator", eq (InvalidInput InvalidNumerator)
      (solve defaultBudget (Input 0 [[]] [f 1000001])))
  , ("dimension mismatch", eq (InvalidInput DimensionMismatch)
      (solve defaultBudget (system 2 [[1]] [0])))
  , ("bound dimension mismatch", eq (InvalidInput DimensionMismatch)
      (solve defaultBudget (system 1 [[1]] [])))
  , ("variable ceiling", eq (InvalidInput VariableCount)
      (solve defaultBudget (system 9 [] [])))
  , ("inequality ceiling", eq (InvalidInput InequalityCount)
      (solve defaultBudget (system 0 (replicate 33 []) (replicate 33 0))))
  , ("invalid budget", eq (InvalidInput InvalidBudget)
      (solve (Budget 4097 1 1) (system 0 [] [])))
  , ("zero row capacity", eq (UnknownBudget RowLimit)
      (solve (Budget 0 200000 4096) parallel))
  , ("zero capacity empty system", eq (Feasible [])
      (solve (Budget 0 0 1) (system 0 [] [])))
  , ("staging counts retained rows", eq (UnknownBudget RowLimit)
      (solve (Budget 3 200000 4096) (system 2 [[1,1],[-1,1]] [1,1])))
  , ("pair ceiling exact", eq (UnknownBudget PairLimit)
      (solve (defaultBudget { pairLimit = 0 }) parallel))
  , ("input component bits", eq (UnknownBudget BitLimit)
      (solve (defaultBudget { componentBits = 1 }) (system 1 [[3]] [0])))
  , ("intermediate growth before cancellation", eq (UnknownBudget BitLimit)
      (solve (defaultBudget { componentBits = 2 }) (system 2 [[1,3],[-1,3]] [1,1])))
  , ("verifier exhaustion is typed", eq (Left (BudgetExceeded BitLimit))
      (verifyPoint (defaultBudget { componentBits = 1 }) (system 1 [[1]] [0]) [2]))
  , ("output budget fallback", do
      let power = 2 ^ (4095 :: Int) :: Integer
          huge = Infeasible (replicate 32 ((power-1) % (power-3)))
      assert "large encoded evidence must not fit" (not (resultFits huge))
      eq (renderResult (UnknownBudget OutputLimit)) (renderResult huge))
  , ("unknown fields", eq (Left InvalidJSON)
      (decodeRequest (B.pack "{\"variables\":0,\"a\":[],\"b\":[],\"extra\":0}")))
  , ("bool is not integer", eq (Left InvalidJSON)
      (decodeRequest (B.pack "{\"variables\":true,\"a\":[],\"b\":[]}")))
  , ("huge positive exponent", eq (Left InvalidJSON)
      (decodeRequest (B.pack "{\"variables\":1e1000000000,\"a\":[],\"b\":[]}")))
  , ("huge negative exponent", eq (Left InvalidJSON)
      (decodeRequest (B.pack "{\"variables\":1e-1000000000,\"a\":[],\"b\":[]}")))
  , ("oversize bytes", eq (Left InputTooLarge) (decodeRequest (B.replicate 65537 ' ')))
  , ("denominator reaches typed validator", case decodeRequest
      (B.pack "{\"variables\":0,\"a\":[[]],\"b\":[{\"n\":1,\"d\":0}]}") of
        Right (b,i) -> eq (InvalidInput InvalidDenominator) (solve b i)
        Left e -> fail (show e))
  , ("duplicate JSON keys use native Aeson first value", case decodeRequest
      (B.pack "{\"variables\":1,\"variables\":0,\"a\":[],\"b\":[]}") of
        Right (b,i) -> eq (Feasible [0]) (solve b i)
        Left e -> fail (show e))
  , ("duplicate JSON keys reverse order", case decodeRequest
      (B.pack "{\"variables\":0,\"variables\":1,\"a\":[],\"b\":[]}") of
        Right (b,i) -> eq (Feasible []) (solve b i)
        Left e -> fail (show e))
  , ("deterministic exact bytes", do
      let expected = renderResult (Infeasible [1,1])
      forM_ [1..20 :: Int] $ \_ -> eq expected (renderResult (solve defaultBudget parallel)))
  ]

synthetic :: Int -> Input
synthetic seed = Input 2
  [[Fraction (toInteger ((seed*(i+3)+j*7+i*i) `mod` 7 - 3))
      (toInteger (1 + (seed+i+j) `mod` 3)) | j <- [0,1]] | i <- [0..3]]
  [f (toInteger ((seed+i*3) `mod` 5 - 2)) | i <- [0..3]]

-- Coupled rational equalities exercise every admitted dimension against Z3,
-- including certificate propagation through the full back-substitution depth.
coupled :: Int -> Bool -> Input
coupled n contradiction = Input n (concatMap bounds [0..n-1] ++ [replicate n (f 1)])
  (concat (replicate n [Fraction 1 2, Fraction (-1) 2]) ++
    [Fraction (toInteger (n - if contradiction then 2 else 0)) 2])
  where
    bounds i = [[f (if j == i then sign else 0) | j <- [0..n-1]] | sign <- [1,-1]]

main :: IO ()
main = do
  let tests = regressions
        ++ [("native fixture " ++ show i, agreement input) | (i,input) <- zip [0::Int ..] fixtures]
        ++ [("native synthetic " ++ show i, agreement (synthetic i)) | i <- [0..95]]
        ++ [("coupled dimension " ++ show n ++ " contradictory=" ++ show bad, agreement (coupled n bad)) | n <- [1..8], bad <- [False,True]]
  assert "test inventory unexpectedly reduced" (length tests >= 167)
  forM_ tests $ \(name,action) -> action >> putStrLn ("PASS " ++ name)
  putStrLn (show (length tests) ++ " tests passed; native oracle UNKNOWN is a failure, not agreement.")
