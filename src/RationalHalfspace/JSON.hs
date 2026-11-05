{-# LANGUAGE OverloadedStrings #-}
module RationalHalfspace.JSON
  ( decodeRequest, resultValue, renderResult, resultFits, maxBytes ) where

import Data.Aeson hiding (Result)
import Data.Aeson.Types (Parser, parseEither)
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.Foldable (toList)
import Data.Ratio (numerator, denominator)
import Data.Scientific (toBoundedInteger)
import RationalHalfspace.Types

maxBytes :: Int
maxBytes = 65536

keysOnly :: [Key] -> Object -> Parser ()
keysOnly allowed o
  | all (`elem` allowed) (KM.keys o) = pure ()
  | otherwise = fail "unknown field"

smallInt :: Value -> Parser Int
smallInt (Number s) = case toBoundedInteger s :: Maybe Int of
  Just n | n >= -1000000 && n <= 1000000 -> pure n
  _ -> fail "bounded integer required"
smallInt _ = fail "integer required"

fraction :: Value -> Parser Fraction
fraction = withObject "rational" $ \o -> do
  keysOnly ["n", "d"] o
  n <- o .: "n" >>= smallInt
  d <- o .: "d" >>= smallInt
  pure (Fraction (toInteger n) (toInteger d))

arrayOf :: Int -> (Value -> Parser a) -> Value -> Parser [a]
arrayOf cap parser = withArray "array" $ \v ->
  if length v > cap then fail "array limit" else traverse parser (toList v)

parseBudget :: Value -> Parser Budget
parseBudget = withObject "budget" $ \o -> do
  keysOnly ["rows", "pairs", "bits"] o
  Budget <$> (o .: "rows" >>= smallInt)
         <*> (o .: "pairs" >>= smallInt)
         <*> (o .: "bits" >>= smallInt)

request :: Value -> Parser (Budget, Input)
request = withObject "request" $ \o -> do
  keysOnly ["variables", "a", "b", "budget"] o
  n <- o .: "variables" >>= smallInt
  a <- o .: "a" >>= arrayOf 32 (arrayOf 8 fraction)
  b <- o .: "b" >>= arrayOf 32 fraction
  budget <- maybe (pure defaultBudget) parseBudget (KM.lookup "budget" o)
  pure (budget, Input n a b)

decodeRequest :: BS.ByteString -> Either InputError (Budget, Input)
decodeRequest bytes
  | BS.length bytes > maxBytes = Left InputTooLarge
  | otherwise = case eitherDecodeStrict' bytes >>= parseEither request of
      Left _ -> Left InvalidJSON
      Right x -> Right x

rationalValue :: Rational -> Value
rationalValue q = object ["n" .= numerator q, "d" .= denominator q]

resultValue :: Result -> Value
resultValue r = object
  (["schema" .= String "rational-halfspace-witnesses/1", "complete" .= True] ++ fields)
  where
    fields = case r of
      Feasible xs -> ["status" .= String "FEASIBLE", "point" .= map rationalValue xs]
      Infeasible xs -> ["status" .= String "INFEASIBLE", "certificate" .= map rationalValue xs]
      UnknownBudget why -> ["status" .= String "UNKNOWN_BUDGET", "reason" .= show why]
      InvalidInput why -> ["status" .= String "INVALID_INPUT", "reason" .= show why]
      CalculationError -> ["status" .= String "INTERNAL_ERROR"]

encoded :: Result -> BL.ByteString
encoded r = encode (resultValue r) <> "\n"

resultFits :: Result -> Bool
resultFits = (<= fromIntegral maxBytes) . BL.length . encoded

-- This is an encoder, not an evidence verifier. solve verifies its results.
renderResult :: Result -> BS.ByteString
renderResult r = BL.toStrict (encoded bounded)
  where bounded = if resultFits r then r else UnknownBudget OutputLimit
