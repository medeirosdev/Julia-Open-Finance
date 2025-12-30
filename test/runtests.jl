# ==============================================================================
# JuliaMarketFeeder.jl - Test Suite
# ==============================================================================
#
# This file contains unit tests for the JuliaMarketFeeder package.
# Run with: julia --project=. -e "using Pkg; Pkg.test()"
#
# ==============================================================================

using Test
using JuliaMarketFeeder
using Dates
using DataFrames

@testset "JuliaMarketFeeder.jl" begin
    
    # ==========================================================================
    # Type System Tests
    # ==========================================================================
    
    @testset "Type System" begin
        @testset "Yahoo constructor" begin
            # Default constructor
            yahoo = Yahoo()
            @test yahoo.base_url == "https://query1.finance.yahoo.com"
            
            # Custom URL
            custom = Yahoo("https://custom.example.com")
            @test custom.base_url == "https://custom.example.com"
            
            # Type hierarchy
            @test Yahoo <: FinancialSource
        end
        
        @testset "Constants" begin
            # Valid intervals
            @test haskey(VALID_INTERVALS, "1d")
            @test haskey(VALID_INTERVALS, "1h")
            @test haskey(VALID_INTERVALS, "5m")
            @test !haskey(VALID_INTERVALS, "invalid")
            
            # Market suffixes
            @test MARKET_SUFFIXES[:brazil] == ".SA"
            @test MARKET_SUFFIXES[:b3] == ".SA"
            @test MARKET_SUFFIXES[:usa] == ""
            @test MARKET_SUFFIXES[:uk] == ".L"
        end
    end
    
    # ==========================================================================
    # Utility Function Tests
    # ==========================================================================
    
    @testset "Utility Functions" begin
        @testset "Timestamp conversion" begin
            # Unix to DateTime
            dt = unix_to_datetime(1704067200)
            @test dt == DateTime(2024, 1, 1, 0, 0, 0)
            
            # DateTime to Unix
            ts = datetime_to_unix(DateTime(2024, 1, 1))
            @test ts == 1704067200
            
            # Round-trip conversion
            original = DateTime(2024, 6, 15, 12, 30, 45)
            unix_ts = datetime_to_unix(original)
            converted = unix_to_datetime(unix_ts)
            @test converted == original
        end
        
        @testset "Ticker formatting" begin
            # Brazilian stocks
            @test format_ticker("PETR4", :brazil) == "PETR4.SA"
            @test format_ticker("VALE3", :b3) == "VALE3.SA"
            
            # US stocks (no suffix)
            @test format_ticker("AAPL", :usa) == "AAPL"
            
            # UK stocks
            @test format_ticker("HSBA", :uk) == "HSBA.L"
            @test format_ticker("HSBA", :london) == "HSBA.L"
            
            # Already formatted (passthrough)
            @test format_ticker("PETR4.SA") == "PETR4.SA"
            @test format_ticker("AAPL") == "AAPL"
            
            # Invalid market
            @test_throws ArgumentError format_ticker("AAPL", :invalid_market)
        end
        
        @testset "Interval validation" begin
            # Valid intervals
            @test JuliaMarketFeeder.validate_interval("1d") == true
            @test JuliaMarketFeeder.validate_interval("1h") == true
            @test JuliaMarketFeeder.validate_interval("5m") == true
            
            # Invalid interval
            @test_throws ArgumentError JuliaMarketFeeder.validate_interval("invalid")
            @test_throws ArgumentError JuliaMarketFeeder.validate_interval("2d")
        end
    end
    
    # ==========================================================================
    # Error Type Tests
    # ==========================================================================
    
    @testset "Error Types" begin
        @testset "APIError" begin
            err = APIError(404, "Not found", "Yahoo")
            @test err isa MarketFeederError
            @test err.status_code == 404
            @test err.message == "Not found"
            @test err.source == "Yahoo"
            
            # Test error display
            io = IOBuffer()
            showerror(io, err)
            msg = String(take!(io))
            @test contains(msg, "404")
            @test contains(msg, "Yahoo")
        end
        
        @testset "TickerNotFoundError" begin
            err = TickerNotFoundError("INVALID", "Yahoo Finance")
            @test err isa MarketFeederError
            @test err.ticker == "INVALID"
            
            io = IOBuffer()
            showerror(io, err)
            msg = String(take!(io))
            @test contains(msg, "INVALID")
        end
        
        @testset "DataParsingError" begin
            err = DataParsingError("Parse failed", "{invalid json}")
            @test err isa MarketFeederError
            @test err.message == "Parse failed"
        end
    end
    
    # ==========================================================================
    # Integration Tests (require network)
    # ==========================================================================
    
    @testset "Yahoo Finance Integration" begin
        # Note: These tests require internet connection
        # They may be skipped in CI environments without network access
        
        @testset "Fetch real data" begin
            try
                yahoo = Yahoo()
                
                # Fetch Apple daily data
                df = get_data(yahoo, "AAPL", interval="1d")
                
                # Verify DataFrame structure
                @test df isa DataFrame
                @test nrow(df) > 0
                
                # Verify columns exist
                @test :timestamp in propertynames(df)
                @test :open in propertynames(df)
                @test :high in propertynames(df)
                @test :low in propertynames(df)
                @test :close in propertynames(df)
                @test :volume in propertynames(df)
                @test :adj_close in propertynames(df)
                
                # Verify data types
                @test eltype(df.timestamp) <: DateTime
                @test eltype(df.close) <: Union{Float64, Missing}
                
                # Basic data validation
                first_row = first(df)
                @test !ismissing(first_row.timestamp)
                
                println("✓ Successfully fetched $(nrow(df)) rows for AAPL")
                
            catch e
                if e isa HTTP.TimeoutError || e isa Base.IOError
                    @warn "Network unavailable, skipping integration test"
                    @test_skip "Network tests skipped"
                else
                    rethrow(e)
                end
            end
        end
        
        @testset "Brazilian stock" begin
            try
                yahoo = Yahoo()
                df = get_data(yahoo, "PETR4.SA", interval="1d")
                
                @test df isa DataFrame
                @test nrow(df) > 0
                
                println("✓ Successfully fetched $(nrow(df)) rows for PETR4.SA")
                
            catch e
                if e isa HTTP.TimeoutError || e isa Base.IOError
                    @warn "Network unavailable, skipping integration test"
                    @test_skip "Network tests skipped"
                else
                    rethrow(e)
                end
            end
        end
        
        @testset "Date range" begin
            try
                yahoo = Yahoo()
                
                start_dt = DateTime(2024, 1, 1)
                end_dt = DateTime(2024, 3, 31)
                
                df = get_data(
                    yahoo, 
                    "MSFT",
                    interval = "1d",
                    start_date = start_dt,
                    end_date = end_dt
                )
                
                @test df isa DataFrame
                @test nrow(df) > 0
                
                # Verify dates are within range (with some tolerance for market hours)
                @test minimum(df.timestamp) >= start_dt - Day(1)
                @test maximum(df.timestamp) <= end_dt + Day(1)
                
                println("✓ Date range query returned $(nrow(df)) rows")
                
            catch e
                if e isa HTTP.TimeoutError || e isa Base.IOError
                    @warn "Network unavailable, skipping integration test"
                    @test_skip "Network tests skipped"
                else
                    rethrow(e)
                end
            end
        end
        
        @testset "Invalid ticker" begin
            try
                yahoo = Yahoo()
                
                @test_throws TickerNotFoundError get_data(yahoo, "INVALIDTICKER12345")
                
            catch e
                if e isa HTTP.TimeoutError || e isa Base.IOError
                    @warn "Network unavailable, skipping integration test"
                    @test_skip "Network tests skipped"
                else
                    rethrow(e)
                end
            end
        end
    end
    
end  # Main testset

println("\n✅ All tests completed!")
