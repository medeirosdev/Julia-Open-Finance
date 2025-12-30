# ==============================================================================
# JuliaMarketFeeder.jl
# ==============================================================================
#
# A high-performance Julia package for fetching financial market data.
# 
# Supports multiple data sources:
#   - Yahoo Finance (stocks, ETFs, indices worldwide)
#   - Binance (cryptocurrencies) - Coming soon
#
# Features:
#   - Type-safe DataFrame output
#   - Comprehensive error handling
#   - Async/batch downloads (planned)
#   - Native Julia performance
#
# Repository: https://github.com/JuliaOpenFinance/JuliaMarketFeeder.jl
# License: MIT
#
# ==============================================================================

module JuliaMarketFeeder

# ==============================================================================
# Dependencies
# ==============================================================================

using HTTP
using JSON3
using DataFrames
using Dates

# ==============================================================================
# Module Includes
# ==============================================================================

# Type system and constants
include("types.jl")

# Utility functions and error types
include("utils.jl")

# Data source implementations
include("sources/yahoo.jl")

# ==============================================================================
# Public Exports
# ==============================================================================

# Abstract types
export FinancialSource

# Data sources
export Yahoo

# Main functions
export get_data

# Utility functions
export format_ticker
export unix_to_datetime
export datetime_to_unix

# Constants
export VALID_INTERVALS
export MARKET_SUFFIXES

# Error types
export MarketFeederError
export APIError
export DataParsingError
export TickerNotFoundError

# ==============================================================================
# Package Documentation
# ==============================================================================

"""
    JuliaMarketFeeder

A high-performance Julia package for fetching financial market data from 
multiple sources including Yahoo Finance and Binance.

# Quick Start
```julia
using JuliaMarketFeeder, Dates

# Create a Yahoo Finance data source
source = Yahoo()

# Fetch daily data for Apple
df = get_data(source, "AAPL")

# Fetch hourly data for a Brazilian stock
df = get_data(source, "PETR4.SA", interval="1h")

# Fetch data with custom date range
df = get_data(
    source, 
    "VALE3.SA",
    interval = "1d",
    start_date = DateTime(2023, 1, 1),
    end_date = DateTime(2024, 1, 1)
)
```

# Supported Data Sources
- `Yahoo()` - Yahoo Finance (stocks, ETFs, indices)
- `Binance()` - Binance exchange (coming soon)

# Helper Functions
- `format_ticker("PETR4", :brazil)` - Add market suffix
- `unix_to_datetime(timestamp)` - Convert Unix timestamp

See the documentation for more details.
"""
JuliaMarketFeeder

end # module
