/ Enhanced Tick Handler with Persistence and Logging
/ Handles real-time data with disk persistence and archiving

\l init.q

/ Configuration
.config.dataPath:hsym `$getenv[`KDB_DATA_PATH],"/data/";
.config.logPath:hsym `$getenv[`KDB_LOG_PATH],"/logs/";
.config.archivePath:hsym `$getenv[`KDB_ARCHIVE_PATH],"/archive/";
.config.logLevel:`$getenv[`KDB_LOG_LEVEL];
if[null .config.logLevel;.config.logLevel:`INFO];

/ Create directories if they don't exist
system"mkdir -p ",1_string .config.dataPath;
system"mkdir -p ",1_string .config.logPath;
system"mkdir -p ",1_string .config.archivePath;

/ Logging functions
.log.levels:`DEBUG`INFO`WARN`ERROR!0 1 2 3;
.log.currentLevel:.log.levels .config.logLevel;

.log.write:{[level;msg]
  if[.log.levels[level]>=.log.currentLevel;
    logFile:.config.logPath,`$"ticker_",string[.z.D],".log";
    h:hopen logFile;
    h enlist (string .z.P)," [",string[level],"] ",msg;
    hclose h;
  ];
 }

.log.debug:{.log.write[`DEBUG;x]}
.log.info:{.log.write[`INFO;x]}
.log.warn:{.log.write[`WARN;x]}
.log.error:{.log.write[`ERROR;x]}

/ Persistence setup
.persist.tables:`ticker`trades`bars;
.persist.writeInterval:00:05:00; / Write to disk every 5 minutes
.persist.archiveInterval:24:00:00; / Archive daily
.persist.lastWrite:.z.P;
.persist.lastArchive:.z.D;

/ Initialize persistence files
.persist.init:{[]
  .log.info"Initializing persistence...";
  
  / Create today's data files if they don't exist
  {[t]
    file:.config.dataPath,`$string[t],"_",string[.z.D];
    if[not count key file;
      .log.info"Creating data file: ",string file;
      file set value t;
    ];
  } each .persist.tables;
  
  / Load today's data
  .persist.load[];
 }

/ Load data from disk
.persist.load:{[]
  .log.info"Loading data from disk...";
  
  {[t]
    file:.config.dataPath,`$string[t],"_",string[.z.D];
    if[count key file;
      .log.info"Loading ",string[t]," from ",string file;
      data:get file;
      
      / Append loaded data to in-memory table
      if[count data;
        t insert data;
        .log.info"Loaded ",(string count data)," rows into ",string t;
      ];
    ];
  } each .persist.tables;
 }

/ Write data to disk
.persist.write:{[]
  .log.info"Writing data to disk...";
  startTime:.z.P;
  
  {[t]
    file:.config.dataPath,`$string[t],"_",string[.z.D];
    data:value t;
    
    if[count data;
      .log.info"Writing ",(string count data)," rows of ",string[t]," to ",string file;
      file set data;
    ];
  } each .persist.tables;
  
  .persist.lastWrite:.z.P;
  elapsed:`long$(.z.P-startTime)%1000000;
  .log.info"Data write completed in ",(string elapsed),"ms";
 }

/ Archive old data
.persist.archive:{[]
  .log.info"Archiving old data...";
  
  / Get dates to archive (all except today)
  dataFiles:key .config.dataPath;
  dates:distinct `date$"D"$"_" vs/: string dataFiles;
  archiveDates:dates except .z.D;
  
  if[count archiveDates;
    {[d]
      .log.info"Archiving data for ",string d;
      
      / Create archive directory for the date
      archiveDir:.config.archivePath,`$string d;
      system"mkdir -p ",1_string archiveDir;
      
      / Move files to archive
      {[d;t]
        srcFile:.config.dataPath,`$string[t],"_",string[d];
        if[count key srcFile;
          dstFile:.config.archivePath,`$string[d],"/",string[t];
          
          / Compress and move
          .log.info"Compressing ",string srcFile;
          data:get srcFile;
          
          / Apply compression (simple example - in production use better compression)
          dstFile set -19!(data;17;1);
          
          / Remove original file
          hdel srcFile;
          .log.info"Archived ",string[t]," for ",string d;
        ];
      }[d;] each .persist.tables;
    } each archiveDates;
  ];
  
  .persist.lastArchive:.z.D;
 }

/ Enhanced upd function with persistence
upd:{[t;x]
  / Original update logic
  t insert x;
  
  / Publish to subscribers
  if[count .u.w[t];
    neg[.u.w[t]] @\: (.u.upd;t;x)
  ];
  
  / Log high-frequency updates periodically
  if[0=.stats.updateCount mod 1000;
    .log.info"Processed ",(string .stats.updateCount)," updates";
  ];
  .stats.updateCount+:1;
  
  / Check if we need to persist
  if[.z.P>.persist.lastWrite+.persist.writeInterval;
    .persist.write[];
  ];
  
  / Check if we need to archive (once per day)
  if[.z.D>.persist.lastArchive;
    .persist.archive[];
  ];
 }

/ Statistics tracking
.stats.updateCount:0;
.stats.startTime:.z.P;

/ Monitoring endpoint
.monitor.status:{[]
  uptime:`long$(.z.P-.stats.startTime)%1000000000;
  
  `status`uptime`updates`tables`lastWrite`lastArchive`memory!(
    `running;
    uptime;
    .stats.updateCount;
    {`table`rows!(x;count value x)} each .persist.tables;
    .persist.lastWrite;
    .persist.lastArchive;
    `used`heap`peak`wmax`mmap`mphy`syms`symw!.Q.w[]
  )
 }

/ Graceful shutdown handler
.z.exit:{[]
  .log.info"Shutting down - persisting final data...";
  .persist.write[];
  .log.info"Shutdown complete";
 }

/ Timer for periodic tasks
.z.ts:{[]
  / Update bars
  updateBars[];
  
  / Periodic persistence check
  if[.z.P>.persist.lastWrite+.persist.writeInterval;
    .persist.write[];
  ];
 }

/ Set timer to 1 minute
system"t 60000";

/ Initialize persistence
.persist.init[];

/ Log startup
.log.info"Enhanced ticker system started";
.log.info"Data path: ",string .config.dataPath;
.log.info"Log path: ",string .config.logPath;
.log.info"Archive path: ",string .config.archivePath;
.log.info"Persistence interval: ",string .persist.writeInterval;

-1"Enhanced Ticker System with Persistence";
-1"Data is persisted every ",string[.persist.writeInterval];
-1"Old data is archived daily";
-1"Monitoring available via .monitor.status[]"; 