{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}
{-# LANGUAGE TemplateHaskell    #-}

-- | Specialization of Logging module for RSCoin.

module RSCoin.Core.Logging
       ( module Control.TimeWarp.Logging
       , initLogging

         -- * Predefined logger names
       , bankLoggerName
       , benchLoggerName
       , communicationLoggerName
       , explorerLoggerName
       , mintetteLoggerName
       , nakedLoggerName
       , notaryLoggerName
       , testingLoggerName
       , timedLoggerName
       , userLoggerName
       ) where

import           Control.TimeWarp.Logging  hiding        (initLogging)
import qualified Control.TimeWarp.Logging      as L      (initLogging)
import qualified Control.TimeWarp.Timed.TimedT as TimedT (defaultLoggerName)

initLogging :: Severity -> IO ()
initLogging = L.initLogging predefinedLoggers

bankLoggerName,
    benchLoggerName,
    communicationLoggerName,
    explorerLoggerName,
    mintetteLoggerName,
    nakedLoggerName,
    notaryLoggerName,
    testingLoggerName,
    timedLoggerName,
    userLoggerName :: LoggerName
bankLoggerName          = "bank"
benchLoggerName         = "bench"
communicationLoggerName = "communication"
explorerLoggerName      = "explorer"
mintetteLoggerName      = "mintette"
nakedLoggerName         = "naked"
notaryLoggerName        = "notary"
testingLoggerName       = "testing"
timedLoggerName         = TimedT.defaultLoggerName
userLoggerName          = "user"

predefinedLoggers :: [LoggerName]
predefinedLoggers =
    [ bankLoggerName
    , communicationLoggerName
    , explorerLoggerName
    , mintetteLoggerName
    , nakedLoggerName
    , notaryLoggerName
    , timedLoggerName
    , userLoggerName
    ]

instance WithNamedLogger IO where
    getLoggerName = pure nakedLoggerName
    modifyLoggerName = const id
