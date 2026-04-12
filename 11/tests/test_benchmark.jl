# tests/test_benchmark_optimized.jl
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
    ("chess.txt", "Chess", [0.85, 0.80, 0.75, 0.70]), 
    ("mushroom.txt", "Mushroom", [0.40, 0.30, 0.25, 0.20]), 
    ("retail.txt", "Retail", [0.10, 0.07, 0.05, 0.03, 0.02]),
    ("accidents.txt", "Accidents", [0.95, 0.90, 0.85, 0.80]), 
    ("T10I4D100K.txt", "T10I4D100K", [0.10, 0.07, 0.05, 0.03, 0.02]),
]

const CORRECTNESS_MINSUP = Dict(
    "Chess"      => 0.80,
    "Mushroom"   => 0.25,
    "Retail"     => 0.03,   
    "Accidents"  => 0.85,
    "T10I4D100K" => 0.03,  
)

# ═════════════════════════════════════════════════════════════════════════════
# HÀM ĐO LƯỜNG TỐI ƯU
# ═════════════════════════════════════════════════════════════════════════════

function measure(f)
    # Ép dọn rác triệt để trước khi đo lường để tránh nhiễu
    GC.gc(true) 
    stats = @timed f()
    return (stats.value, stats.time, round(stats.bytes / 1024^2, digits=2))
end

# ═════════════════════════════════════════════════════════════════════════════
# PHẦN 0: CORRECTNESS — Sử dụng Dấu vân tay Băm (Hashing Fingerprints)
# ═════════════════════════════════════════════════════════════════════════════

function cross_validate(rb::Vector{Tuple{Vector{Int},Int}},
                        ro::Vector{Tuple{Vector{Int},Int}})
    # TỐI ƯU CHÍNH: Thay vì cấp phát Set chứa hàng triệu Vector{Int},
    # ta mã hóa chúng thành số nguyên UInt64. Điều này tiết kiệm hàng GB RAM
    # và tăng tốc độ giao/hợp (intersect/union) lên hàng chục lần.
    sb = Set{UInt64}(hash((sort(is), s)) for (is, s) in rb)
    so = Set{UInt64}(hash((sort(is), s)) for (is, s) in ro)
    
    matched    = length(intersect(sb, so))
    total      = length(union(sb, so))
    rate       = total == 0 ? 100.0 : round(matched / total * 100, digits=2)
    only_basic = length(setdiff(sb, so))
    only_opt   = length(setdiff(so, sb))
    
    return (matched, total, rate, only_basic, only_opt)
end

function run_correctness()
    csv_path = joinpath(DATA_DIR, "correctness_results.csv")
    println("\n" * "═"^70)
    println("  PHẦN 0: CORRECTNESS (Hashing Optimized)")
    println("═"^70)

    open(csv_path, "w") do f
        println(f, "Dataset,Minsup_Pct,Num_FI_Basic,Num_FI_Opt,Matched,Match_Rate_Pct")

        for (fname, dname, _) in DATASETS
            fpath = joinpath(BENCHMARK_DIR, fname)
            if !isfile(fpath); continue; end

            m = get(CORRECTNESS_MINSUP, dname, 0.50)
            transactions = read_spmf_file(fpath)
            n = length(transactions)
            mc = max(1, Int(ceil(m * n)))
            pct = round(m * 100, digits=2)

            print("  $(dname) — minsup=$(pct)% ($(mc)/$(n))... ")

            try
                rb = relim_mine(transactions, mc)
                ro = relim_opt(transactions, mc)
                (matched, total, rate, ob, oo) = cross_validate(rb, ro)

                if rate == 100.0
                    println("✅ PASS — $(length(rb)) FI")
                else
                    println("⚠ MISMATCH — B=$(length(rb)), O=$(length(ro)), Khớp $(rate)%")
                end
                println(f, "$(dname),$(pct),$(length(rb)),$(length(ro)),$(matched),$(rate)")
            catch e
                println("ERROR: OOM hoặc lỗi thực thi.")
            end
        end
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# PHẦN 1 & 2: BENCHMARK VÀ SCALABILITY (Giữ nguyên cấu trúc nhưng an toàn hơn)
# ═════════════════════════════════════════════════════════════════════════════

function run_main_benchmark()
    csv_path = joinpath(DATA_DIR, "benchmark_results.csv")
    println("\n" * "═"^70)
    println("  PHẦN 1: BENCHMARK CHÍNH")
    println("═"^70)

    open(csv_path, "w") do f
        println(f, "Dataset,Minsup_Pct,Time_Basic_s,Mem_Basic_MB,Time_Opt_s,Mem_Opt_MB,Num_FI")

        for (fname, dname, minsups) in DATASETS
            fpath = joinpath(BENCHMARK_DIR, fname)
            if !isfile(fpath); continue; end

            println("\n──── Dataset: $(dname) ────")
            transactions = read_spmf_file(fpath)
            n = length(transactions)

            for m in minsups
                mc = max(1, Int(ceil(m * n)))
                pct = round(m * 100, digits=2)
                print("  minsup=$(pct)%... ")

                try
                    (rb, tb, mb) = measure(() -> relim_mine(transactions, mc))
                    (ro, to, mo) = measure(() -> relim_opt(transactions, mc))

                    println("Basic: $(round(tb,digits=2))s ($(mb)MB) | Opt: $(round(to,digits=2))s ($(mo)MB)")
                    println(f, "$(dname),$(pct),$(round(tb,digits=4)),$(mb),$(round(to,digits=4)),$(mo),$(length(rb))")
                catch e
                    println("ERROR: Bỏ qua do quá tải hệ thống.")
                end
            end
        end
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# PHẦN 3: ẢNH HƯỞNG ĐỘ DÀI GIAO DỊCH (Sửa lỗi phân phối đều)
# ═════════════════════════════════════════════════════════════════════════════

function generate_synthetic_sparse(n_trans::Int, n_items::Int, avg_len::Int)
    # TỐI ƯU CHÍNH: Không gian items (n_items) phải đủ lớn so với avg_len 
    # để tránh bị mật độ giao thoa ngẫu nhiên làm bùng nổ tổ hợp (combinatorial explosion)
    txs = Vector{Vector{Int}}(undef, n_trans)
    for i in 1:n_trans
        len = max(1, rand(max(1, avg_len-2):avg_len+2))
        txs[i] = sort!(unique(rand(1:n_items, len)))
    end
    return txs
end

function run_txlen_experiment()
    println("\n" * "═"^70)
    println("  PHẦN 3: ẢNH HƯỞNG ĐỘ DÀI GIAO DỊCH (Sparse Synthetic)")
    println("═"^70)

    n_trans = 10_000
    n_items = 5_000 # Tăng từ 100 lên 5,000 để mô phỏng dữ liệu thưa
    minsup_pct = 0.05 
    avg_lens = [1, 2, 3, 4, 5]

    for avg_len in avg_lens
        txs = generate_synthetic_sparse(n_trans, n_items, avg_len)
        mc = max(1, Int(ceil(minsup_pct * n_trans)))
        print("  avg_len=$(avg_len)... ")
        try
            (rb, tb, mb) = measure(() -> relim_mine(txs, mc))
            println("Basic: $(round(tb,digits=4))s | $(length(rb)) FI")
        catch
            println("ERROR")
        end
    end
end

function main()
    run_correctness()
    run_main_benchmark()
    run_txlen_experiment()
    println("\n🎉 HOÀN TẤT BENCHMARK AN TOÀN!")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end