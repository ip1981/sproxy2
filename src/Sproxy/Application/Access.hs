{-# LANGUAGE TemplateHaskell #-}

module Sproxy.Application.Access
  ( Inquiry
  , Question(..)
  ) where

import Data.Aeson.TH (defaultOptions, deriveFromJSON)
import Data.HashMap.Strict (HashMap)
import Data.Text (Text)

data Question = Question
  { path :: Text
  , method :: Text
  } deriving (Show)

$(deriveFromJSON defaultOptions ''Question)

type Inquiry = HashMap Text Question
