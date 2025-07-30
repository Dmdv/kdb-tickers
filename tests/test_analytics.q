/ KDB+ Analytics Test Suite
/ Comprehensive tests for all analytics modules

\l ../src/q/init.q

/ Test utilities
.test.results:()!()
.test.passed:0
.test.failed:0

.test.assert:{[name;condition;msg]
  if[condition;
    .test.passed+:1;
    .test.results[name]:`passed;
    -1"✓ ",name,": ",msg;
    :1b
  ];
  .test.failed+:1;
  .test.results[name]:`failed;
  -1"✗ ",name,": ",msg;
  :0b
 }

.test.assertEq:{[name;actual;expected;msg]
  .test.assert[name;actual~expected;msg," (expected: ",(-3!expected),", actual: ",(-3!actual),")"]
 }

.test.assertClose:{[name;actual;expected;tolerance;msg]
  .test.assert[name;abs[actual-expected]<tolerance;msg," (expected: ",string[expected],", actual: ",string[actual],")"]
 }

/ Generate test data
generateTestData:{[sym;n]
  times:asc .z.p+til[n]*1000000000;
  prices:100+n?10.0;
  spreads:0.01+n?0.05;
  sizes:100+n?1000;
  
  `ticker insert flip `time`sym`bid`ask`bidSize`askSize`last`volume!(
    times;
    n#sym;
    prices-spreads%2;
    prices+spreads%2;
    sizes;
    sizes*1.1;
    prices;
    sums 10+n?100
  );
  
  `trades insert flip `time`sym`price`size`side!(
    times;
    n#sym;
    prices;
    sizes;
    n?`buy`sell
  );
 }

/ Clear test data
clearTestData:{[]
  delete from `ticker;
  delete from `trades;
  delete from `bars;
 }

/ Test VWAP calculations
testVWAP:{[]
  -1"\n=== Testing VWAP Analytics ===";
  clearTestData[];
  generateTestData[`ETHUSDT;100];
  
  \l ../src/q/analytics/vwap.q
  
  / Test simple VWAP
  vwap1:simpleVWAP[`ETHUSDT];
  .test.assert["VWAP-Simple-NotNull";not null vwap1;"Simple VWAP should return a value"];
  .test.assert["VWAP-Simple-Positive";vwap1>0;"Simple VWAP should be positive"];
  
  / Test rolling VWAP
  rvwap:rollingVWAP[`ETHUSDT;10];
  .test.assert["VWAP-Rolling-Count";count[rvwap]=count[ticker];"Rolling VWAP count should match ticker count"];
  .test.assert["VWAP-Rolling-NoNulls";not any null last 90#rvwap;"Rolling VWAP should have no nulls after window"];
  
  / Test bucketed VWAP
  bvwap:bucketedVWAP[`ETHUSDT;00:01:00];
  .test.assert["VWAP-Bucketed-HasResults";0<count bvwap;"Bucketed VWAP should return results"];
  .test.assert["VWAP-Bucketed-Structure";all `time`vwap in cols bvwap;"Bucketed VWAP should have correct columns"];
  
  / Test VWAP deviation
  dev:vwapDeviation[`ETHUSDT];
  .test.assert["VWAP-Deviation-Structure";all `time`price`vwap`deviation in cols dev;"VWAP deviation should have correct columns"];
  .test.assert["VWAP-Deviation-Calculated";not any null dev`deviation;"Deviation should be calculated for all rows"];
 }

/ Test Order Book Analytics
testOrderBook:{[]
  -1"\n=== Testing Order Book Analytics ===";
  clearTestData[];
  generateTestData[`ETHUSDT;100];
  
  \l ../src/q/analytics/orderbook.q
  
  / Test spread analysis
  spread:spreadAnalysis[`ETHUSDT];
  .test.assert["Spread-HasResults";0<count spread;"Spread analysis should return results"];
  .test.assert["Spread-Structure";all `time`spread`spreadBps in cols spread;"Spread analysis should have correct columns"];
  .test.assert["Spread-Positive";all spread[`spread]>0;"Spreads should be positive"];
  .test.assertClose["Spread-BpsRange";avg spread[`spreadBps];50;100;"Average spread in bps should be reasonable"];
  
  / Test book imbalance
  imb:bookImbalance[`ETHUSDT];
  .test.assert["Imbalance-Range";all imb[`imbalance] within -1 1;"Imbalance should be between -1 and 1"];
  .test.assert["Imbalance-Calculation";all not null imb[`imbalance];"Imbalance should be calculated for all rows"];
  
  / Test micro price
  mp:microPrice[`ETHUSDT];
  .test.assert["MicroPrice-Between";all mp[`microPrice] within mp[`bid],mp[`ask];"Micro price should be between bid and ask"];
  .test.assert["MicroPrice-NotNull";not any null mp[`microPrice];"Micro price should not have nulls"];
  
  / Test liquidity score
  liq:liquidityScore[`ETHUSDT;00:05:00];
  .test.assert["Liquidity-Positive";all liq[`liquidityScore]>=0;"Liquidity scores should be non-negative"];
  .test.assert["Liquidity-HasResults";0<count liq;"Liquidity scoring should return results"];
 }

/ Test Volatility Analytics
testVolatility:{[]
  -1"\n=== Testing Volatility Analytics ===";
  clearTestData[];
  generateTestData[`ETHUSDT;1000]; / More data for volatility
  
  \l ../src/q/analytics/volatility.q
  
  / Test historical volatility
  hvol:historicalVolatility[`ETHUSDT;20];
  .test.assert["HVol-Count";count[hvol]=count[ticker];"Historical volatility count should match ticker count"];
  .test.assert["HVol-Range";all hvol within 0 1;"Historical volatility should be between 0 and 1"];
  
  / Test Parkinson volatility
  pvol:parkinsonVolatility[`ETHUSDT;00:05:00;20];
  .test.assert["PVol-HasResults";0<count pvol;"Parkinson volatility should return results"];
  .test.assert["PVol-Positive";all pvol[`parkinson]>=0;"Parkinson volatility should be non-negative"];
  
  / Test realized volatility
  rvol:realizedVolatility[`ETHUSDT;5];
  .test.assert["RVol-Structure";all `time`returns`realizedVol in cols rvol;"Realized volatility should have correct structure"];
  .test.assert["RVol-Calculated";sum[not null rvol`realizedVol]>count[rvol]%2;"Most realized volatility values should be calculated"];
  
  / Test volatility clustering
  clust:volatilityClustering[`ETHUSDT;20];
  .test.assert["Clustering-States";all clust[`regime] in `low`medium`high;"Volatility regimes should be low/medium/high"];
  .test.assert["Clustering-Complete";count[clust]=count[ticker];"Clustering should cover all data points"];
 }

/ Test Performance Analytics
testPerformance:{[]
  -1"\n=== Testing Performance Analytics ===";
  clearTestData[];
  generateTestData[`ETHUSDT;500];
  
  \l ../src/q/analytics/performance.q
  
  / Test ingestion stats
  stats:ingestionStats[];
  .test.assert["Stats-Tables";all `ticker`trades in stats`table;"Stats should include main tables"];
  .test.assert["Stats-Metrics";all `rows`dataSize`avgRowSize in cols stats;"Stats should have correct metrics"];
  
  / Test data quality
  quality:dataQuality[`ticker];
  .test.assert["Quality-Metrics";all `nullCount`duplicates`gaps in cols quality;"Quality check should have all metrics"];
  .test.assertEq["Quality-NoNulls";quality[`nullCount];0;"Should have no null values in test data"];
  
  / Test system resources
  res:systemResources[];
  .test.assert["Resources-Memory";res[`memoryUsedMB]>0;"Memory usage should be positive"];
  .test.assert["Resources-Tables";0<count res[`tables];"Should have table information"];
 }

/ Test Integration
testIntegration:{[]
  -1"\n=== Testing Integration ===";
  clearTestData[];
  
  / Simulate real-time data flow
  n:50;
  do[n;
    t:.z.p;
    s:`ETHUSDT;
    p:100+rand 10.0;
    spread:0.01+rand 0.05;
    sz:100+rand 1000;
    
    `ticker insert (t;s;p-spread%2;p+spread%2;sz;sz*1.1;p;sum 10+rand 100);
    
    if[0=rand 3;
      `trades insert (t;s;p;sz;`buy`sell rand 2);
    ];
  ];
  
  .test.assert["Integration-DataInserted";n=count ticker;"All ticker data should be inserted"];
  .test.assert["Integration-TradesInserted";0<count trades;"Some trades should be inserted"];
  
  / Test analytics on integrated data
  \l ../src/q/analytics/vwap.q
  vwap:simpleVWAP[`ETHUSDT];
  .test.assert["Integration-VWAPCalculated";not null vwap;"VWAP should be calculated on integrated data"];
  
  \l ../src/q/analytics/orderbook.q
  spread:avg exec spreadBps from spreadAnalysis[`ETHUSDT];
  .test.assert["Integration-SpreadReasonable";spread within 1 100;"Average spread should be reasonable"];
 }

/ Test Edge Cases
testEdgeCases:{[]
  -1"\n=== Testing Edge Cases ===";
  clearTestData[];
  
  / Test with no data
  \l ../src/q/analytics/vwap.q
  vwapEmpty:simpleVWAP[`NONEXISTENT];
  .test.assert["EdgeCase-EmptyVWAP";null vwapEmpty;"VWAP should be null for non-existent symbol"];
  
  / Test with single data point
  `ticker insert (.z.p;`SINGLE;99.5;100.5;100;110;100;100);
  vwapSingle:simpleVWAP[`SINGLE];
  .test.assertEq["EdgeCase-SingleVWAP";vwapSingle;100f;"VWAP with single point should equal price"];
  
  / Test with extreme values
  `ticker insert (.z.p;`EXTREME;0n;100.5;100;110;100;100);
  \l ../src/q/analytics/orderbook.q
  spreadExtreme:spreadAnalysis[`EXTREME];
  .test.assert["EdgeCase-NullBid";(exec null spread from spreadExtreme)0;"Spread should be null with null bid"];
  
  / Test with zero volumes
  clearTestData[];
  `ticker insert (.z.p;`ZEROVOL;99.5;100.5;0;0;100;0);
  \l ../src/q/analytics/vwap.q
  vwapZero:simpleVWAP[`ZEROVOL];
  .test.assert["EdgeCase-ZeroVolume";null vwapZero;"VWAP should be null with zero volume"];
 }

/ Performance Benchmarks
testPerformance:{[]
  -1"\n=== Performance Benchmarks ===";
  clearTestData[];
  
  / Generate large dataset
  n:10000;
  generateTestData[`ETHUSDT;n];
  
  / Benchmark VWAP
  \l ../src/q/analytics/vwap.q
  t1:.z.p;
  vwap:simpleVWAP[`ETHUSDT];
  t2:.z.p;
  vwapTime:`long$(t2-t1)%1000000;
  .test.assert["Perf-VWAPTime";vwapTime<100;"Simple VWAP should complete in <100ms"];
  
  / Benchmark spread analysis
  \l ../src/q/analytics/orderbook.q
  t1:.z.p;
  spread:spreadAnalysis[`ETHUSDT];
  t2:.z.p;
  spreadTime:`long$(t2-t1)%1000000;
  .test.assert["Perf-SpreadTime";spreadTime<200;"Spread analysis should complete in <200ms"];
  
  / Benchmark volatility
  \l ../src/q/analytics/volatility.q
  t1:.z.p;
  vol:historicalVolatility[`ETHUSDT;20];
  t2:.z.p;
  volTime:`long$(t2-t1)%1000000;
  .test.assert["Perf-VolTime";volTime<500;"Historical volatility should complete in <500ms"];
  
  -1"Performance Summary:";
  -1"  VWAP calculation: ",string[vwapTime],"ms for ",string[n]," records";
  -1"  Spread analysis: ",string[spreadTime],"ms for ",string[n]," records";
  -1"  Volatility calc: ",string[volTime],"ms for ",string[n]," records";
 }

/ Run all tests
runAllTests:{[]
  -1"KDB+ Analytics Test Suite";
  -1"========================\n";
  
  .test.results:()!();
  .test.passed:0;
  .test.failed:0;
  
  testVWAP[];
  testOrderBook[];
  testVolatility[];
  testPerformance[];
  testIntegration[];
  testEdgeCases[];
  testPerformance[];
  
  -1"\n========================";
  -1"Test Summary:";
  -1"  Passed: ",string .test.passed;
  -1"  Failed: ",string .test.failed;
  -1"  Total:  ",string .test.passed+.test.failed;
  
  if[.test.failed>0;
    -1"\nFailed tests:";
    -1 each " - ",/:string key .test.results where .test.results=`failed;
  ];
  
  :.test.failed=0
 }

/ Run tests if called directly
if[`test.q in .z.x;runAllTests[]]; 