{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}

module Test.Warden.Data.Row where

import           Control.Lens ((^.))

import qualified Data.Array as A
import qualified Data.Set as S

import           Data.Attoparsec.Text (parseOnly)
import qualified Data.Vector as V

import           Disorder.Core.Tripping (tripping)

import           P

import           System.IO (IO)

import           Test.QuickCheck
import           Test.Warden.Arbitrary

import           Warden.Data

sumFLC :: FieldLookCount -> ObservationCount
sumFLC l = sum . join $ A.elems <$> (lookArrays l)
  where
    lookArrays l' = case l' of
      NoFieldLookCount -> []
      FieldLookCount v -> V.toList v


prop_roundtrip_parsed_field :: ParsedField -> Property
prop_roundtrip_parsed_field = tripping renderParsedField (parseOnly fieldP)

prop_resolveSVParseState :: [SVParseState] -> Property
prop_resolveSVParseState ss =
  let s' = resolveSVParseState ss
      bad' = s' ^. badRows
      total' = s' ^. totalRows
      fns' = S.size $ s' ^. numFields in
  (===) True $ all (\s'' ->    bad' >= (s'' ^. badRows)
                            && total' >= (s'' ^. totalRows)
                            && fns' >= (S.size $ s'' ^. numFields)) ss

prop_updateSVParseState :: [ValidRow] -> Property
prop_updateSVParseState rs =
  let rs' = unValidRow <$> rs
      s = foldl updateSVParseState initialSVParseState rs' in
  (s ^. badRows, s ^. totalRows) === (RowCount 0, RowCount $ length rs)

prop_combineFieldLooks :: [FieldLookCount] -> Property
prop_combineFieldLooks ls =
  let l = foldr combineFieldLooks NoFieldLookCount ls
      lSum = sumFLC l
      tSum = sum $ sumFLC <$> ls in
  lSum === tSum

return []
tests :: IO Bool
tests = $quickCheckAll
