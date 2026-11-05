{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import Control.Exception (IOException, catch)
import Data.Aeson (encode, object, (.=))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.Ratio ((%))
import System.Environment (getArgs)
import System.Exit (ExitCode(..), exitWith)
import System.IO
import RationalHalfspace
import RationalHalfspace.JSON

-- At most cap+1 bytes are retained. The extra byte distinguishes oversize
-- input from a complete cap-byte document without an unbounded lazy read.
readInput :: IO BS.ByteString
readInput = go [] 0
  where
    go chunks size
      | size > maxBytes = pure (BS.concat (reverse chunks))
      | otherwise = do
          part <- BS.hGetSome stdin (min 4096 (maxBytes + 1 - size))
          if BS.null part then pure (BS.concat (reverse chunks))
          else go (part:chunks) (size + BS.length part)

bestEffortStderr :: String -> IO ()
bestEffortStderr msg =
  catch (hPutStrLn stderr msg >> hFlush stderr) ignoreIO
  where
    ignoreIO :: IOException -> IO ()
    ignoreIO _ = pure ()

exitFor :: Result -> IO ()
exitFor (InvalidInput _) = exitWith (ExitFailure 2)
exitFor CalculationError = exitWith (ExitFailure 70)
exitFor _ = pure ()

serve :: IO ()
serve = do
  bytes <- readInput
  let result = case decodeRequest bytes of
        Left err -> InvalidInput err
        Right (budget,input) -> solve budget input
  BS.hPut stdout (renderResult result)
  hFlush stdout
  exitFor result

interval :: Integer -> Integer -> Input
interval upper lower = Input 1 [[Fraction 1 1],[Fraction (-1) 1]]
  [Fraction upper 3,Fraction (negate lower) 2]

demo :: Bool -> IO ()
demo machine = do
  let feasible = solve defaultBudget (interval 2 1)
      infeasible = solve defaultBudget (interval 1 1)
      exhausted = solve (defaultBudget { pairLimit = 0 }) (interval 1 1)
      expected = feasible == Feasible [1 % 2]
        && infeasible == Infeasible [1,1]
        && exhausted == UnknownBudget PairLimit
  if not expected then do
    bestEffortStderr "Synthetic demo assertion failed."
    exitWith (ExitFailure 70)
  else if machine then do
    let output = encode (object
          [ "schema" .= ("rational-halfspace-witnesses-demo/1" :: String)
          , "complete" .= True
          , "results" .= map resultValue [feasible,infeasible,exhausted]
          ]) <> "\n"
    if BL.length output > fromIntegral maxBytes then exitWith (ExitFailure 70)
    else BL.hPut stdout output >> hFlush stdout
  else do
    putStrLn "Synthetic / Sintético — development 0.1.0"
    putStrLn "FEASIBLE / VIÁVEL: x = 1/2"
    putStrLn "INFEASIBLE / INVIÁVEL: multipliers / multiplicadores = [1, 1]"
    putStrLn "UNKNOWN_BUDGET / ORÇAMENTO ESGOTADO: PairLimit"
    putStrLn "Assertions passed / Asserções aprovadas."
    hFlush stdout

main :: IO ()
main = catch run ioFailure
  where
    run = do
      hSetEncoding stdout utf8
      args <- getArgs
      case args of
        [] -> serve
        ["solve"] -> serve
        ["demo","--assert"] -> demo False
        ["demo","--assert","--json"] -> demo True
        _ -> do
          BS.hPut stdout (renderResult (InvalidInput InvalidArguments))
          hFlush stdout
          exitWith (ExitFailure 2)
    ioFailure :: IOException -> IO ()
    ioFailure _ = do
      bestEffortStderr "I/O incomplete; no complete result is guaranteed."
      exitWith (ExitFailure 74)
