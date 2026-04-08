# tests/test_benchmark.jl
include(joinpath(@__DIR__, "..", "src", "algorithm", "relim.jl"))
include(joinpath(@__DIR__, "..", "src", "algorithm", "relim_opt.jl"))

using .Algorithm: relim_mine
using .AlgorithmOptV3: relim_optimized_mine
using .Utils: read_spmf_file

const relim_opt = relim_optimized_mine

# ─── Thư mục output ─────────────────────────────────────────────────────────
const DATA_DIR      = joinpath(@__DIR__, "..", "data")
const BENCHMARK_DIR = joinpath(DATA_DIR, "benchmark")


DATASETS = [
    ("chess.txt", "Chess", [0.80, 0.75, 0.70, 0.65, 0.60]),
    ("mushroom.txt", "Mushroom", [0.30, 0.25, 0.20, 0.15, 0.10, 0.05]),
    ("retail.txt", "Retail", [0.10, 0.07, 0.05, 0.03, 0.02]),
    ("accidents.txt", "Accidents", [0.90, 0.85, 0.80, 0.75, 0.70, 0.65]),
    ("T10I4D100K.txt", "T10I4D100K", [0.10, 0.07, 0.05, 0.03, 0.02]),
]
# Minsup dùng cho kiểm tra correctness (a) — chọn giá trị giữa của mỗi dataset
const CORRECTNESS_MINSUP = Dict(
    "Chess"      => 0.75,
    "Mushroom"   => 0.15,
    "Retail"     => 0.03,   
    "Accidents"  => 0.80,
    "T10I4D100K" => 0.03,  
)

# ═════════════════════════════════════════════════════════════════════════════
# HÀM ĐO LƯỜNG
# ═════════════════════════════════════════════════════════════════════════════

"""
    measure(f) → (result, time_s, mem_mb)

Đo thời gian chạy và bộ nhớ cấp phát (allocated bytes) của hàm f().
`@timed.bytes` = tổng bytes cấp phát qua GC → xấp xỉ trên của Peak Memory.
"""
function measure(f)
    GC.gc()
    stats = @timed f()
    return (stats.value, stats.time, round(stats.bytes / 1024^2, digits=2))
end

# ═════════════════════════════════════════════════════════════════════════════
# PHẦN 0: CORRECTNESS — So sánh Basic vs Optimized trên 5 dataset chuẩn
# Yêu cầu (a): Báo cáo (i) tỉ lệ itemset khớp hoàn toàn;
#               (ii) nếu sai lệch → phân tích nguyên nhân.
# Output: correctness_results.csv
# ═════════════════════════════════════════════════════════════════════════════

"""
    cross_validate(basic_result, opt_result) → (match_count, total, match_rate)

So sánh từng itemset+support giữa Basic và Optimized.
Trả về: số FI khớp hoàn toàn, tổng FI (union), tỉ lệ khớp (%).
"""
function cross_validate(rb::Vector{Tuple{Vector{Int},Int}},
                        ro::Vector{Tuple{Vector{Int},Int}})
    sb = Set([(sort(is), s) for (is, s) in rb])
    so = Set([(sort(is), s) for (is, s) in ro])
    matched   = length(intersect(sb, so))
    total     = length(union(sb, so))
    rate      = total == 0 ? 100.0 : round(matched / total * 100, digits=2)
    only_basic = length(setdiff(sb, so))
    only_opt   = length(setdiff(so, sb))
    return (matched, total, rate, only_basic, only_opt)
end

function run_correctness()
    csv_path = joinpath(DATA_DIR, "correctness_results.csv")
    println("\n" * "═"^70)
    println("  PHẦN 0: CORRECTNESS — Basic vs Optimized (5 datasets)")
    println("  Output: ", csv_path)
    println("═"^70)

    open(csv_path, "w") do f
        println(f, "Dataset,Minsup_Pct,Minsup_Count,Num_Trans,Num_FI_Basic,Num_FI_Opt,Matched,Total_Union,Match_Rate_Pct,Only_Basic,Only_Opt")

        for (fname, dname, _) in DATASETS
            fpath = joinpath(BENCHMARK_DIR, fname)
            if !isfile(fpath)
                println("  ⚠ SKIP: $(fname)"); continue
            end

            m = get(CORRECTNESS_MINSUP, dname, 0.50)
            transactions = read_spmf_file(fpath)
            n = length(transactions)
            mc = max(1, Int(ceil(m * n)))
            pct = round(m * 100, digits=2)

            print("  $(dname) — minsup=$(pct)% ($(mc)/$(n)) ... ")

            try
                rb = relim_mine(transactions, mc)
                ro = relim_opt(transactions, mc)
                nb = length(rb); no = length(ro)
                (matched, total, rate, ob, oo) = cross_validate(rb, ro)

                if rate == 100.0
                    println("✅ PASS — $(nb) FI, khớp 100%")
                else
                    println("⚠ MISMATCH — Basic=$(nb), Opt=$(no), khớp $(rate)% (Basic-only=$(ob), Opt-only=$(oo))")
                end
                println(f, "$(dname),$(pct),$(mc),$(n),$(nb),$(no),$(matched),$(total),$(rate),$(ob),$(oo)")
            catch e
                println("ERROR: ", e)
                println(f, "$(dname),$(pct),$(mc),$(n),ERROR,ERROR,ERROR,ERROR,ERROR,ERROR,ERROR")
            end
        end
    end
    println("\n✅ Phần 0 hoàn tất → $(csv_path)")
    println("  ℹ Để so sánh với SPMF: chạy SPMF cùng minsup, đối chiếu Num_FI.")
end

# ═════════════════════════════════════════════════════════════════════════════
# PHẦN 1: BENCHMARK CHÍNH — Thời gian + Bộ nhớ + Số FI theo minsup
# Output: benchmark_results.csv
# ═════════════════════════════════════════════════════════════════════════════

function run_main_benchmark()
    csv_path = joinpath(DATA_DIR, "benchmark_results.csv")
    println("\n" * "═"^70)
    println("  PHẦN 1: BENCHMARK CHÍNH (5 datasets × 5-6 minsup)")
    println("  Output: ", csv_path)
    println("═"^70)

    open(csv_path, "w") do f
        println(f, "Dataset,Minsup_Pct,Minsup_Count,Num_Trans,Num_FI_Basic,Num_FI_Opt,Time_Basic_s,Mem_Basic_MB,Time_Opt_s,Mem_Opt_MB")

        for (fname, dname, minsups) in DATASETS
            fpath = joinpath(BENCHMARK_DIR, fname)
            if !isfile(fpath)
                println("  ⚠ SKIP: Không tìm thấy file $(fname)")
                continue
            end

            println("\n──── Dataset: $(dname) ($(fname)) ────")
            transactions = read_spmf_file(fpath)
            n = length(transactions)
            println("  Số giao dịch: $(n)")

            # JIT Warm-up (chạy trên tập nhỏ để biên dịch lần đầu)
            warmup = transactions[1:min(10, n)]
            relim_mine(warmup, 1)
            relim_opt(warmup, 1)

            for m in minsups
                mc = max(1, Int(ceil(m * n)))
                pct = round(m * 100, digits=2)
                print("  minsup=$(pct)% ($(mc)/$(n)) ... ")

                try
                    (rb, tb, mb) = measure(() -> relim_mine(transactions, mc))
                    (ro, to, mo) = measure(() -> relim_opt(transactions, mc))

                    nb = length(rb); no = length(ro)
                    println("Basic: $(round(tb,digits=4))s / $(mb)MB ($(nb) FI) | Opt: $(round(to,digits=4))s / $(mo)MB ($(no) FI)")
                    println(f, "$(dname),$(pct),$(mc),$(n),$(nb),$(no),$(round(tb,digits=4)),$(mb),$(round(to,digits=4)),$(mo)")
                catch e
                    println("ERROR: ", e)
                    println(f, "$(dname),$(pct),$(mc),$(n),ERROR,ERROR,ERROR,ERROR,ERROR,ERROR")
                end
            end
        end
    end
    println("\n✅ Phần 1 hoàn tất → $(csv_path)")
end

# ═════════════════════════════════════════════════════════════════════════════
# PHẦN 2: SCALABILITY — Retail subsets (10%, 25%, 50%, 75%, 100%)
# Output: scalability_results.csv
# ═════════════════════════════════════════════════════════════════════════════

function run_scalability()
    csv_path = joinpath(DATA_DIR, "scalability_results.csv")
    println("\n" * "═"^70)
    println("  PHẦN 2: SCALABILITY (Retail subsets)")
    println("  Output: ", csv_path)
    println("═"^70)

    fpath = joinpath(BENCHMARK_DIR, "retail.txt")
    if !isfile(fpath)
        println("  ⚠ SKIP: Không tìm thấy retail.txt"); return
    end

    all_txs = read_spmf_file(fpath)
    n_total = length(all_txs)
    minsup_pct = 0.005  # cố định 0.5%

    open(csv_path, "w") do f
        println(f, "Subset_Pct,Num_Trans,Minsup_Count,Num_FI_Basic,Num_FI_Opt,Time_Basic_s,Mem_Basic_MB,Time_Opt_s,Mem_Opt_MB")

        for pct in [0.10, 0.25, 0.50, 0.75, 1.00]
            n_sub = Int(ceil(pct * n_total))
            subset = all_txs[1:n_sub]
            mc = max(1, Int(ceil(minsup_pct * n_sub)))

            print("  $(Int(pct*100))% ($(n_sub) trans, minsup=$(mc)) ... ")
            try
                (rb, tb, mb) = measure(() -> relim_mine(subset, mc))
                (ro, to, mo) = measure(() -> relim_opt(subset, mc))
                nb = length(rb); no = length(ro)
                println("Basic: $(round(tb,digits=4))s | Opt: $(round(to,digits=4))s")
                println(f, "$(Int(pct*100)),$(n_sub),$(mc),$(nb),$(no),$(round(tb,digits=4)),$(mb),$(round(to,digits=4)),$(mo)")
            catch e
                println("ERROR: ", e)
                println(f, "$(Int(pct*100)),$(n_sub),$(mc),ERROR,ERROR,ERROR,ERROR,ERROR,ERROR")
            end
        end
    end
    println("\n✅ Phần 2 hoàn tất → $(csv_path)")
end

# ═════════════════════════════════════════════════════════════════════════════
# PHẦN 3: ẢNH HƯỞNG ĐỘ DÀI GIAO DỊCH (Synthetic data)
# Output: txlen_results.csv
# ═════════════════════════════════════════════════════════════════════════════

function generate_synthetic(n_trans::Int, n_items::Int, avg_len::Int)
    txs = Vector{Vector{Int}}(undef, n_trans)
    for i in 1:n_trans
        len = max(1, rand(max(1,avg_len-2):avg_len+2))
        txs[i] = sort!(unique(rand(1:n_items, len)))
    end
    return txs
end

function run_txlen_experiment()
    csv_path = joinpath(DATA_DIR, "txlen_results.csv")
    println("\n" * "═"^70)
    println("  PHẦN 3: ẢNH HƯỞNG ĐỘ DÀI GIAO DỊCH (Synthetic)")
    println("  Output: ", csv_path)
    println("═"^70)

    n_trans = 10_000
    n_items = 100
    minsup_pct = 0.05  # 5%
    avg_lens = [5, 10, 15, 20, 25, 30, 35]

    open(csv_path, "w") do f
        println(f, "Avg_TxLen,Num_Trans,Minsup_Count,Num_FI_Basic,Num_FI_Opt,Time_Basic_s,Mem_Basic_MB,Time_Opt_s,Mem_Opt_MB")

        for avg_len in avg_lens
            txs = generate_synthetic(n_trans, n_items, avg_len)
            mc = max(1, Int(ceil(minsup_pct * n_trans)))

            print("  avg_len=$(avg_len) (minsup=$(mc)) ... ")
            try
                (rb, tb, mb) = measure(() -> relim_mine(txs, mc))
                (ro, to, mo) = measure(() -> relim_opt(txs, mc))
                nb = length(rb); no = length(ro)
                println("Basic: $(round(tb,digits=4))s ($(nb) FI) | Opt: $(round(to,digits=4))s ($(no) FI)")
                println(f, "$(avg_len),$(n_trans),$(mc),$(nb),$(no),$(round(tb,digits=4)),$(mb),$(round(to,digits=4)),$(mo)")
            catch e
                println("ERROR: ", e)
                println(f, "$(avg_len),$(n_trans),$(mc),ERROR,ERROR,ERROR,ERROR,ERROR,ERROR")
            end
        end
    end
    println("\n✅ Phần 3 hoàn tất → $(csv_path)")
end

# ═════════════════════════════════════════════════════════════════════════════
# MAIN
# ═════════════════════════════════════════════════════════════════════════════

function main()
    println("╔══════════════════════════════════════════════════════════════╗")
    println("║        RELIM BENCHMARK SUITE — Basic vs Optimized          ║")
    println("╠══════════════════════════════════════════════════════════════╣")
    println("║  Datasets: Chess, Mushroom, Retail, T10I4D100K, Accidents  ║")
    println("║  Metrics : Correctness, Time, Memory, FI Count            ║")
    println("╚══════════════════════════════════════════════════════════════╝")

    run_correctness()      # (a) — Kiểm tra tính đúng đắn Basic vs Opt
    run_main_benchmark()   # (b)(c)(d) — Thời gian + FI + Memory vs minsup
    run_scalability()      # (e) — Scalability trên Retail
    run_txlen_experiment() # (f) — Ảnh hưởng độ dài giao dịch

    println("\n" * "═"^70)
    println("  🎉 HOÀN TẤT TẤT CẢ BENCHMARK!")
    println("  📄 correctness_results.csv → Bảng (a) — tỉ lệ khớp Basic vs Opt")
    println("  📄 benchmark_results.csv   → Biểu đồ (b)(c)(d)")
    println("  📄 scalability_results.csv → Biểu đồ (e)")
    println("  📄 txlen_results.csv       → Biểu đồ (f)")
    println("═"^70)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
