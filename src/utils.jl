# ==============================================================================
# JuliaMarketFeeder.jl - Utilities Module
# ==============================================================================
#
# This module provides utility functions for data conversion, ticker formatting,
# and error handling. These helpers are used internally by data source 
# implementations and are also exported for user convenience.
#
# ==============================================================================

using Dates

# ==============================================================================
# Timestamp Conversion
# ==============================================================================

"""
    unix_to_datetime(timestamp::Integer) -> DateTime

Convert a Unix timestamp (seconds since epoch) to a Julia DateTime object.

# Arguments
- `timestamp::Integer`: Unix timestamp in seconds

# Returns
- `DateTime`: Corresponding Julia DateTime in UTC

# Examples
```julia
julia> unix_to_datetime(1704067200)
2024-01-01T00:00:00

julia> unix_to_datetime(0)
1970-01-01T00:00:00
```

# Notes
- All timestamps are treated as UTC
- Use `TimeZones.jl` for timezone conversions if needed
"""
function unix_to_datetime(timestamp::Integer)::DateTime
    return unix2datetime(timestamp)
end

"""
    datetime_to_unix(dt::DateTime) -> Int64

Convert a Julia DateTime object to Unix timestamp (seconds since epoch).

# Arguments
- `dt::DateTime`: Julia DateTime object (assumed UTC)

# Returns
- `Int64`: Unix timestamp in seconds

# Examples
```julia
julia> datetime_to_unix(DateTime(2024, 1, 1))
1704067200

julia> datetime_to_unix(DateTime(1970, 1, 1))
0
```
"""
function datetime_to_unix(dt::DateTime)::Int64
    return round(Int64, datetime2unix(dt))
end

# ==============================================================================
# Ticker Formatting
# ==============================================================================

"""
    format_ticker(ticker::String, market::Symbol) -> String

Format a ticker symbol with the appropriate market suffix for Yahoo Finance.

Yahoo Finance requires market-specific suffixes for non-US stocks:
- Brazilian stocks: `.SA` (e.g., "PETR4" → "PETR4.SA")
- UK stocks: `.L` (e.g., "HSBA" → "HSBA.L")
- German stocks: `.DE` (e.g., "VOW" → "VOW.DE")

# Arguments
- `ticker::String`: Base ticker symbol (e.g., "PETR4", "AAPL")
- `market::Symbol`: Market identifier (`:brazil`, `:b3`, `:usa`, `:uk`, `:germany`)

# Returns
- `String`: Formatted ticker with appropriate suffix

# Examples
```julia
julia> format_ticker("PETR4", :brazil)
"PETR4.SA"

julia> format_ticker("VALE3", :b3)
"VALE3.SA"

julia> format_ticker("AAPL", :usa)
"AAPL"

julia> format_ticker("HSBA", :uk)
"HSBA.L"
```

# Throws
- `ArgumentError`: If the market symbol is not recognized

See also: [`MARKET_SUFFIXES`](@ref)
"""
function format_ticker(ticker::String, market::Symbol)::String
    # Already has a suffix? Return as-is
    if contains(ticker, ".")
        return ticker
    end
    
    suffix = get(MARKET_SUFFIXES, market, nothing)
    if isnothing(suffix)
        supported = join(keys(MARKET_SUFFIXES), ", :")
        throw(ArgumentError("Unknown market: :$market. Supported: :$supported"))
    end
    
    return ticker * suffix
end

"""
    format_ticker(ticker::String) -> String

Pass-through for already formatted tickers. Returns the input unchanged.

# Arguments
- `ticker::String`: Ticker symbol (may or may not have suffix)

# Returns
- `String`: Same ticker symbol

# Examples
```julia
julia> format_ticker("PETR4.SA")
"PETR4.SA"

julia> format_ticker("AAPL")
"AAPL"
```
"""
format_ticker(ticker::String)::String = ticker

# ==============================================================================
# Interval Validation
# ==============================================================================

"""
    validate_interval(interval::String) -> Bool

Check if the given interval is supported by Yahoo Finance.

# Arguments
- `interval::String`: Interval code (e.g., "1d", "1h", "5m")

# Returns
- `Bool`: `true` if valid, throws error otherwise

# Throws
- `ArgumentError`: If interval is not recognized

# Examples
```julia
julia> validate_interval("1d")
true

julia> validate_interval("invalid")
ERROR: ArgumentError: Invalid interval: invalid
```

See also: [`VALID_INTERVALS`](@ref)
"""
function validate_interval(interval::String)::Bool
    if !haskey(VALID_INTERVALS, interval)
        valid = join(keys(VALID_INTERVALS), ", ")
        throw(ArgumentError("Invalid interval: $interval. Valid intervals: $valid"))
    end
    return true
end

# ==============================================================================
# Error Types
# ==============================================================================

"""
    MarketFeederError <: Exception

Base exception type for JuliaMarketFeeder errors.

All package-specific errors inherit from this type, allowing users to catch
all JuliaMarketFeeder errors with a single catch block.

# Example
```julia
try
    df = get_data(Yahoo(), "INVALID")
catch e::MarketFeederError
    @warn "MarketFeeder error" exception=e
end
```
"""
abstract type MarketFeederError <: Exception end

"""
    APIError <: MarketFeederError

Error returned by the financial data API.

# Fields
- `status_code::Int`: HTTP status code
- `message::String`: Error message from API or description
- `source::String`: Name of the data source (e.g., "Yahoo")
"""
struct APIError <: MarketFeederError
    status_code::Int
    message::String
    source::String
end

function Base.showerror(io::IO, e::APIError)
    print(io, "APIError($(e.source)): HTTP $(e.status_code) - $(e.message)")
end

"""
    DataParsingError <: MarketFeederError

Error parsing the response data from the API.

# Fields
- `message::String`: Description of the parsing error
- `raw_data::String`: First 200 characters of the raw response (for debugging)
"""
struct DataParsingError <: MarketFeederError
    message::String
    raw_data::String
end

function Base.showerror(io::IO, e::DataParsingError)
    print(io, "DataParsingError: $(e.message)")
    if !isempty(e.raw_data)
        print(io, "\nRaw data preview: $(first(e.raw_data, 200))...")
    end
end

"""
    TickerNotFoundError <: MarketFeederError

The requested ticker symbol was not found.

# Fields
- `ticker::String`: The ticker that was not found
- `source::String`: Name of the data source
"""
struct TickerNotFoundError <: MarketFeederError
    ticker::String
    source::String
end

function Base.showerror(io::IO, e::TickerNotFoundError)
    print(io, "TickerNotFoundError: '$(e.ticker)' not found on $(e.source)")
end
