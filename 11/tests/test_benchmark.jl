# tests/test_benchmark.jl
# =============================================================================
# TV3 - Level 3: Benchmark thời gian chạy & bộ nhớ cho cả 2 phiên bản
# Chạy: julia --project=. tests/test_benchmark.jl  (từ thư mục 11/)
# Output: data/benchmark_results.csv
# =============================================================================

# Include thuật toán (guard isdefined bên trong sẽ tránh load trùng)
include(joinpath(@__DIR__, "..", "src", "algorithm", "relim.jl"))
include(joinpath(@__DIR__, "..", "src", "algorithm", "relim_opt.jl"))

using .Algorithm: relim_mine
using .AlgorithmOptV4: relim_optimized_mine as relim_opt_mine
using .Utils: read_spmf_file

"""
    generate_mock_dataset(filepath, num_transactions, num_items, avg_length)

Sinh tập dữ liệu giả lập. Dùng `unique(sort!(...))` để mỗi giao dịch không chứa item trùng.
"""
function generate_mock_dataset(filepath::String, num_transactions::Int, num_items::Int, avg_length::Int)
    println("  ⚙ Đang tạo dataset giả lập: ", basename(filepath))
    open(filepath, "w") do f
        for _ in 1:num_transactions
            len = max(1, rand(max(1, avg_length-2):avg_length+2))
            items = sort!(unique(rand(1:num_items, len)))
            println(f, join(items, " "))
        end
    end
end

"""
    ensure_datasets(dir)

Đảm bảo các file benchmark tồn tại (tạo mock nếu chưa có).
Minsup được chọn phù hợp đặc tính dense/sparse:
- Dense (nhiều item/giao dịch, ít item tổng): minsup RẤT CAO (>80%)
- Sparse (ít item/giao dịch, nhiều item tổng): minsup thấp (1-15%)
"""
function ensure_datasets(dir::String)
    mkpath(dir)

    # QUAN TRỌNG: Với dataset dense mock, cần:
    #   - Giảm n_trans nhỏ hơn bản gốc  
    #   - Tăng tỉ lệ num_items / avg_len để giảm overlap
    #   - Dùng minsup rất cao
    configs = [
        # Dense datasets → kích thước NHỎ, minsup CAO
        # Chess gốc: 3196 trans, 75 items, avg 37. Mock: 500 trans, 200 items, avg 12 → bớt dense hơn
        ("chess_mock.txt",     "Chess (mock)",     500,  200,  12, [0.50, 0.40, 0.30, 0.20, 0.10]),
        # Mushroom gốc: 8124 trans, 119 items, avg 23. Mock tương tự
        ("mushroom_mock.txt",  "Mushroom (mock)",  1000, 200,  15, [0.50, 0.40, 0.30, 0.20, 0.10]),
        # Sparse datasets → kích thước vừa, minsup thấp 
        ("retail_mock.txt",    "Retail (mock)",    5000, 500,  8,  [0.10, 0.05, 0.03, 0.02, 0.01]),
        ("t10i4d100k_mock.txt","T10I4 (mock)",     5000, 870,  10, [0.10, 0.05, 0.03, 0.02, 0.01]),
    ]

    result = Tuple{String, String, Vector{Float64}}[]
    for (fname, dname, n_trans, n_items, avg_len, minsups) in configs
        fpath = joinpath(dir, fname)
        if !isfile(fpath)
            generate_mock_dataset(fpath, n_trans, n_items, avg_len)
        end
        push!(result, (fpath, dname, minsups))
    end
    return result
end

"""
    run_benchmark()

Chạy benchmark so sánh Relim Basic vs Relim Opt.
Xuất kết quả ra file CSV để TV4 vẽ biểu đồ.
"""
function run_benchmark()
    dataset_dir = joinpath(@__DIR__, "..", "data", "benchmark")
    datasets = ensure_datasets(dataset_dir)

    output_csv = joinpath(@__DIR__, "..", "data", "benchmark_results.csv")
    println("\n>>> Đang chạy Benchmark...")
    println(">>> Kết quả sẽ lưu vào: ", output_csv)

    open(output_csv, "w") do f
        # Header CSV
        println(f, "Dataset,Minsup_Pct,Minsup_Count,Num_Trans,Num_FI_Basic,Num_FI_Opt,Time_Basic_s,Mem_Basic_MB,Time_Opt_s,Mem_Opt_MB")

        for (path, dname, minsup_list) in datasets
            println("\n═══════════════════════════════════════")
            println("  Dataset: ", dname, "  (", basename(path), ")")
            println("═══════════════════════════════════════")

            transactions = read_spmf_file(path)
            n_trans = length(transactions)
            println("  Số giao dịch: ", n_trans)

            # Warm-up JIT
            warmup_txs = transactions[1:min(10, n_trans)]
            relim_mine(warmup_txs, 1)
            relim_opt_mine(warmup_txs, 1)

            for m in minsup_list
                min_count = max(1, Int(ceil(m * n_trans)))

                print("  minsup=$(round(m*100, digits=1))% ($(min_count)/$(n_trans)) ... ")

                # --- Basic ---
                GC.gc()
                stats_b = @timed relim_mine(transactions, min_count)
                time_b = round(stats_b.time, digits=4)
                mem_b  = round(stats_b.bytes / 1024^2, digits=2)
                n_fi_b = length(stats_b.value)

                # --- Optimized ---
                GC.gc()
                stats_o = @timed relim_opt_mine(transactions, min_count)
                time_o = round(stats_o.time, digits=4)
                mem_o  = round(stats_o.bytes / 1024^2, digits=2)
                n_fi_o = length(stats_o.value)

                println("Basic: $(time_b)s/$(mem_b)MB ($(n_fi_b) FI) | Opt: $(time_o)s/$(mem_o)MB ($(n_fi_o) FI)")

                # Ghi CSV
                println(f, "$(dname),$(round(m*100, digits=1)),$(min_count),$(n_trans),$(n_fi_b),$(n_fi_o),$(time_b),$(mem_b),$(time_o),$(mem_o)")
            end
        end
    end

    println("\n✅ Hoàn tất Benchmark!")
    println("   File CSV: ", output_csv)
end

# Chạy khi gọi trực tiếp file
if abspath(PROGRAM_FILE) == @__FILE__
    run_benchmark()
end
