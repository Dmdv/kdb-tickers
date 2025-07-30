// VWAP (Volume Weighted Average Price) Analytics
// Calculate VWAP for different time windows

// Connect to ticker database
h:hopen `::5001

// Calculate VWAP for a symbol over a time window
calcVWAP:{[sym;startTime;endTime]
  data:h"select from ticker where sym=`$sym, time within (startTime;endTime)";
  
  if[not count data; :`time`sym`vwap`totalVolume!(0Np;`$sym;0n;0n)];
  
  vwap:wavg[data`volume;data`last];
  totalVol:sum data`volume;
  
  `time`sym`vwap`totalVolume!(last data`time;`$sym;vwap;totalVol)
 }

// Calculate rolling VWAP with specified window
rollingVWAP:{[sym;window]
  data:h"select from ticker where sym=`$sym";
  
  // Calculate VWAP for each rolling window
  times:data`time;
  vwaps:{[d;t;w]
    windowData:select from d where time within (t-w;t);
    if[count windowData; wavg[windowData`volume;windowData`last]; 0n]
  }[data;;window] each times;
  
  ([] time:times; sym:`$sym; vwap:vwaps; window:window)
 }

// Calculate VWAP by time buckets (e.g., 5-minute buckets)
bucketVWAP:{[sym;bucketSize]
  data:h"select from ticker where sym=`$sym";
  
  // Create time buckets
  data:update bucket:bucketSize xbar time from data;
  
  // Calculate VWAP for each bucket
  select 
    time:last time,
    open:first last,
    high:max last,
    low:min last,
    close:last last,
    vwap:wavg[volume;last],
    volume:sum volume,
    count:count i
  by bucket,sym from data
 }

// Calculate intraday VWAP anchored at market open
intradayVWAP:{[sym]
  data:h"select from ticker where sym=`$sym, time > .z.D";
  
  // Calculate cumulative values
  data:update cumVol:sums volume, cumVolPrice:sums volume*last from data;
  
  // Calculate running VWAP
  update vwap:cumVolPrice%cumVol from data
 }

// VWAP deviation analysis
vwapDeviation:{[sym;window]
  // Get data with VWAP
  data:intradayVWAP[sym];
  
  // Calculate deviation from VWAP
  update 
    deviation:last-vwap,
    pctDeviation:100*(last-vwap)%vwap
  from data
 }

// Example usage functions
examples:{[]
  -1"VWAP Analytics Examples:";
  -1"";
  
  // Example 1: Calculate VWAP for last hour
  -1"1. VWAP for ETHUSDT last hour:";
  show calcVWAP["ETHUSDT";.z.P-01:00:00;.z.P];
  
  // Example 2: 5-minute rolling VWAP
  -1"";
  -1"2. Rolling 5-minute VWAP:";
  show 5#rollingVWAP["ETHUSDT";00:05:00];
  
  // Example 3: 5-minute bucket VWAP
  -1"";
  -1"3. 5-minute bucket VWAP:";
  show 5#bucketVWAP["ETHUSDT";00:05:00];
  
  // Example 4: Current VWAP deviation
  -1"";
  -1"4. Current VWAP deviation:";
  show -5#vwapDeviation["ETHUSDT";00:05:00];
 }

// Performance metrics
vwapPerformance:{[sym]
  // Calculate how often price crosses VWAP
  data:intradayVWAP[sym];
  
  // Identify crosses
  data:update cross:differ signum last-vwap from data;
  
  // Summary statistics
  stats:([]
    metric:`totalCrosses`avgAboveVWAP`avgBelowVWAP`currentPosition;
    value:(
      sum data`cross;
      avg data[where data`last>data`vwap]`pctDeviation;
      avg data[where data`last<data`vwap]`pctDeviation;
      `$string $[last[data]`last>last[data]`vwap;`above;`below]
    )
  );
  
  stats
 }

// Close connection when done
// hclose h

-1"VWAP analytics loaded. Run examples[] to see usage."; 