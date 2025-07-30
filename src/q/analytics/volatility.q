// Volatility Analytics
// Calculate various volatility metrics and patterns

// Connect to ticker database
h:hopen `::5001

// Calculate simple historical volatility
historicalVolatility:{[sym;window;period]
  data:h"select from ticker where sym=`$sym, time > .z.P-window";
  
  // Calculate returns
  prices:data`last;
  returns:1_deltas[log prices];
  
  // Rolling volatility (annualized)
  periods:count[data]%window%period;  // periods per year
  vol:sqrt[periods]*sdev returns;
  
  vol*10000  // Return in basis points
 }

// Parkinson volatility (using high/low)
parkinsonVolatility:{[sym;window]
  // Get minute bars for high/low data
  data:h"select from bars where sym=`$sym, time > .z.P-window";
  
  if[not count data; :0n];
  
  // Parkinson formula
  factor:1%4*log 2;
  sumSq:sum xexp[log data`high%data`low;2];
  
  sqrt[factor*sumSq%count data]*10000
 }

// Garman-Klass volatility
garmanKlassVolatility:{[sym;window]
  data:h"select from bars where sym=`$sym, time > .z.P-window";
  
  if[not count data; :0n];
  
  // GK formula components
  hl:log data`high%data`low;
  co:log data`close%data`open;
  
  factor1:0.5*sum xexp[hl;2];
  factor2:(2*log 2 - 1)*sum xexp[co;2];
  
  sqrt[(factor1-factor2)%count data]*10000
 }

// Calculate realized volatility
realizedVolatility:{[sym;window;freq]
  data:h"select from ticker where sym=`$sym, time > .z.P-window";
  
  // Sample at frequency
  sampled:select last by freq xbar time from data;
  
  // Calculate returns
  returns:1_deltas[log sampled`last];
  
  // Realized vol
  sqrt[sum xexp[returns;2]]*10000
 }

// Volatility term structure
volTermStructure:{[sym]
  windows:`5min`15min`30min`1hour`4hour`1day!00:05 00:15 00:30 01:00 04:00 24:00;
  
  structure:{[s;w]
    vol:historicalVolatility[s;w;252*24*60*60%w];
    `window`volatility!(w;vol)
  }[sym] each windows;
  
  `window xasc structure
 }

// Volatility clustering analysis (GARCH-like)
volClustering:{[sym;window]
  data:h"select from ticker where sym=`$sym, time > .z.P-window";
  
  // Calculate squared returns
  returns:1_deltas[log data`last];
  sqReturns:xexp[returns;2];
  
  // Check autocorrelation of squared returns
  lags:1 5 10 20;
  
  acf:{[sr;lag]
    n:count sr;
    if[lag>=n;:0n];
    
    mean:avg sr;
    c0:avg xexp[sr-mean;2];
    
    shifted:(lag#0n),sr til n-lag;
    cLag:avg (sr-mean)*shifted-mean;
    
    cLag%c0
  }[sqReturns] each lags;
  
  ([] lag:lags; autocorrelation:acf)
 }

// Intraday volatility patterns
intradayVolPattern:{[sym;days]
  // Get data for multiple days
  data:h"select from ticker where sym=`$sym, time > .z.P-days";
  
  // Add time of day
  data:update timeOfDay:`minute$time-`date$time from data;
  
  // Calculate returns by minute of day
  data:update return:1_deltas[log last] by `date$time from data;
  
  // Aggregate by time of day
  pattern:select 
    avgVol:10000*sdev return,
    samples:count i
  by timeOfDay from data;
  
  pattern
 }

// Volatility regime detection
volRegimes:{[sym;window;threshold]
  data:h"select from ticker where sym=`$sym, time > .z.P-window";
  
  // Calculate rolling volatility
  data:update 
    returns:1_deltas[log last],
    time:time
  from data;
  
  // 20-period rolling vol
  data:update rollingVol:10000*mdev[20;returns] from data;
  
  // Identify regimes
  avgVol:avg data`rollingVol;
  
  update regime:?[rollingVol>avgVol*threshold;`high;`low] from data
 }

// Volatility smile analysis (if options data available)
volSmile:{[sym;expiry]
  // This would require options data
  // Placeholder for volatility smile calculation
  -1"Volatility smile requires options data";
  ()
 }

// Risk metrics based on volatility
riskMetrics:{[sym;window;confidence]
  data:h"select from ticker where sym=`$sym, time > .z.P-window";
  
  // Calculate returns
  returns:1_deltas[log data`last];
  
  // Basic statistics
  vol:sdev returns;
  mean:avg returns;
  
  // Value at Risk (VaR)
  varNormal:mean-vol*sqrt[window]*-1*.qnorm[1-confidence];
  varHistorical:.quantile[returns;1-confidence];
  
  // Expected Shortfall
  es:avg returns where returns<varHistorical;
  
  ([]
    metric:`volatility`dailyVol`VaR_normal`VaR_historical`expectedShortfall;
    value:(vol*10000;vol*sqrt[252]*10000;varNormal*10000;varHistorical*10000;es*10000)
  )
 }

// Examples
examples:{[]
  -1"Volatility Analytics Examples:";
  -1"";
  
  // Example 1: Historical volatility
  -1"1. 1-hour historical volatility:";
  -1"   ",string[historicalVolatility["ETHUSDT";01:00:00;365*24*60*60]]," bps";
  
  // Example 2: Volatility term structure
  -1"";
  -1"2. Volatility term structure:";
  show volTermStructure["ETHUSDT"];
  
  // Example 3: Volatility clustering
  -1"";
  -1"3. Volatility clustering (autocorrelation):";
  show volClustering["ETHUSDT";24:00:00];
  
  // Example 4: Risk metrics
  -1"";
  -1"4. Risk metrics (95% confidence):";
  show riskMetrics["ETHUSDT";01:00:00;0.95];
 }

// Volatility alerts
volAlert:{[sym;threshold;window]
  currentVol:historicalVolatility[sym;window;365*24*60*60];
  
  if[currentVol>threshold;
    -1"ALERT: High volatility on ",string[sym],": ",string[currentVol]," bps";
  ];
  
  currentVol
 }

-1"Volatility analytics loaded. Run examples[] to see usage."; 