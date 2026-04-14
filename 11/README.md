# Data Mining Project: RELIM Algorithm Implementation

An optimized implementation of the RELIM algorithm for frequent itemset mining, developed in Julia.

## Project Structure

```text
DM_Lab02/11/
├── Project.toml        # Julia project environment properties
├── Manifest.toml       # Julia project dependencies resolution
├── src/
│   ├── algorithm/
│   │   ├── relim.jl      # Basic RELIM implementation
│   │   └── relim_opt.jl  # Optimized RELIM implementation (V3)
│   ├── utils.jl          # Utility functions for I/O
│   └── structures.jl     # Data structures
├── data/
│   ├── benchmark/      # Benchmark datasets (chess, mushroom, retail, accidents, T10I4D100K)
│   ├── toy/            # Toy dataset for demonstration (demo.txt)
│   ├── tools/          # External verification tools (spmf.jar)
│   └── results/        # Exported benchmark analytical results (CSV files)
├── notebooks/
│   ├── application.ipynb           # Association Rules mining from frequent itemsets
│   ├── demo.ipynb                  # Data visualization for benchmark metrics
│   └── output_prac_applicaiton.txt # Execution output for practical application
├── docs/
│   └── Relim_Opt_V3_Knowledge.md   # Documentation on algorithm theory and optimizations
├── tests/
│   ├── runtests.jl         # Main test suite for correctness verification
│   └── test_benchmark.jl   # Scripts for performance benchmarking experiments
└── README.md
```

## Algorithms

### Basic RELIM
- Direct implementation of the RELIM algorithm based on the original theoretical framework.
- Utilizes the recursive approach for frequent itemset generation.

### Optimized RELIM (V3)
- Enhanced implementation focusing on advanced memory management.
- Implements hash-based filtering and data structures tailored for candidate pruning.
- Significantly reduces computational and garbage collection overhead.

## Requirements

- Julia 1.9+
- Python 3.x (with Jupyter Notebook, Pandas, Matplotlib) - For Data Visualization & Association Rules mapping.
- SPMF (Java) - For algorithmic correctness verification.
- Java Runtime Environment (JRE)

## Installation

1. Clone the repository and navigate to the project directory:
```bash
cd 11
```

2. Activate the Julia environment:
```bash
julia --project
```

3. Install required Julia dependencies:
```julia
julia> ]
pkg> instantiate
```

4. Exit the Julia package manager to return to the system terminal:
- Press `Backspace` to return to the `julia>` prompt.
- Type `exit()` and press Enter (or press `Ctrl+D`) to return to `...\DM_Lab02\11>`.

## Running Tests

From your system terminal, execute the automated correctness test suite to verify the outputs against the SPMF reference tool:
```bash
julia --project tests/runtests.jl
```

Expected output format:
```text
Test Summary:                  | Pass  Total  Time
Relim Correctness — 6 Datasets |   15     15  2.3s
Test Summary:                  | Pass  Total  Time
Relim Correctness vs SPMF      |   21     21  30.9s

Tất cả bài Test đã PASS!
```

## Running Benchmarks

Execute the automated benchmark experiments:
```bash
julia --project tests/test_benchmark.jl
```

This script will evaluate the algorithm and automatically generate analytical CSV files in the `data/results/` directory:
- `time_fi_results.csv`: Execution time and frequent itemset count relative to minimum support thresholds.
- `memory_results.csv`: RAM usage capacity comparison.
- `scalability_results.csv`: Scalability analysis across varying dataset sizes.
- `txlen_results.csv`: Execution efficiency across differing transaction lengths.

## Benchmark Datasets

| Dataset       | Transactions | Description                  |
|---------------|--------------|------------------------------|
| chess.txt     | 3,196        | Chess board positions        |
| mushroom.txt  | 8,124        | Mushroom structural features |
| retail.txt    | 88,162       | Retail market basket data    |
| accidents.txt | 340,183      | Belgian traffic accidents    |
| T10I4D100K    | 100,000      | IBM Quest Synthetic data     |

## Key Analytical Results

### Correctness Validation
- Demonstrates 100% output parity with the industry-standard SPMF Java implementation across all benchmarked datasets and variations of minimum support thresholds.

### Performance Optimization
- The optimized RELIM variant achieves significantly accelerated execution speeds compared to the basic baseline by minimizing heap allocations via the algorithm's optimized memory tracking.
- Showcases linear and stable computational scalability with incrementally growing dataset volumes.
- Manifests remarkable memory efficiency suitable for processing exceedingly large transaction environments.

## Lab Evaluation Metrics

| Requirement | Description |
|-------------|-------------|
| a) Correctness | Rigorous comparison against the SPMF Java reference model |
| b) Time vs minsup | Measurement of execution duration at diverse minsup factors |
| c) FI count vs minsup | Quantification of frequent itemsets detected at varying thresholds |
| d) Memory usage | Validation of peak memory footprint between Basic vs Optimized versions |
| e) Scalability | Stress test deployed on iterative subsets of the retail dataset (10% to 100%) |
| f) Transaction length | Impact analysis of variable transaction payload lengths |


## Application & Visualization

**Note:** Please ensure you have run the benchmark experiments first to generate the necessary `.csv` datasets.

To review the analytical visualizations and the practical application of Association Rules, execute the Jupyter Notebooks located in the `notebooks/` directory:
- **`demo.ipynb`**: Provides comprehensive data visualization covering benchmark results (Execution time, Frequent Itemset counts, Peak Memory usage, and Scalability). Visualizations are plotted based on the `.csv` reports generated from `tests/test_benchmark.jl`.
- **`application.ipynb`**: Demonstrates a real-world application by executing the RELIM algorithm, processing frequent itemsets, and extracting the top-10 Association Rules sorted by the *Lift* metric.


## References

- Toivonen, H. (1996). Sampling large databases for association rules.
- Zaki, M. J. (2000). Scalable algorithms for association mining.

## License

MIT License