# RELIM Algorithm Implementation - TV3 Data Mining Lab 2

An optimized implementation of the RELIM algorithm for frequent itemset mining, written in Julia.

## Project Structure

```
DM_Lab02/11/
├── src/
│   ├── algorithm/
│   │   ├── relim.jl       # Basic RELIM implementation
│   │   └── relim_opt.jl  # Optimized RELIM implementation
│   ├── utils.jl          # Utility functions
│   └── structures.jl    # Data structures
├── data/
│   ├── benchmark/      # Test datasets (chess, mushroom, retail, accidents, T10I4D100K)
│   ├── toy/            # Demo dataset (demo.txt from TV1)
│   ├── tools/          # External tools (spmf.jar)
│   └── results/        # Benchmark results (CSV files)
├── tests/
│   ├── runtests.jl         # Main test suite (36 tests)
│   └── test_benchmark.jl   # Benchmark experiments (b-f)
└── README.md
```

## Algorithms

### Basic RELIM
- Direct implementation of the RELIM algorithm based on the original paper
- Uses recursive approach for itemset generation

### Optimized RELIM (V3)
- Improved version with better memory management
- Hash-based filtering for candidate pruning
- Reduced computational overhead

## Requirements

- Julia 1.9+
- SPMF (Java) - for correctness verification
- Java Runtime Environment (JRE)

## Installation

1. Clone the repository:
```bash
cd DM_Lab02/11
```

2. Activate the project:
```bash
julia --project
```

3. Install dependencies (if needed):
```julia
julia> ]
pkg> add ArgParse
```

## Running Tests

Run all tests:
```bash
julia --project tests/runtests.jl
```

Expected output:
```
Test Summary:                  | Pass  Total  Time
Relim Correctness — 6 Datasets |   15     15  2.3s
Test Summary:                  | Pass  Total  Time
Relim Correctness vs SPMF        |   21     21  30.9s

✅ Tất cả bài Test đã PASS!
```

## Running Benchmarks

Run all benchmark experiments:
```bash
julia --project tests/test_benchmark.jl
```

This will generate CSV files in `data/results/`:
- `time_fi_results.csv` - Execution time and FI count vs minsup
- `memory_results.csv` - Memory usage comparison
- `scalability_results.csv` - Scalability analysis
- `txlen_results.csv` - Transaction length impact

## Benchmark Datasets

| Dataset      | Transactions | Description           |
|-------------|-------------|----------------------|
| chess.txt   | 3,196       | Chess board positions |
| mushroom.txt| 8,124       | Mushroom features    |
| retail.txt  | 88,162      | Retail transactions  |
| accidents.txt| 340,183    | Traffic accidents    |
| T10I4D100K  | 100,000     | Synthetic data       |

## Key Results

### Correctness
- 100% match with SPMF Java implementation across all datasets and minsup thresholds

### Performance
- Optimized version significantly faster than basic implementation
- Linear scalability with data size
- Memory efficient for large datasets

## Lab Requirements

| Requirement | Description                          |
|-------------|--------------------------------------|
| a) Correctness | Compare with SPMF Java (15 tests) |
| b) Time vs minsup | Measure execution time at various minsup thresholds |
| c) FI count vs minsup | Count frequent itemsets at different thresholds |
| d) Memory usage | Compare Basic vs Optimized at average minsup |
| e) Scalability | Test on retail subsets (10%, 25%, 50%, 75%, 100%) |
| f) Transaction length | Analyze impact of varying transaction lengths |

## References

- Toivonen, H. (1996). Sampling large databases for association rules.
- Zaki, M. J. (2000). Scalable algorithms for association mining.

## License

MIT License