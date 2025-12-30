# ==============================================================================
# JuliaMarketFeeder.jl - Types Module
# ==============================================================================
#
# This module defines the core type system for the JuliaMarketFeeder package.
# It uses Julia's multiple dispatch paradigm to provide a flexible and 
# extensible architecture for different financial data sources.
#
# Design Philosophy:
# - Use abstract types as the base for financial data sources
# - Each source (Yahoo, Binance, etc.) is a concrete subtype
# - Multiple dispatch selects the appropriate implementation based on source type
#
# ==============================================================================

"""
    FinancialSource

Abstract type representing a financial data source.

All data source implementations (Yahoo, Binance, etc.) must be subtypes of this 
abstract type. This enables multiple dispatch to select the appropriate 
`get_data` implementation based on the data source.

# Examples
```julia
struct Yahoo <: FinancialSource end
struct Binance <: FinancialSource end
```

# Extended Help
When implementing a new data source:
1. Create a struct that subtypes `FinancialSource`
2. Implement `get_data(::YourSource, ticker; kwargs...)` method
3. Export the new type from the main module
"""
abstract type FinancialSource end

# ==============================================================================
# Yahoo Finance Source
# ==============================================================================

"""
    Yahoo <: FinancialSource

Data source for Yahoo Finance API.

Yahoo Finance provides historical and real-time data for stocks, ETFs, 
mutual funds, and indices from markets worldwide. Supports exchanges like 
NYSE, NASDAQ, B3 (Brazil), LSE (London), and many others.

# Fields
- `base_url::String`: Base URL for the Yahoo Finance API (default: query1.finance.yahoo.com)

# Constructor
```julia
Yahoo()  # Uses default base URL
Yahoo("https://custom-proxy.example.com")  # Custom proxy URL
```

# Notes
- Yahoo Finance API is unofficial and may change without notice
- Brazilian stocks require `.SA` suffix (e.g., "PETR4.SA")
- Use `format_ticker` helper to automatically add market suffixes

# Examples
```julia
using JuliaMarketFeeder

# Default configuration
source = Yahoo()

# Get historical data for Petrobras
df = get_data(source, "PETR4.SA", interval="1d")
```

See also: [`get_data`](@ref), [`format_ticker`](@ref)
"""
struct Yahoo <: FinancialSource 
    base_url::String
end

# Default constructor with official Yahoo Finance endpoint
Yahoo() = Yahoo("https://query1.finance.yahoo.com")

# ==============================================================================
# Interval Validation
# ==============================================================================

"""
    VALID_INTERVALS::Dict{String, String}

Dictionary mapping interval codes to human-readable descriptions.
Used for validation and documentation purposes.
"""
const VALID_INTERVALS = Dict{String, String}(
    "1m"  => "1 minute",
    "2m"  => "2 minutes",
    "5m"  => "5 minutes",
    "15m" => "15 minutes",
    "30m" => "30 minutes",
    "60m" => "60 minutes",
    "90m" => "90 minutes",
    "1h"  => "1 hour",
    "1d"  => "1 day",
    "5d"  => "5 days",
    "1wk" => "1 week",
    "1mo" => "1 month",
    "3mo" => "3 months"
)

"""
    MARKET_SUFFIXES::Dict{Symbol, String}

Dictionary mapping market symbols to Yahoo Finance ticker suffixes.

# Supported Markets
- `:brazil` or `:b3` → `.SA` (São Paulo Stock Exchange)
- `:usa` → `` (no suffix for US markets)
- `:uk` → `.L` (London Stock Exchange)
- `:germany` → `.DE` (Frankfurt Stock Exchange)
"""
const MARKET_SUFFIXES = Dict{Symbol, String}(
    :brazil  => ".SA",
    :b3      => ".SA",
    :usa     => "",
    :uk      => ".L",
    :london  => ".L",
    :germany => ".DE",
    :japan   => ".T",
    :tokyo   => ".T"
)
