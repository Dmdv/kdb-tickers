// KDB+ Initialization Script for Ticker Data
// This script sets up the schema and tables for storing real-time ticker data

\p 5001  / Set port to 5001
\S 42    / Set random seed for reproducibility

// Create ticker table schema
ticker:([]
  time:`timestamp$();
  sym:`symbol$();
  bid:`float$();
  ask:`float$();
  bidSize:`float$();
  askSize:`float$();
  last:`float$();
  volume:`float$()
 )

// Create trade table for processed trades
trades:([]
  time:`timestamp$();
  sym:`symbol$();
  price:`float$();
  size:`float$();
  side:`symbol$()
 )

// Create minute bars table
bars:([]
  time:`timestamp$();
  sym:`symbol$();
  open:`float$();
  high:`float$();
  low:`float$();
  close:`float$();
  volume:`float$();
  vwap:`float$();
  count:`long$()
 )

// Helper functions for data insertion
.u.upd:{[t;x]
  t insert x;
  }

// Subscribe function for real-time updates
.u.sub:{[t;s]
  // Implementation for subscription logic
  }

// Initialize system tables
system"l ."

// Display startup message
-1"KDB+ ticker database initialized on port 5001";
-1"Tables: ticker, trades, bars";
-1"Ready to receive data...";
