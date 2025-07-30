/ Integration Test Suite
/ Tests the complete data flow from ingestion to analytics

\l ../src/q/tick.q

/ Test utilities
.test.passed:0
.test.failed:0

.test.assert:{[name;condition;msg]
  if[condition;
    .test.passed+:1;
    -1"✓ ",name,": ",msg;
    :1b
  ];
  .test.failed+:1;
  -1"✗ ",name,": ",msg;
  :0b
 }

/ Simulate KDB+ client batch insert
simulateBatchInsert:{[data]
  / This simulates what the Rust client would send
  {upd[`ticker;x]} each data;
 }

/ Test complete data flow
testCompleteDataFlow:{[]
  -1"\n=== Testing Complete Data Flow ===";
  
  / Clear all tables
  delete from `ticker;
  delete from `trades;
  delete from `bars;
  
  / Simulate batch of ticker data (like from Rust client)
  batch1:(
    (.z.p;`ETHUSDT;2850.25;2850.75;1250;1375;2850.50;125000);
    (.z.p+1000000000;`ETHUSDT;2850.30;2850.80;1300;1400;2850.55;125100);
    (.z.p+2000000000;`ETHUSDT;2850.35;2850.85;1275;1380;2850.60;125200);
    (.z.p+3000000000;`ETHUSDT;2850.40;2850.90;1290;1390;2850.65;125300);
    (.z.p+4000000000;`ETHUSDT;2850.45;2850.95;1310;1410;2850.70;125400)
  );
  
  simulateBatchInsert[batch1];
  
  .test.assert["flow-batch-insert";5=count ticker;"Batch insert should add 5 records"];
  .test.assert["flow-data-integrity";all 2850.25 2850.30 2850.35 2850.40 2850.45 = exec bid from ticker;"Data should maintain integrity"];
  
  / Load and test VWAP
  \l ../src/q/analytics/vwap.q
  vwap:simpleVWAP[`ETHUSDT];
  .test.assert["flow-vwap-calc";not null vwap;"VWAP should be calculated"];
  .test.assert["flow-vwap-range";vwap within 2850 2851;"VWAP should be in expected range"];
  
  / Load and test order book analytics
  \l ../src/q/analytics/orderbook.q
  spread:exec avg spread from spreadAnalysis[`ETHUSDT];
  .test.assert["flow-spread-calc";spread=0.5;"Average spread should be 0.5"];
  
  imbalance:exec avg imbalance from bookImbalance[`ETHUSDT];
  .test.assert["flow-imbalance-calc";not null imbalance;"Imbalance should be calculated"];
  
  / Test with more realistic data over time
  -1"\nSimulating continuous data flow...";
  
  / Generate 1 minute of data
  times:.z.p+til[60]*1000000000;
  prices:2850+60?5.0;
  spreads:0.3+60?0.4;
  
  minuteData:{[t;p;s]
    (t;`ETHUSDT;p-s%2;p+s%2;1000+rand 1000;1100+rand 1000;p;100000+sum rand 10000)
  } ./: flip (times;prices;spreads);
  
  simulateBatchInsert[minuteData];
  
  / Update bars
  updateBars[];
  
  .test.assert["flow-bars-created";0<count bars;"Minute bars should be created"];
  .test.assert["flow-bar-vwap";not null bars[0;`vwap];"Bar VWAP should be calculated"];
  
  / Test volatility on the data
  \l ../src/q/analytics/volatility.q
  vol:exec last vol from historicalVolatility[`ETHUSDT;20];
  .test.assert["flow-volatility";not null vol;"Volatility should be calculated"];
 }

/ Test high-frequency scenario
testHighFrequencyScenario:{[]
  -1"\n=== Testing High-Frequency Scenario ===";
  
  / Clear tables
  delete from `ticker;
  delete from `trades;
  
  / Simulate 1000 updates in rapid succession
  startTime:.z.p;
  n:1000;
  
  / Generate rapid updates (microsecond intervals)
  rapidData:{[i]
    t:startTime+i*1000000; / 1 microsecond apart
    p:2850+sin[i%100]*2;
    s:0.3+0.1*sin[i%50];
    (t;`ETHUSDT;p-s%2;p+s%2;1000+i mod 500;1050+i mod 500;p;100000+i*10)
  } each til n;
  
  / Time the insertion
  t1:.z.p;
  simulateBatchInsert[rapidData];
  t2:.z.p;
  insertTime:`long$(t2-t1)%1000000;
  
  .test.assert["hf-insert-complete";n=count ticker;"All HF data should be inserted"];
  .test.assert["hf-insert-performance";insertTime<1000;"Insertion should complete in <1 second"];
  
  / Test analytics performance on HF data
  \l ../src/q/analytics/vwap.q
  t1:.z.p;
  vwap:simpleVWAP[`ETHUSDT];
  t2:.z.p;
  vwapTime:`long$(t2-t1)%1000000;
  
  .test.assert["hf-vwap-performance";vwapTime<100;"VWAP calculation should be <100ms"];
  
  -1"  Insert time: ",string[insertTime],"ms for ",string[n]," records";
  -1"  VWAP calc time: ",string[vwapTime],"ms";
 }

/ Test error handling
testErrorHandling:{[]
  -1"\n=== Testing Error Handling ===";
  
  / Test with malformed data
  badData:(
    (.z.p;`ETHUSDT;0n;100.5;100;110;100;1000);      / null bid
    (.z.p;`ETHUSDT;100.5;0n;100;110;100;1000);      / null ask  
    (.z.p;`ETHUSDT;100.5;99.5;0n;110;100;1000);     / null bid size
    (.z.p;`ETHUSDT;100.5;99.5;100;0n;100;1000);     / null ask size
    (.z.p;`ETHUSDT;100.5;99.5;100;110;0n;1000);     / null last
    (.z.p;`ETHUSDT;100.5;99.5;100;110;100;0n)       / null volume
  );
  
  count0:count ticker;
  simulateBatchInsert[badData];
  
  .test.assert["error-data-inserted";6=count[ticker]-count0;"Bad data should still be inserted"];
  
  / Test analytics with bad data
  \l ../src/q/analytics/orderbook.q
  spread:spreadAnalysis[`ETHUSDT];
  nullSpreads:exec i from spread where null spread;
  
  .test.assert["error-null-handling";2=count nullSpreads;"Null spreads should be handled correctly"];
 }

/ Test concurrent updates
testConcurrentUpdates:{[]
  -1"\n=== Testing Concurrent Updates ===";
  
  / Clear tables
  delete from `ticker;
  delete from `trades;
  
  / Simulate multiple symbols being updated concurrently
  symbols:`ETHUSDT`BTCUSDT`BNBUSDT;
  n:100;
  
  / Generate interleaved updates
  allData:raze {[s;i]
    t:.z.p+i*1000000000;
    p:$[s=`ETHUSDT;2850;s=`BTCUSDT;42000;300]+rand 100.0;
    spread:$[s=`ETHUSDT;0.5;s=`BTCUSDT;5;0.3];
    (t;s;p-spread%2;p+spread%2;1000+rand 1000;1100+rand 1000;p;100000+rand 10000)
  }[;] ./: raze (enlist each symbols) cross til n;
  
  / Shuffle to simulate concurrent arrival
  allData:allData iasc n?count allData;
  
  simulateBatchInsert[allData];
  
  .test.assert["concurrent-total-count";(n*count symbols)=count ticker;"All concurrent updates should be inserted"];
  
  / Verify data integrity per symbol
  {[s]
    c:count select from ticker where sym=s;
    .test.assert["concurrent-",string[s];c=n;"Should have correct count for ",string s];
  } each symbols;
  
  / Test analytics work correctly with multiple symbols
  \l ../src/q/analytics/vwap.q
  vwaps:symbols!simpleVWAP each symbols;
  
  .test.assert["concurrent-vwap-eth";vwaps[`ETHUSDT] within 2850 2950;"ETHUSDT VWAP should be in range"];
  .test.assert["concurrent-vwap-btc";vwaps[`BTCUSDT] within 42000 42100;"BTCUSDT VWAP should be in range"];
  .test.assert["concurrent-vwap-bnb";vwaps[`BNBUSDT] within 300 400;"BNBUSDT VWAP should be in range"];
 }

/ Test memory efficiency
testMemoryEfficiency:{[]
  -1"\n=== Testing Memory Efficiency ===";
  
  / Get initial memory usage
  \l ../src/q/analytics/performance.q
  mem1:systemResources[][`memoryUsedMB];
  
  / Insert large dataset
  n:50000;
  largeData:{[i]
    t:.z.p+i*1000000;
    p:2850+sin[i%1000]*10;
    s:0.3+0.2*cos[i%500];
    (t;`ETHUSDT;p-s%2;p+s%2;1000+i mod 1000;1050+i mod 1000;p;100000+i*10)
  } each til n;
  
  simulateBatchInsert[largeData];
  
  / Get memory after insertion
  mem2:systemResources[][`memoryUsedMB];
  memIncrease:mem2-mem1;
  
  .test.assert["memory-reasonable";memIncrease<100;"Memory increase should be <100MB for 50k records"];
  
  -1"  Memory increase: ",string[memIncrease],"MB for ",string[n]," records";
  
  / Clean up large dataset
  delete from `ticker where sym=`ETHUSDT;
 }

/ Run all integration tests
runTests:{[]
  -1"Integration Test Suite";
  -1"=====================\n";
  
  .test.passed:0;
  .test.failed:0;
  
  testCompleteDataFlow[];
  testHighFrequencyScenario[];
  testErrorHandling[];
  testConcurrentUpdates[];
  testMemoryEfficiency[];
  
  -1"\n=====================";
  -1"Integration Test Summary:";
  -1"  Passed: ",string .test.passed;
  -1"  Failed: ",string .test.failed;
  -1"  Total:  ",string .test.passed+.test.failed;
  
  :.test.failed=0
 }

runTests[]; 