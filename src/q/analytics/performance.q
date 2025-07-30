// Performance Analytics
// Monitor system performance, latency, and data quality

// Connect to ticker database
h:hopen `::5001

// Data ingestion statistics
ingestionStats:{[]
  // Get ticker table stats
  tickerStats:h"select count:count i, minTime:min time, maxTime:max time, symbols:count distinct sym from ticker";
  
  // Calculate rates
  duration:(tickerStats`maxTime)-tickerStats`minTime;
  rate:tickerStats`count%`float$duration%0D00:00:01;
  
  // Data quality checks
  gaps:h"select time, gap:`time$time-prev time from ticker where 0D00:00:10<`time$time-prev time";
  
  stats:([]
    metric:`totalRecords`uniqueSymbols`timeRange`recordsPerSecond`dataGaps;
    value:(
      tickerStats`count;
      tickerStats`symbols;
      string[duration];
      rate;
      count gaps
    )
  );
  
  stats
 }

// Latency analysis
latencyAnalysis:{[sym]
  data:h"select from ticker where sym=`$sym";
  
  // Add system receive time (would need to be tracked)
  // For now, simulate with small random delay
  data:update sysTime:time+`time$1+rand each count[data]#1000 from data;
  
  // Calculate latencies
  data:update latency:`long$`time$sysTime-time from data;
  
  // Latency distribution
  latencyDist:([]
    percentile:`p50`p90`p95`p99`p999`max;
    latency:.quantile[data`latency;0.5 0.9 0.95 0.99 0.999 1.0]
  );
  
  latencyDist
 }

// Data quality metrics
dataQuality:{[sym;window]
  data:h"select from ticker where sym=`$sym, time > .z.P-window";
  
  // Check for various quality issues
  
  // 1. Duplicate timestamps
  duplicates:count[data]-count distinct data`time;
  
  // 2. Stale prices (no change for extended period)
  data:update priceChange:differ last from data;
  maxStale:max {sum mins x} each {1b sv x} each 5 cut not data`priceChange;
  
  // 3. Outliers (using z-score)
  data:update zScore:abs[(last-avg last)%sdev last] from data;
  outliers:count select from data where zScore>3;
  
  // 4. Missing data (gaps > 5 seconds)
  data:update gap:`time$time-prev time from data;
  gaps:count select from data where gap>0D00:00:05;
  
  // 5. Crossed markets
  crossed:count select from data where bid>ask;
  
  quality:([]
    check:`duplicates`stalePrices`outliers`gaps`crossedMarkets;
    count:(duplicates;maxStale;outliers;gaps;crossed);
    severity:?[count>0;`warn;`ok]
  );
  
  quality
 }

// System resource monitoring
systemMonitor:{[]
  // Memory usage
  memStats:h".Q.w[]";
  
  // Table sizes
  tableStats:h"{`table`count`bytes!(x;count value x;-22!value x)} each tables[]";
  
  // Connection count
  connCount:h"count .z.W";
  
  // Build summary
  summary:([]
    metric:`usedMemoryMB`heapMemoryMB`tableCount`connectionCount;
    value:(
      `long$memStats[`used]%1024*1024;
      `long$memStats[`heap]%1024*1024;
      count tableStats;
      connCount
    )
  );
  
  summary
 }

// Query performance tracking
queryPerformance:{[queries]
  // Test performance of common queries
  results:{[q]
    start:.z.P;
    res:h q;
    elapsed:`time$.z.P-start;
    
    `query`elapsed`resultCount!(q;elapsed;count res)
  } each queries;
  
  results
 }

// Throughput analysis
throughputAnalysis:{[window]
  // Get data counts by time window
  data:h"select from ticker where time > .z.P-window";
  
  // Group by smaller windows
  bucketSize:window%20;  // 20 buckets
  throughput:select 
    records:count i,
    symbols:count distinct sym,
    avgLatency:avg `long$`time$.z.P-time
  by bucketSize xbar time from data;
  
  // Calculate rates
  update 
    recordsPerSec:records%`float$bucketSize%0D00:00:01,
    symbolsPerSec:symbols%`float$bucketSize%0D00:00:01
  from throughput
 }

// Alert monitoring
performanceAlerts:{[]
  alerts:();
  
  // Check memory usage
  mem:h".Q.w[]";
  if[mem[`used]>0.8*mem[`heap];
    alerts,:enlist `alert`severity`message!(`memory;`high;"Memory usage above 80%");
  ];
  
  // Check data freshness
  lastUpdate:h"exec max time from ticker";
  if[.z.P-lastUpdate>0D00:01:00;
    alerts,:enlist `alert`severity`message!(`stale;`critical;"No data for >1 minute");
  ];
  
  // Check connection count
  conns:h"count .z.W";
  if[conns>100;
    alerts,:enlist `alert`severity`message!(`connections;`warn;"High connection count: ",string conns);
  ];
  
  alerts
 }

// Benchmark common operations
benchmark:{[]
  operations:(
    `simpleSelect;"select from ticker where sym=`ETHUSDT";
    `aggregation;"select avg bid, avg ask by sym from ticker";
    `timeWindow;"select from ticker where time > .z.P-00:05:00";
    `vwap;"select vwap:wavg[volume;last] by sym from ticker";
    `joinOperation;"ticker lj `sym xkey select last bid, last ask by sym from ticker"
  );
  
  results:{[name;query]
    times:();
    do[5;
      start:.z.P;
      h query;
      times,:`long$`time$.z.P-start;
    ];
    
    `operation`avgTime`minTime`maxTime!(
      name;
      avg times;
      min times;
      max times
    )
  } ./: operations;
  
  results
 }

// Historical performance tracking
trackPerformance:{[]
  // This would append to a performance log
  stats:`timestamp`records`symbols`memoryMB`connections!(
    .z.P;
    h"count ticker";
    h"count distinct exec sym from ticker";
    `long$h[".Q.w[]"][`used]%1024*1024;
    h"count .z.W"
  );
  
  // In practice, would append to a log table
  stats
 }

// Examples
examples:{[]
  -1"Performance Analytics Examples:";
  -1"";
  
  // Example 1: Ingestion statistics
  -1"1. Data ingestion statistics:";
  show ingestionStats[];
  
  // Example 2: System monitoring
  -1"";
  -1"2. System resource usage:";
  show systemMonitor[];
  
  // Example 3: Data quality
  -1"";
  -1"3. Data quality check for ETHUSDT:";
  show dataQuality["ETHUSDT";01:00:00];
  
  // Example 4: Performance alerts
  -1"";
  -1"4. Current alerts:";
  alerts:performanceAlerts[];
  $[count alerts;show alerts;-1"No active alerts"];
 }

// Real-time dashboard data
dashboardData:{[]
  `ingestion`system`alerts!(
    ingestionStats[];
    systemMonitor[];
    performanceAlerts[]
  )
 }

-1"Performance analytics loaded. Run examples[] to see usage."; 