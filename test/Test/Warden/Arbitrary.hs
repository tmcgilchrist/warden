{-# LANGUAGE NoImplicitPrelude          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Test.Warden.Arbitrary where

import P

import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.Char
import Data.Csv
import qualified Data.Text as T
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8, decodeUtf8')
import qualified Data.Vector as V
import Data.Word
import Test.QuickCheck

import Disorder.Corpus
import Warden.Data

newtype SVSep = SVSep { getSVSep :: Word8 }
  deriving (Eq, Show, Ord)

instance Arbitrary SVSep where
  arbitrary = elements $ SVSep <$> filter (not . affectsRowState) [32..127]

-- | Valid rows for testing the tokenizer.
newtype ValidSVRow = ValidSVRow { getValidSVRow :: [Text] }
  deriving (Eq, Show, Ord, ToRecord)

newtype RowCount = RowCount { getRowCount :: Int }
  deriving (Eq, Show, Ord)

instance Arbitrary RowCount where
  arbitrary = RowCount <$> choose (1, 100)

newtype FieldCount = FieldCount { getFieldCount :: Int }
  deriving (Eq, Show, Ord)

instance Arbitrary FieldCount where
  arbitrary = FieldCount <$> choose (2, 10)

-- Our parser is stateless at the field level, unless it sees these characters.
affectsRowState :: Word8 -> Bool
affectsRowState w = elem w $ (fromIntegral . ord) <$> ['"', '\'', '\r', '\n', '\\']

invalidSVDocument :: Gen ByteString
invalidSVDocument = BL.pack <$> do
  body <- (listOf1 arbitrary) `suchThat` (not . (any affectsRowState))
  suffix <- elements $ pure $ (fromIntegral . ord) <$> ['"', '\'']
  pure $ body <> suffix

invalidSVRow :: SVSep -> Gen ByteString
invalidSVRow (SVSep s) = BL.intercalate (BL.pack [s]) <$> listOf1 invalidSVField

invalidSVField :: Gen ByteString
invalidSVField = BL.pack <$> (listOf arbitrary) `suchThat` isInvalidText
 where
  isInvalidText bs = (isLeft . decodeUtf8' . BS.pack) bs && not (any affectsRowState bs)

validSVField :: SVSep
             -> Gen Text
validSVField (SVSep s) = (decodeUtf8 . BS.pack) <$>
  (listOf arbitrary) `suchThat` isValid
 where
  isValid bs = 
       isRight (decodeUtf8' (BS.pack bs))
    && all (/= s) bs
    && not (any affectsRowState bs)

validSVRow :: SVSep -> FieldCount -> Gen ValidSVRow
validSVRow s (FieldCount n) = ValidSVRow <$> vectorOf n (validSVField s)

tokenizedRow :: FieldCount -> Gen Row
tokenizedRow (FieldCount n) = (SVFields . V.fromList) <$>
  vectorOf n (oneof [textField, integralField, realField])

textField :: Gen Text
textField = elements southpark

integralField :: Gen Text
integralField = (T.pack . show) <$> (arbitrary :: Gen Integer)

realField :: Gen Text
realField = (T.pack . show) <$> (arbitrary :: Gen Double)
