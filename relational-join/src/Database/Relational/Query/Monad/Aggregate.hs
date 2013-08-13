{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- |
-- Module      : Database.Relational.Query.Monad.Aggregate
-- Copyright   : 2013 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module defines definitions about aggregated query type.
module Database.Relational.Query.Monad.Aggregate (
  -- * Aggregated Query
  QueryAggregate,
  AggregatedQuery,

  toSQL,

  toSubQuery
  ) where

import Database.Relational.Query.Projection (Projection)
import qualified Database.Relational.Query.Projection as Projection
import Database.Relational.Query.Aggregation (Aggregation)
import qualified Database.Relational.Query.Aggregation as Aggregation
import Database.Relational.Query.SQL (selectSeedSQL)
import Database.Relational.Query.Sub (SubQuery, subQuery)

import Database.Relational.Query.Monad.Qualify (Qualify)
import Database.Relational.Query.Monad.Class (MonadQualify(..))
import Database.Relational.Query.Monad.Trans.Join
  (join', FromAppend, appendFrom, extractFrom)
import Database.Relational.Query.Monad.Trans.Restrict
  (restrict, WhereAppend, appendWhere, extractWheres)
import Database.Relational.Query.Monad.Trans.Aggregate
  (Aggregatings, aggregate, GroupBysAppend, appendGroupBys, extractGroupBys)
import Database.Relational.Query.Monad.Trans.Ordering
  (Orderings, orderings, OrderedQuery, OrderByAppend, appendOrderBy, extractOrderBys)
import Database.Relational.Query.Monad.Core (QueryCore)


-- | Aggregated query monad type.
type QueryAggregate    = Orderings Aggregation (Aggregatings QueryCore)

-- | Aggregated query type. AggregatedQuery r == QueryAggregate (Aggregation r).
type AggregatedQuery r = OrderedQuery Aggregation (Aggregatings QueryCore) r

-- | Lift from qualified table forms into 'QueryAggregate'.
aggregatedQuery :: Qualify a -> QueryAggregate a
aggregatedQuery =  orderings . aggregate . restrict . join'

-- | Instance to lift from qualified table forms into 'QueryAggregate'.
instance MonadQualify Qualify (Orderings Aggregation (Aggregatings QueryCore)) where
  liftQualify = aggregatedQuery

expandAppend :: AggregatedQuery r
             -> Qualify ((((Aggregation r, OrderByAppend), GroupBysAppend), WhereAppend), FromAppend)
expandAppend =  extractFrom . extractWheres . extractGroupBys . extractOrderBys

-- | Run 'AggregatedQuery' to get SQL string.
expandSQL :: AggregatedQuery r -> Qualify (String, Projection r)
expandSQL q = do
  ((((aggr, ao), ag), aw), af) <- expandAppend q
  let projection = Aggregation.unsafeProjection aggr
  return (appendOrderBy ao . appendGroupBys ag . appendWhere aw . appendFrom af
          $ selectSeedSQL projection,
          projection)

-- | Run 'AggregatedQuery' to get SQL with 'Qualify' computation.
toSQL :: AggregatedQuery r -- ^ 'AggregatedQuery' to run
      -> Qualify String    -- ^ Result SQL string with 'Qualify' computation
toSQL =  fmap fst . expandSQL

-- | Run 'AggregatedQuery' to get 'SubQuery' with 'Qualify' computation.
toSubQuery :: AggregatedQuery r -- ^ 'AggregatedQuery' to run
           -> Qualify SubQuery  -- ^ Result 'SubQuery' with 'Qualify' computation
toSubQuery q = do
  (sql, pj) <- expandSQL q
  return $ subQuery sql (Projection.width pj)
