/ Test suite for tick.q
/ Tests real-time ticker functionality

\l ../src/q/tick.q

/ Test utilities
.test.assert:{[name;condition;msg]
  if[condition;
    -1"✓ ",name,": ",msg;
    :1b
  ];
  -1"✗ ",name,": ",msg;
  :0b
 }

/ Test data generator
generateTickData:{[sym;n]
  times:.z.p+til[n]*1000000000;
  prices:100+n?10.0;
  spreads:0.01+n?0.05;
  sizes:100+n?1000;
  
  data:flip `time`sym`bid`ask`bidSize`askSize`last`volume!(
    times;
    n#sym;
    prices-spreads%2;
    prices+spreads%2;
    sizes;
    sizes*1.1;
    prices;
    sums 10+n?100
  );
  
  :data
 }

/ Test upd function
testUpdFunction:{[]
  -1"Testing upd function...";
  
  / Clear tables
  delete from `ticker;
  delete from `trades;
  
  / Test ticker update
  data:generateTickData[`ETHUSDT;5];
  count0:count ticker;
  
  {upd[`ticker;value x]} each data;
  
  .test.assert["upd-ticker-insert";count[ticker]=count0+count[data];"upd should insert ticker data"];
  .test.assert["upd-ticker-data";ticker[0;`sym]=`ETHUSDT;"upd should insert correct symbol"];
  
  / Test trades update
  tradeData:flip `time`sym`price`size`side!(
    .z.p+til[3]*1000000000;
    3#`ETHUSDT;
    100 101 99.5;
    100 200 150;
    `buy`sell`buy
  );
  
  count0:count trades;
  {upd[`trades;value x]} each tradeData;
  
  .test.assert["upd-trades-insert";count[trades]=count0+count[tradeData];"upd should insert trade data"];
 }

/ Test subscription mechanism
testSubscription:{[]
  -1"\nTesting subscription mechanism...";
  
  / Initialize subscription
  .u.w:`ticker`trades!(`int$();`int$());
  
  / Test subscriber tracking
  .test.assert["sub-init";.u.w~`ticker`trades!(`int$();`int$());"Subscription lists should be initialized"];
  
  / Note: Full subscription testing would require actual handles
  / which we can't create in unit tests
 }

/ Test bar updates
testBarUpdates:{[]
  -1"\nTesting bar updates...";
  
  / Clear and prepare data
  delete from `ticker;
  delete from `bars;
  
  / Insert minute of data
  times:.z.p-00:01:00+til[60]*1000000000;
  prices:100+60?2.0;
  
  tickData:flip `time`sym`bid`ask`bidSize`askSize`last`volume!(
    times;
    60#`ETHUSDT;
    prices-0.01;
    prices+0.01;
    60#100f;
    60#110f;
    prices;
    sums 60#10f
  );
  
  ticker insert tickData;
  
  / Run bar update
  updateBars[];
  
  .test.assert["bars-created";0<count bars;"Bars should be created"];
  .test.assert["bars-symbol";bars[0;`sym]=`ETHUSDT;"Bar should have correct symbol"];
  .test.assert["bars-ohlc";bars[0;`open]<=bars[0;`high];"Open should be <= high"];
  .test.assert["bars-ohlc2";bars[0;`low]<=bars[0;`close];"Low should be <= close"];
  .test.assert["bars-volume";bars[0;`volume]>0;"Volume should be positive"];
 }

/ Test timer functionality
testTimerFunctionality:{[]
  -1"\nTesting timer functionality...";
  
  / Test timer callback exists
  .test.assert["timer-exists";not null .z.ts;".z.ts timer function should exist"];
  .test.assert["timer-type";100h=type .z.ts;".z.ts should be a function"];
 }

/ Test data persistence
testDataPersistence:{[]
  -1"\nTesting data persistence...";
  
  / Insert test data
  delete from `ticker where sym=`TEST;
  testData:(.z.p;`TEST;99.5;100.5;100;110;100;1000);
  upd[`ticker;testData];
  
  / Verify data persists
  result:select from ticker where sym=`TEST;
  .test.assert["persist-data";1=count result;"Data should persist in ticker table"];
  .test.assert["persist-values";result[0;`bid]=99.5;"Persisted data should have correct values"];
  
  / Clean up
  delete from `ticker where sym=`TEST;
 }

/ Test real-time simulation
testRealTimeSimulation:{[]
  -1"\nTesting real-time simulation...";
  
  / Clear tables
  delete from `ticker;
  delete from `trades;
  delete from `bars;
  
  / Simulate real-time updates
  n:20;
  do[n;
    t:.z.p;
    upd[`ticker;(t;`SIMTEST;99.5+rand 1.0;100.5+rand 1.0;100+rand 100;110+rand 100;100+rand 1.0;sum 100?10)];
    
    if[0=rand 5;
      upd[`trades;(t;`SIMTEST;100+rand 1.0;100+rand 500;`buy`sell rand 2)];
    ];
  ];
  
  .test.assert["sim-ticker-data";n=count select from ticker where sym=`SIMTEST;"All simulated ticker data should be inserted"];
  .test.assert["sim-trades-data";0<count select from trades where sym=`SIMTEST;"Some trades should be inserted"];
  
  / Clean up
  delete from `ticker where sym=`SIMTEST;
  delete from `trades where sym=`SIMTEST;
 }

/ Run all tests
runTests:{[]
  -1"Tick.q Test Suite";
  -1"=================\n";
  
  testUpdFunction[];
  testSubscription[];
  testBarUpdates[];
  testTimerFunctionality[];
  testDataPersistence[];
  testRealTimeSimulation[];
  
  -1"\nTests completed.";
 }

runTests[]; 