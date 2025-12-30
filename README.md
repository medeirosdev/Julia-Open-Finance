# JuliaOpenFinance.jl

[![Julia](https://img.shields.io/badge/Julia-1.9+-blue.svg)](https://julialang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Part of the [Open Finance Julia](https://github.com/medeirosdev/Julia-Open-Finance) project.**

A high-performance Julia package for fetching financial market data from multiple sources.

## Features

- **Yahoo Finance Support**: Stocks, ETFs, and indices from worldwide markets (NYSE, NASDAQ, B3, LSE, etc.)
- **Type-Safe**: Returns properly typed `DataFrame` with `Float64` prices and `DateTime` timestamps
- **Error Handling**: Comprehensive error types for API failures, invalid tickers, and parsing issues
- **Multiple Intervals**: From 1-minute intraday to monthly data
- **Brazilian Market**: Native support for B3 stocks with `.SA` suffix handling

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/medeirosdev/Julia-Open-Finance")
```

Or for development:

```julia
] dev path/to/JuliaMarketFeeder
```

## Quick Start

```julia
using JuliaMarketFeeder
using Dates

# Create a Yahoo Finance data source
yahoo = Yahoo()

# Fetch daily data for Apple (last year)
df = get_data(yahoo, "AAPL")

# Fetch Brazilian stocks
df = get_data(yahoo, "PETR4.SA", interval="1d")

# Or use the helper to format tickers
ticker = format_ticker("VALE3", :brazil)  # Returns "VALE3.SA"
df = get_data(yahoo, ticker)

# Custom date range
df = get_data(
    yahoo, 
    "MSFT",
    interval = "1d",
    start_date = DateTime(2023, 1, 1),
    end_date = DateTime(2024, 1, 1)
)
```

## Supported Intervals

| Interval | Description |
|----------|-------------|
| `1m`, `2m`, `5m`, `15m`, `30m` | Minutes (limited to last 7-60 days) |
| `60m`, `90m`, `1h` | Hours |
| `1d`, `5d` | Days |
| `1wk`, `1mo`, `3mo` | Weeks/Months |

## Market Suffixes

Use `format_ticker` to automatically add market suffixes:

```julia
format_ticker("PETR4", :brazil)  # "PETR4.SA"
format_ticker("HSBA", :uk)       # "HSBA.L"
format_ticker("VOW", :germany)   # "VOW.DE"
format_ticker("AAPL", :usa)      # "AAPL"
```

## DataFrame Output

The `get_data` function returns a `DataFrame` with the following columns:

| Column | Type | Description |
|--------|------|-------------|
| `timestamp` | `DateTime` | Candle timestamp (UTC) |
| `open` | `Float64` | Opening price |
| `high` | `Float64` | Highest price |
| `low` | `Float64` | Lowest price |
| `close` | `Float64` | Closing price |
| `volume` | `Int64` | Trading volume |
| `adj_close` | `Float64` | Adjusted close (dividends/splits) |

## Error Handling

The package provides custom error types for better error handling:

```julia
try
    df = get_data(Yahoo(), "INVALID_TICKER")
catch e
    if e isa TickerNotFoundError
        println("Ticker not found: $(e.ticker)")
    elseif e isa APIError
        println("API error ($(e.status_code)): $(e.message)")
    elseif e isa DataParsingError
        println("Parse error: $(e.message)")
    end
end
```

## Roadmap

- [ ] Binance integration (cryptocurrencies)
- [ ] Batch downloads (`get_data_batch`)
- [ ] Async/parallel requests
- [ ] Rate limiting
- [ ] WebSocket real-time data

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Yahoo Finance for providing market data
- The Julia community for amazing packages like HTTP.jl, JSON3.jl, and DataFrames.jl

## Disclaimer

This package uses the unofficial Yahoo Finance API. It is not affiliated with Yahoo and the API may change without notice. Use at your own risk for production applications.
