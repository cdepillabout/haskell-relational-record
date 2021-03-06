{-# LANGUAGE TemplateHaskell #-}

module Database.Relational.Schema.SQLite3 (
  getType, normalizeColumn, normalizeType, notNull,
  tableInfoQuerySQL, indexListQuerySQL, indexInfoQuerySQL
  ) where

import qualified Data.Map as Map
import qualified Database.Relational.Schema.SQLite3Syscat.TableInfo as TableInfo

import Control.Applicative ((<|>))
import Data.ByteString (ByteString)
import Data.Char (toLower)
import Data.Int (Int64)
import Data.Map (Map)
import Database.Record.Instances ()
import Database.Relational.Query (Query)
import Database.Relational.Query.Type (unsafeTypedQuery)
import Database.Relational.Schema.SQLite3Syscat.IndexInfo
import Database.Relational.Schema.SQLite3Syscat.IndexList
import Database.Relational.Schema.SQLite3Syscat.TableInfo
import Language.Haskell.TH (TypeQ)

--{-# ANN module "HLint: ignore Redundant $" #-}

mapFromSqlDefault :: Map String TypeQ
mapFromSqlDefault =
    Map.fromList [ ("integer", [t|Int64|])
                 , ("real",    [t|Double|])
                 , ("text",    [t|String|])
                 , ("blob",    [t|ByteString|])
                 ]

normalizeColumn :: String -> String
normalizeColumn = map toLower

normalizeType :: String -> String
normalizeType = normalizeColumn . takeWhile (not . flip elem " (")

notNull :: TableInfo -> Bool
notNull info = isTrue . TableInfo.notnull $ info
  where
    isTrue 1 = True
    isTrue _ = False

getType :: Map String TypeQ -> TableInfo -> Maybe (String, TypeQ)
getType mapFromSql info = do
    typ <- Map.lookup key mapFromSql
           <|>
           Map.lookup key mapFromSqlDefault
    return (normalizeColumn (TableInfo.name info), mayNull typ)
  where
    key = normalizeType . TableInfo.ctype $ info
    mayNull typ = if notNull info
                    then typ
                    else [t|Maybe $(typ)|]

tableInfoQuerySQL :: String -> String -> Query () TableInfo
tableInfoQuerySQL db tbl = unsafeTypedQuery $ "pragma " ++ db ++ ".table_info(" ++ tbl ++ ");"

indexListQuerySQL :: String -> String -> Query () IndexList
indexListQuerySQL db tbl = unsafeTypedQuery $ "pragma " ++ db ++ ".index_list(" ++ tbl ++ ");"

indexInfoQuerySQL :: String -> String -> Query () IndexInfo
indexInfoQuerySQL db idx = unsafeTypedQuery $ "pragma " ++ db ++ ".index_info(" ++ idx ++ ");"
