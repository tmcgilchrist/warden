{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

module Warden.Parser.PII (
    addressP
  , emailP
  , phoneNumberP
  ) where

import           Data.Attoparsec.ByteString (Parser)
import           Data.Attoparsec.ByteString (takeWhile1, word8, endOfInput)
import           Data.Attoparsec.ByteString (choice, count, skipWhile, skip)
import           Data.Attoparsec.ByteString.Char8 (skipSpace, string)

import           P hiding (count)

-- | Without any reference to RFC 5321, this parser matches things which look
-- vaguely like they might be email addresses.
emailP :: Parser ()
emailP = {-# SCC emailP #-} do
  void $ takeWhile1 (not . (== at))
  void $ word8 at
  void $ takeWhile1 hostPart
  void $ word8 period
  void $ takeWhile1 (not . (== at))
  endOfInput
  where
    at = 0x40

    period = 0x2e

    hostPart 0x40 = False -- at
    hostPart 0x2e = False -- period
    hostPart 0x20 = False -- space
    hostPart _ = True
{-# INLINE emailP #-}

-- | Matches Australian phone numbers or fully-qualified international phone
-- numbers.
phoneNumberP :: Parser ()
phoneNumberP = {-# SCC phoneNumberP #-} do
  void $ choice [australianNumberP, internationalNumberP]
  endOfInput
{-# INLINE phoneNumberP #-}

australianNumberP :: Parser ()
australianNumberP = {-# SCC australianNumberP #-} do
  void $ word8 0x30 -- 0
  -- Only match Australian phone numbers with valid area codes.
  secondNum
  replicateM_ 8 phoneCharP
  where
    secondNum = skip isAreaCode >> skipPhoneFiller

    isAreaCode 0x32 = True -- 2, NSW/ACT
    isAreaCode 0x33 = True -- 3, VIC/TAS
    isAreaCode 0x34 = True -- 4, mobiles
    isAreaCode 0x37 = True -- 7, QLD
    isAreaCode 0x38 = True -- 8, SA/WA/NT
    isAreaCode _ = False
{-# INLINE australianNumberP #-}

internationalNumberP :: Parser ()
internationalNumberP = {-# SCC internationalNumberP #-} do
  void $ word8 0x2b -- +
  void $ count 11 phoneCharP
{-# INLINE internationalNumberP #-}

phoneCharP :: Parser ()
phoneCharP = {-# SCC phoneCharP #-}
  skip isPhoneChar >> skipPhoneFiller
  where
    isPhoneChar c = c >= 0x30 && c <= 0x39 -- 0-9
{-# INLINE phoneCharP #-}

skipPhoneFiller :: Parser ()
skipPhoneFiller = {-# SCC skipPhoneFiller #-}
  skipWhile valid
  where
    valid 0x20 = True -- space
    valid 0x2d = True -- hyphen
    valid 0x2e = True -- period
    valid _ = False
{-# INLINE skipPhoneFiller #-}

-- | Rudimentary address parser for Western-style street-level address
-- prefixes. Does not match some address forms, e.g., "Unit 5,
-- Whatever Road" or "La Maison Bourgeois, 123 Fake St".
--
-- This parser expects input to be pre-lowercased. It is safe to use
-- 'Warden.Row.Internal.asciiToLower'.
addressP :: Parser ()
addressP = {-# SCC addressP #-} do
  skipWhile numericBit
  skipWhile (== 0x32) -- space, safe for asciiToLower
  -- FIXME: unicode letters
  skipWhile alpha
  skipSpace
  -- FIXME: faster
  void $ choice streets
  where
    numericBit 0x2f = True -- /, e.g., 5/60 Fake Ave.
    numericBit c = c >= 0x30 && c <= 0x39

    -- Everything's lowercase by the time it gets here.
    alpha c = c >= 0x61 && c <= 0x7a

    streets = fmap string [
        "street"
      , "st"
      , "rd"
      , "road"
      , "lane"
      , "ln"
      , "cres"
      , "crescent"
      , "avenue"
      , "ave"
      ]
{-# INLINE addressP #-}