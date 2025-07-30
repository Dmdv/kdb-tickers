// Order Book Analytics
// Analyze bid/ask spreads, depth, and imbalances

// Connect to ticker database
h:hopen `::5001

// Calculate bid-ask spread statistics
spreadAnalysis:{[sym;window]
  data:h"select from ticker where sym=`$sym, time > .z.P-window";
  
  // Calculate spreads
  data:update 
    spread:ask-bid,
    spreadBps:10000*(ask-bid)%bid,
    midPrice:0.5*bid+ask
  from data;
  
  // Summary statistics
  stats:([]
    metric:`avgSpread`avgSpreadBps`minSpread`maxSpread`currentSpread`spreadStdDev;
    value:(
      avg data`spread;
      avg data`spreadBps;
      min data`spread;
      max data`spread;
      last data`spread;
      sdev data`spread
    )
  );
  
  stats
 }

// Order book imbalance indicator
bookImbalance:{[sym]
  data:h"select last 100 from ticker where sym=`$sym";
  
  // Calculate imbalance
  update 
    imbalance:(bidSize-askSize)%(bidSize+askSize),
    totalSize:bidSize+askSize,
    bidAskRatio:bidSize%askSize
  from data
 }

// Detect large orders (size anomalies)
largeOrderDetection:{[sym;threshold]
  data:h"select from ticker where sym=`$sym";
  
  // Calculate rolling average sizes
  data:update 
    avgBidSize:mavg[20;bidSize],
    avgAskSize:mavg[20;askSize]
  from data;
  
  // Detect anomalies
  select from data where 
    (bidSize>threshold*avgBidSize) or (askSize>threshold*avgAskSize)
 }

// Micro-price calculation (weighted by size)
microPrice:{[sym;window]
  data:h"select from ticker where sym=`$sym, time > .z.P-window";
  
  // Calculate micro-price
  update microPrice:(bid*askSize + ask*bidSize)%(bidSize+askSize) from data
 }

// Spread pattern analysis
spreadPatterns:{[sym]
  data:h"select from ticker where sym=`$sym, time > .z.P-01:00:00";
  
  // Calculate spread metrics
  data:update 
    spread:ask-bid,
    spreadBps:10000*(ask-bid)%bid
  from data;
  
  // Time-based aggregation
  timeAnalysis:select 
    avgSpread:avg spreadBps,
    medianSpread:med spreadBps,
    volatility:sdev spreadBps,
    samples:count i
  by 00:05:00 xbar time from data;
  
  timeAnalysis
 }

// Order book depth analysis
depthAnalysis:{[sym]
  data:h"select last 1000 from ticker where sym=`$sym";
  
  // Calculate depth metrics
  data:update 
    totalDepth:bidSize+askSize,
    depthRatio:bidSize%askSize,
    weightedMid:(bid*bidSize + ask*askSize)%(bidSize+askSize)
  from data;
  
  // Depth distribution
  depthDist:([]
    percentile:`p10`p25`p50`p75`p90;
    bidSize:.quantile[data`bidSize;0.1 0.25 0.5 0.75 0.9];
    askSize:.quantile[data`askSize;0.1 0.25 0.5 0.75 0.9];
    totalDepth:.quantile[data`totalDepth;0.1 0.25 0.5 0.75 0.9]
  );
  
  depthDist
 }

// Liquidity score calculation
liquidityScore:{[sym;window]
  data:h"select from ticker where sym=`$sym, time > .z.P-window";
  
  // Calculate various liquidity metrics
  spread:avg 10000*(data`ask-data`bid)%data`bid;
  depth:avg data`bidSize+data`askSize;
  volatility:sdev 10000*1_deltas[data`midPrice]%prev data`midPrice;
  
  // Normalize and combine into score (0-100)
  spreadScore:100*1-spread%10;  // Assume 10bps is bad
  depthScore:100*depth%max data`bidSize+data`askSize;
  volScore:100*1-volatility%100;  // Assume 100bps vol is bad
  
  // Weighted average
  score:0.4*spreadScore + 0.4*depthScore + 0.2*volScore;
  
  ([]
    metric:`spread`depth`volatility`liquidityScore;
    value:(spread;depth;volatility;score)
  )
 }

// Example usage
examples:{[]
  -1"Order Book Analytics Examples:";
  -1"";
  
  // Example 1: Spread analysis
  -1"1. Spread analysis for last hour:";
  show spreadAnalysis["ETHUSDT";01:00:00];
  
  // Example 2: Current book imbalance
  -1"";
  -1"2. Recent order book imbalances:";
  show -10#bookImbalance["ETHUSDT"];
  
  // Example 3: Spread patterns by time
  -1"";
  -1"3. Spread patterns (5-min buckets):";
  show -10#spreadPatterns["ETHUSDT"];
  
  // Example 4: Liquidity score
  -1"";
  -1"4. Current liquidity score:";
  show liquidityScore["ETHUSDT";00:30:00];
 }

// Real-time spread monitor
monitorSpreads:{[syms;alertThreshold]
  // Monitor multiple symbols
  {[sym;threshold]
    data:h"select last from ticker where sym=`$sym";
    spread:10000*(data[`ask]-data[`bid])%data[`bid];
    
    if[spread>threshold;
      -1"ALERT: High spread on ",string[sym],": ",string[spread]," bps";
    ];
  }[;alertThreshold] each `$syms;
 }

-1"Order book analytics loaded. Run examples[] to see usage."; 