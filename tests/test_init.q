/ Test suite for init.q
/ Tests table schemas and basic functions

\l ../src/q/init.q

/ Test utilities
.test.assert:{[name;condition;msg]
  if[condition;
    -1"✓ ",name,": ",msg;
    :1b
  ];
  -1"✗ ",name,": ",msg;
  :0b
 }

/ Test table schemas
testTableSchemas:{[]
  -1"Testing table schemas...";
  
  / Test ticker table
  .test.assert["ticker-exists";`ticker in tables[];"ticker table should exist"];
  .test.assert["ticker-columns";cols[ticker]~`time`sym`bid`ask`bidSize`askSize`last`volume;"ticker should have correct columns"];
  .test.assert["ticker-types";meta[ticker][`t]~"psffffff";"ticker should have correct types"];
  
  / Test trades table
  .test.assert["trades-exists";`trades in tables[];"trades table should exist"];
  .test.assert["trades-columns";cols[trades]~`time`sym`price`size`side;"trades should have correct columns"];
  .test.assert["trades-types";meta[trades][`t]~"psffs";"trades should have correct types"];
  
  / Test bars table
  .test.assert["bars-exists";`bars in tables[];"bars table should exist"];
  .test.assert["bars-columns";cols[bars]~`time`sym`open`high`low`close`volume`vwap`count;"bars should have correct columns"];
  .test.assert["bars-types";meta[bars][`t]~"psffffffj";"bars should have correct types"];
 }

/ Test utility functions
testUtilityFunctions:{[]
  -1"\nTesting utility functions...";
  
  / Test .u.upd
  .test.assert["upd-exists";not null .u.upd;".u.upd function should exist"];
  .test.assert["upd-type";100h=type .u.upd;".u.upd should be a function"];
  
  / Test .u.sub
  .test.assert["sub-exists";not null .u.sub;".u.sub function should exist"];
  .test.assert["sub-type";100h=type .u.sub;".u.sub should be a function"];
  
  / Test data insertion
  count0:count ticker;
  .u.upd[`ticker;(.z.p;`TEST;99.5;100.5;100;110;100.0;1000)];
  .test.assert["upd-insert";count[ticker]=count0+1;".u.upd should insert data"];
  
  / Clean up
  delete from `ticker where sym=`TEST;
 }

/ Test time functions
testTimeFunctions:{[]
  -1"\nTesting time functions...";
  
  / Test getTime
  t:getTime[];
  .test.assert["getTime-type";-16h=type t;"getTime should return timespan"];
  .test.assert["getTime-valid";t within 00:00:00.000 24:00:00.000;"getTime should return valid time"];
  
  / Test getMinute
  m:getMinute[];
  .test.assert["getMinute-type";-17h=type m;"getMinute should return minute"];
  .test.assert["getMinute-valid";m within 00:00 23:59;"getMinute should return valid minute"];
 }

/ Test port configuration
testPortConfiguration:{[]
  -1"\nTesting port configuration...";
  
  .test.assert["port-set";system"p";"5001";"Port should be set to 5001"];
 }

/ Run all tests
runTests:{[]
  -1"Init.q Test Suite";
  -1"=================\n";
  
  testTableSchemas[];
  testUtilityFunctions[];
  testTimeFunctions[];
  testPortConfiguration[];
  
  -1"\nTests completed.";
 }

runTests[]; 