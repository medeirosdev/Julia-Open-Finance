# ==============================================================================
# JuliaMarketFeeder.jl - Yahoo Finance Source
# ==============================================================================
#
# This module implements the Yahoo Finance data source for fetching historical
# market data. It uses the unofficial Yahoo Finance API v8 endpoint.
#
# API Reference:
#   Endpoint: https://query1.finance.yahoo.com/v8/finance/chart/{ticker}
#   Method: GET
#   Response: JSON with OHLCV data
#
# ==============================================================================

using HTTP
using JSON3
using DataFrames
using Dates

# ==============================================================================
# Main Data Fetching Function
# ==============================================================================

"""
    get_data(source::Yahoo, ticker::String; kwargs...) -> DataFrame

Fetch historical OHLCV data from Yahoo Finance.

# Arguments
- `source::Yahoo`: Yahoo Finance data source instance
- `ticker::String`: Stock ticker symbol (e.g., "AAPL", "PETR4.SA")

# Keyword Arguments
- `interval::String="1d"`: Data interval. Valid values:
  - Minutes: "1m", "2m", "5m", "15m", "30m", "60m", "90m"
  - Hours: "1h"
  - Days: "1d", "5d"
  - Weeks/Months: "1wk", "1mo", "3mo"
- `start_date::Union{DateTime, Nothing}=nothing`: Start date (defaults to 1 year ago)
- `end_date::Union{DateTime, Nothing}=nothing`: End date (defaults to now)

# Returns
- `DataFrame`: Table with columns:
  - `timestamp::DateTime`: Candle timestamp (UTC)
  - `open::Float64`: Opening price
  - `high::Float64`: Highest price
  - `low::Float64`: Lowest price
  - `close::Float64`: Closing price
  - `volume::Int64`: Trading volume
  - `adj_close::Float64`: Adjusted closing price (for dividends/splits)

# Examples
```julia
using JuliaMarketFeeder, Dates

# Fetch daily data for Apple (last year)
df = get_data(Yahoo(), "AAPL")

# Fetch hourly data for Petrobras with date range
df = get_data(
    Yahoo(), 
    "PETR4.SA",
    interval = "1h",
    start_date = DateTime(2024, 1, 1),
    end_date = DateTime(2024, 6, 30)
)

# Fetch 5-minute data (limited to last 7 days by Yahoo)
df = get_data(Yahoo(), "VALE3.SA", interval="5m")
```

# Notes
- Intraday data (< 1d interval) is limited to the last 7-60 days depending on interval
- All timestamps are returned in UTC
- Returns empty DataFrame if no data is available

# Throws
- `TickerNotFoundError`: If the ticker symbol is not found
- `APIError`: If the API request fails
- `DataParsingError`: If the response cannot be parsed

See also: [`Yahoo`](@ref), [`format_ticker`](@ref)
"""
function get_data(
    source::Yahoo,
    ticker::String;
    interval::String = "1d",
    start_date::Union{DateTime, Nothing} = nothing,
    end_date::Union{DateTime, Nothing} = nothing
)::DataFrame
    
    # Validate interval
    validate_interval(interval)
    
    # Set default date range (1 year of data)
    end_dt = isnothing(end_date) ? now(UTC) : end_date
    start_dt = isnothing(start_date) ? end_dt - Year(1) : start_date
    
    # Convert to Unix timestamps
    period1 = datetime_to_unix(start_dt)
    period2 = datetime_to_unix(end_dt)
    
    # Build API URL
    url = build_yahoo_url(source, ticker, interval, period1, period2)
    
    # Make HTTP request
    response = fetch_data(url, ticker)
    
    # Parse and return DataFrame
    return parse_yahoo_response(response, ticker)
end

# ==============================================================================
# URL Builder
# ==============================================================================

"""
    build_yahoo_url(source::Yahoo, ticker, interval, period1, period2) -> String

Build the Yahoo Finance API URL for chart data.

Internal function - not exported.
"""
function build_yahoo_url(
    source::Yahoo,
    ticker::String,
    interval::String,
    period1::Int64,
    period2::Int64
)::String
    base = source.base_url
    # URL encode the ticker (handles special characters)
    encoded_ticker = HTTP.escapeuri(ticker)
    
    return "$(base)/v8/finance/chart/$(encoded_ticker)?" *
           "period1=$(period1)&" *
           "period2=$(period2)&" *
           "interval=$(interval)&" *
           "includeAdjustedClose=true"
end

# ==============================================================================
# HTTP Request Handler
# ==============================================================================

"""
    fetch_data(url::String, ticker::String) -> String

Make HTTP GET request to Yahoo Finance API.

Handles common errors like rate limiting, network issues, and invalid tickers.
Internal function - not exported.
"""
function fetch_data(url::String, ticker::String)::String
    try
        response = HTTP.get(
            url,
            headers = [
                "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Accept" => "application/json"
            ],
            connect_timeout = 10,
            readtimeout = 30
        )
        
        return String(response.body)
        
    catch e
        if e isa HTTP.StatusError
            status = e.status
            
            if status == 404
                throw(TickerNotFoundError(ticker, "Yahoo Finance"))
            elseif status == 429
                throw(APIError(429, "Rate limit exceeded. Please wait before retrying.", "Yahoo"))
            elseif status >= 500
                throw(APIError(status, "Yahoo Finance server error. Try again later.", "Yahoo"))
            else
                throw(APIError(status, "HTTP request failed", "Yahoo"))
            end
            
        elseif e isa HTTP.TimeoutError
            throw(APIError(0, "Connection timeout. Check your internet connection.", "Yahoo"))
        else
            rethrow(e)
        end
    end
end

# ==============================================================================
# Response Parser
# ==============================================================================

"""
    parse_yahoo_response(response::String, ticker::String) -> DataFrame

Parse Yahoo Finance JSON response into a DataFrame.

Extracts OHLCV data from the nested JSON structure and creates a properly
typed DataFrame with named columns.

Internal function - not exported.
"""
function parse_yahoo_response(response::String, ticker::String)::DataFrame
    try
        data = JSON3.read(response)
        
        # Navigate to the result data
        chart = data[:chart]
        
        # Check for API errors
        if haskey(chart, :error) && !isnothing(chart[:error])
            error_msg = string(get(chart[:error], :description, "Unknown error"))
            throw(APIError(0, error_msg, "Yahoo"))
        end
        
        result = chart[:result]
        
        if isnothing(result) || isempty(result)
            throw(TickerNotFoundError(ticker, "Yahoo Finance"))
        end
        
        result_data = result[1]
        
        # Extract timestamps
        timestamps_raw = result_data[:timestamp]
        
        if isnothing(timestamps_raw) || isempty(timestamps_raw)
            # Return empty DataFrame with correct schema
            return empty_ohlcv_dataframe()
        end
        
        timestamps = [unix_to_datetime(Int(ts)) for ts in timestamps_raw]
        
        # Extract quote data
        quote_data = result_data[:indicators][:quote][1]
        
        # Extract OHLCV arrays (handle potential missing values)
        open_prices = safe_extract_array(quote_data, :open)
        high_prices = safe_extract_array(quote_data, :high)
        low_prices = safe_extract_array(quote_data, :low)
        close_prices = safe_extract_array(quote_data, :close)
        volumes = safe_extract_int_array(quote_data, :volume)
        
        # Extract adjusted close (may not exist for all data)
        adj_close = if haskey(result_data[:indicators], :adjclose) && 
                       !isnothing(result_data[:indicators][:adjclose]) &&
                       !isempty(result_data[:indicators][:adjclose])
            safe_extract_array(result_data[:indicators][:adjclose][1], :adjclose)
        else
            close_prices  # Fallback to regular close
        end
        
        # Build DataFrame
        df = DataFrame(
            timestamp = timestamps,
            open = open_prices,
            high = high_prices,
            low = low_prices,
            close = close_prices,
            volume = volumes,
            adj_close = adj_close
        )
        
        # Remove rows with all missing OHLC values
        filter!(row -> !all(ismissing, [row.open, row.high, row.low, row.close]), df)
        
        return df
        
    catch e
        if e isa MarketFeederError
            rethrow(e)
        else
            raw_preview = first(response, 500)
            throw(DataParsingError("Failed to parse Yahoo Finance response: $(e)", raw_preview))
        end
    end
end

# ==============================================================================
# Helper Functions
# ==============================================================================

"""
    safe_extract_array(data, key::Symbol) -> Vector{Union{Float64, Missing}}

Safely extract a numeric array from JSON data, converting nulls to missing.
"""
function safe_extract_array(data, key::Symbol)::Vector{Union{Float64, Missing}}
    if !haskey(data, key) || isnothing(data[key])
        return Union{Float64, Missing}[]
    end
    
    raw = data[key]
    return [isnothing(v) ? missing : Float64(v) for v in raw]
end

"""
    safe_extract_int_array(data, key::Symbol) -> Vector{Union{Int64, Missing}}

Safely extract an integer array from JSON data, converting nulls to missing.
"""
function safe_extract_int_array(data, key::Symbol)::Vector{Union{Int64, Missing}}
    if !haskey(data, key) || isnothing(data[key])
        return Union{Int64, Missing}[]
    end
    
    raw = data[key]
    return [isnothing(v) ? missing : Int64(v) for v in raw]
end

"""
    empty_ohlcv_dataframe() -> DataFrame

Create an empty DataFrame with the standard OHLCV schema.
"""
function empty_ohlcv_dataframe()::DataFrame
    return DataFrame(
        timestamp = DateTime[],
        open = Float64[],
        high = Float64[],
        low = Float64[],
        close = Float64[],
        volume = Int64[],
        adj_close = Float64[]
    )
end
