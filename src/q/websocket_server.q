/ KDB+ WebSocket Server with TLS Support
/ Demonstrates serving data over secure WebSocket connections

/ Load the ticker system
\l init.q

/ Configuration
.ws.config.port:5002;  / WebSocket port (separate from main KDB+ port)
.ws.config.enableTLS:1b;  / Enable TLS (requires TLS license)
.ws.config.certFile:`$getenv[`TLS_CERT_FILE];  / Path to TLS certificate
.ws.config.keyFile:`$getenv[`TLS_KEY_FILE];   / Path to private key

/ Client management
.ws.clients:()!();  / Dictionary to track WebSocket clients
.ws.subscriptions:()!();  / Client subscriptions

/ WebSocket message handlers
.z.ws:{[msg]
  handle:.z.w;
  
  / Parse incoming message (expect JSON)
  cmd:@[.j.k;msg;{[err] `error`msg!("parse_error";err)}];
  
  if[`error~first cmd;
    .ws.sendError[handle;"Invalid JSON message"];
    :();
  ];
  
  / Handle different command types
  if[`subscribe~cmd`action;
    .ws.handleSubscribe[handle;cmd];
  ];
  
  if[`unsubscribe~cmd`action;
    .ws.handleUnsubscribe[handle;cmd];
  ];
  
  if[`query~cmd`action;
    .ws.handleQuery[handle;cmd];
  ];
 }

/ WebSocket connection opened
.z.wo:{[handle]
  show "WebSocket client connected: ",string handle;
  .ws.clients[handle]:`connected`time!(1b;.z.P);
  
  / Send welcome message
  welcome:`action`message`timestamp!(`welcome;"Connected to KDB+ Ticker System";.z.P);
  .ws.send[handle;welcome];
 }

/ WebSocket connection closed
.z.wc:{[handle]
  show "WebSocket client disconnected: ",string handle;
  
  / Clean up client data
  .ws.clients:.ws.clients _ handle;
  .ws.subscriptions:.ws.subscriptions _ handle;
 }

/ Send JSON message to client
.ws.send:{[handle;data]
  msg:.j.j data;
  neg[handle] msg;
 }

/ Send error message
.ws.sendError:{[handle;errorMsg]
  error:`action`error`timestamp!((`error;errorMsg;.z.P));
  .ws.send[handle;error];
 }

/ Handle subscription requests
.ws.handleSubscribe:{[handle;cmd]
  if[not `table in key cmd;
    .ws.sendError[handle;"Missing table parameter"];
    :();
  ];
  
  table:cmd`table;
  
  / Validate table exists
  if[not table in `ticker`trades`bars;
    .ws.sendError[handle;"Invalid table name"];
    :();
  ];
  
  / Add subscription
  if[not handle in key .ws.subscriptions;
    .ws.subscriptions[handle]:();
  ];
  .ws.subscriptions[handle]:.ws.subscriptions[handle],table;
  
  / Send confirmation
  confirm:`action`table`message!(`subscribed;table;"Subscribed to ",string table);
  .ws.send[handle;confirm];
  
  / Send recent data (last 10 rows)
  recent:neg[10]#value table;
  if[count recent;
    data:`action`table`data`timestamp!(`data;table;recent;.z.P);
    .ws.send[handle;data];
  ];
 }

/ Handle unsubscribe requests
.ws.handleUnsubscribe:{[handle;cmd]
  if[not `table in key cmd;
    .ws.sendError[handle;"Missing table parameter"];
    :();
  ];
  
  table:cmd`table;
  
  if[handle in key .ws.subscriptions;
    .ws.subscriptions[handle]:.ws.subscriptions[handle] except table;
  ];
  
  confirm:`action`table`message!(`unsubscribed;table;"Unsubscribed from ",string table);
  .ws.send[handle;confirm];
 }

/ Handle query requests
.ws.handleQuery:{[handle;cmd]
  if[not `query in key cmd;
    .ws.sendError[handle;"Missing query parameter"];
    :();
  ];
  
  queryStr:cmd`query;
  
  / Execute query safely
  result:@[value;queryStr;{[err] `error`msg!((`query_error;err))}];
  
  if[`error~first result;
    .ws.sendError[handle;"Query error: ",last result];
    :();
  ];
  
  / Send query result
  response:`action`query`result`timestamp!(`query_result;queryStr;result;.z.P);
  .ws.send[handle;response];
 }

/ Broadcast updates to subscribed clients
.ws.broadcast:{[table;data]
  subscribedClients:key[.ws.subscriptions] where {table in .ws.subscriptions x} each key .ws.subscriptions;
  
  if[count subscribedClients;
    message:`action`table`data`timestamp!(`update;table;data;.z.P);
    {.ws.send[x;message]} each subscribedClients;
  ];
 }

/ Enhanced upd function that broadcasts to WebSocket clients
.ws.upd:{[t;x]
  / Call original upd function
  upd[t;x];
  
  / Broadcast to WebSocket subscribers
  .ws.broadcast[t;x];
 }

/ Override the upd function
upd:.ws.upd;

/ Analytics API endpoints via WebSocket
.ws.handleAnalytics:{[handle;cmd]
  if[not `analytics in key cmd;
    .ws.sendError[handle;"Missing analytics parameter"];
    :();
  ];
  
  analytics:cmd`analytics;
  
  result:$[
    `vwap~analytics; vwap[ticker];
    `spread~analytics; spread[ticker];
    `volatility~analytics; historicalVolatility[ticker;60];
    `volume~analytics; select sum volume by sym from ticker;
    `error`msg!("Unknown analytics function")
  ];
  
  if[`error~first result;
    .ws.sendError[handle;"Analytics error: ",last result];
    :();
  ];
  
  response:`action`analytics`result`timestamp!(`analytics_result;analytics;result;.z.P);
  .ws.send[handle;response];
 }

/ TLS Configuration (requires KDB+ TLS license)
.ws.setupTLS:{[]
  if[.ws.config.enableTLS;
    if[null .ws.config.certFile;
      -1"Warning: TLS enabled but no certificate file specified";
      :0b;
    ];
    
    / Set TLS certificate and key
    system"C ",1_string .ws.config.certFile;
    system"K ",1_string .ws.config.keyFile;
    
    / Enable TLS
    system"e 1";
    -1"TLS enabled for WebSocket connections";
    :1b;
  ];
  
  -1"TLS disabled - using plain WebSocket connections";
  0b
 }

/ Start WebSocket server
.ws.start:{[]
  -1"Starting KDB+ WebSocket Server...";
  
  / Setup TLS if configured
  .ws.setupTLS[];
  
  / Start listening on WebSocket port
  system"p ",string .ws.config.port;
  
  -1"WebSocket server listening on port ",string .ws.config.port;
  -1"Use ",$[.ws.config.enableTLS;"wss";"ws"],"://localhost:",string[.ws.config.port];
  -1"";
  -1"Available commands:";
  -1"  {\"action\":\"subscribe\",\"table\":\"ticker\"}";
  -1"  {\"action\":\"unsubscribe\",\"table\":\"ticker\"}";
  -1"  {\"action\":\"query\",\"query\":\"select from ticker where sym=`ETHUSDT\"}";
  -1"  {\"action\":\"analytics\",\"analytics\":\"vwap\"}";
 }

/ Load analytics functions
\l analytics/vwap.q
\l analytics/orderbook.q
\l analytics/volatility.q

/ Start the WebSocket server
.ws.start[]; 