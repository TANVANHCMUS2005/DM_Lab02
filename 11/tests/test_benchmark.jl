# tests/test_benchmark.jl
# =============================================================================
# Yêu cầu Lab2:
# a) Correctness vs SPMF - so sánh itemset + support
# b) Time vs minsup + SPMF comparison (vẽ đồ thị)
# c) FI count vs minsup (vẽ đồ thị)
# d) Memory usage Basic vs Opt
# e) Scalability (Retail subsets)
# f) Transaction length effect
# =============================================================================

include(joinpath(@__DIR__, "..", "src", "algorithm", "relim.jl"))
include(joinpath(@__DIR__, "..", "src", "algorithm", "relim_opt.jl"))

using .Algorithm: relim_mine
using .AlgorithmOptV3: relim_optimized_mine
using .Utils: read_spmf_file, read_spmf_output

const relim_opt = relim_optimized_mine

const DATA_DIR      = joinpath(@__DIR__, "..", "data")
const BENCHMARK_DIR = joinpath(DATA_DIR, "benchmark")

DATASETS = [
    ("chess.txt", "Chess", [0.85, 0.80, 0.75, 0.70, 0.65]), 
    ("mushroom.txt", "Mushroom", [0.40, 0.30, 0.25, 0.20, 0.15]), 
    ("retail.txt", "Retail", [0.10, 0.07, 0.05, 0.03, 0.02]),
    ("accidents.txt", "Accidents", [0.95, 0.90, 0.85, 0.80, 0.75]), 
    ("T10I4D100K.txt", "T10I4D100K", [0.10, 0.07, 0.05, 0.03, 0.02]),
]

const CORRECTNESS_MINSUP = Dict(
    "Chess"      => 0.80,
    "Mushroom"   => 0.25,
    "Retail"     => 0.03,   
    "Accidents"  => 0.85,
    "T10I4D100K" => 0.03,  
)

function measure(f)
    GC.gc(true) 
    stats = @timed f()
    return (stats.value, stats.time, round(stats.bytes / 1024^2, digits=2))
end

# ═════════════════════════════════════════════════════════════════════════════
# SPMF Reference Files (đã có sẵn)
# ═════════════════════════════════════════════════════════════════════════════
# SPMF file naming không nhất quán, map lại
const SPMF_FILENAME = Dict(
    "chess.txt" => "spmf_chess.txt",       # NOT EXISTS - cần generate hoặc bỏ qua
    "mushroom.txt" => "spmf_mushrooms.txt",
    "retail.txt" => "spmf_retail.txt",
    "accidents.txt" => "spmf_accidents.txt",
    "T10I4D100K.txt" => "spmf_T10I4D100K.txt",
)

# SPMF reference đã có cho những minsup nào (từ các file có sẵn)
# Lưu ý: Các file SPMF này chỉ chạy với 1 minsup duy nhất, không phải 5-7 điểm
const SPMF_REFERENCE_MINSUP = Dict(
    "Chess"      => [],      # KHÔNG CÓ - thiếu reference
    "Mushroom"   => [0.25],  # Có reference
    "Retail"     => [0.03],  # Có reference  
    "Accidents"  => [0.85],  # Có reference
    "T10I4D100K" => [0.03],  # Có reference
)

# ═════════════════════════════════════════════════════════════════════════════
# a) CORRECTNESS — So sánh với SPMF
# ═════════════════════════════════════════════════════════════════════════════

function compare_with_spmf(our_result::Vector{Tuple{Vector{Int},Int}}, spmf_result::Vector{Tuple{Vector{Int},Int}})
    # So sánh từng itemset + support
    our_set = Set{UInt64}(hash((sort(is), s)) for (is, s) in our_result)
    spmf_set = Set{UInt64}(hash((sort(is), s)) for (is, s) in spmf_result)
    
    matched   = length(intersect(our_set, spmf_set))
    total     = length(union(our_set, spmf_set))
    rate      = total == 0 ? 100.0 : round(matched / total * 100, digits=2)
    only_ours = length(setdiff(our_set, spmf_set))
    only_spmf = length(setdiff(spmf_set, our_set))
    
    return (matched, total, rate, only_ours, only_spmf)
end

function run_correctness_with_spmf()
    csv_path = joinpath(DATA_DIR, "correctness_results.csv")
    println("\n" * "═"^70)
    println("  a) CORRECTNESS — So sánh với SPMF")
    println("═"^70)
    
    open(csv_path, "w") do f
        println(f, "Dataset,Minsup_Pct,Num_FI_Our,Num_FI_SPMF,Matched,Match_Rate_Pct,Only_Our,Only_SPMF,Notes")
        
        for (fname, dname, _) in DATASETS
            fpath = joinpath(BENCHMARK_DIR, fname)
            spmf_fname = get(SPMF_FILENAME, fname, "spmf_$(fname)")
            spmf_path = joinpath(BENCHMARK_DIR, spmf_fname)
            
            if !isfile(fpath); continue; end
            
            m = get(CORRECTNESS_MINSUP, dname, 0.50)
            transactions = read_spmf_file(fpath)
            n = length(transactions)
            mc = max(1, Int(ceil(m * n)))
            pct = round(m * 100, digits=2)
            
            print("  $(dname) — minsup=$(pct)%... ")
            
            try
                our_result = relim_mine(transactions, mc)
                
                if isfile(spmf_path)
                    spmf_result = read_spmf_output(spmf_path)
                    (matched, total, rate, our_only, spmf_only) = compare_with_spmf(our_result, spmf_result)
                    
                    if rate == 100.0
                        println("✅ PASS vs SPMF — $(length(our_result)) FI, khớp $(rate)%")
                    else
                        println("⚠ SPMF mismatch — Ours=$(length(our_result)), SPMF=$(length(spmf_result)), Khớp $(rate)%")
                    end
                    println(f, "$(dname),$(pct),$(length(our_result)),$(length(spmf_result)),$(matched),$(rate),$(our_only),$(spmf_only),OK")
                else
                    println("⚠ No SPMF reference — $(length(our_result)) FI found (không thể so sánh)")
                    println(f, "$(dname),$(pct),$(length(our_result)),N/A,N/A,N/A,N/A,N/A,Missing_SPMF_Ref")
                end
            catch e
                println("ERROR: $e")
                println(f, "$(dname),$(pct),ERROR,ERROR,ERROR,ERROR,ERROR,ERROR,$e")
            end
        end
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# b) TIME vs MINSUP, c) FI COUNT vs MINSUP, d) MEMORY
# ═════════════════════════════════════════════════════════════════════════════

# Hàm chạy SPMF qua Java (nếu có Java và spmf.jar)
function run_spmf_timing(input_path::String, minsup_count::Int)
    spmf_jar = joinpath(BENCHMARK_DIR, "spmf.jar")
    if !isfile(spmf_jar)
        return nothing
    end
    
    output_file = tempname() * ".txt"
    
    try
        cmd = `java -jar $spmf_jar run Relim $input_path $output_file $minsup_count`
        start = time()
        run(cmd)
        elapsed = time() - start
        isfile(output_file) && rm(output_file)
        return elapsed
    catch e
        isfile(output_file) && rm(output_file)
        return nothing
    end
end

function run_main_benchmark()
    csv_path = joinpath(DATA_DIR, "benchmark_results.csv")
    println("\n" * "═"^70)
    println("  b) TIME vs MINSUP, c) FI COUNT vs MINSUP, d) MEMORY")
    println("═"^70)
    
    open(csv_path, "w") do f
        println(f, "Dataset,Minsup_Pct,Minsup_Count,Time_Basic_s,Mem_Basic_MB,Time_Opt_s,Mem_Opt_MB,Num_FI_Our,Num_FI_SPMF,SPMF_Time_s,Notes")
        
        for (fname, dname, minsups) in DATASETS
            fpath = joinpath(BENCHMARK_DIR, fname)
            spmf_fname = get(SPMF_FILENAME, fname, "spmf_$(fname)")
            spmf_path = joinpath(BENCHMARK_DIR, spmf_fname)
            
            if !isfile(fpath); continue; end
            
            println("\n──── Dataset: $(dname) ────")
            transactions = read_spmf_file(fpath)
            n = length(transactions)
            println("  Total transactions: $(n)")
            
            # Đọc SPMF results nếu có (chỉ có 1 minsup)
            spmf_result = nothing
            spmf_count = -1
            if isfile(spmf_path)
                try
                    spmf_result = read_spmf_output(spmf_path)
                    spmf_count = length(spmf_result)
                    println("  SPMF reference: $(spmf_count) FI (chỉ 1 minsup)")
                catch e
                    println("  ⚠ Cannot read SPMF file")
                end
            else
                println("  ℹ No SPMF reference file")
            end
            
            for m in minsups
                mc = max(1, Int(ceil(m * n)))
                pct = round(m * 100, digits=2)
                print("  minsup=$(pct)% ($(mc)/$(n))... ")
                
                try
                    (rb, tb, mb) = measure(() -> relim_mine(transactions, mc))
                    (ro, to, mo) = measure(() -> relim_opt(transactions, mc))
                    
                    # So sánh với SPMF nếu minsup match
                    spmf_fi = spmf_count
                    spmf_time = -1.0
                    note = ""
                    if spmf_result !== nothing && m in get(CORRECTNESS_MINSUP, dname, [])
                        if length(rb) == spmf_count
                            note = "Match_with_SPMF"
                        else
                            note = "Mismatch_with_SPMF"
                        end
                    end
                    
                    println("Basic: $(round(tb,digits=2))s ($(mb)MB) | Opt: $(round(to,digits=2))s ($(mo)MB) | FI: $(length(rb))")
                    println(f, "$(dname),$(pct),$(mc),$(round(tb,digits=4)),$(mb),$(round(to,digits=4)),$(mo),$(length(rb)),$(spmf_fi),$(spmf_time),$(note)")
                catch e
                    println("ERROR: $e")
                    println(f, "$(dname),$(pct),$(mc),ERROR,ERROR,ERROR,ERROR,ERROR,-1,-1,ERROR")
                end
            end
        end
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# e) SCALABILITY — Retail subsets (10%, 25%, 50%, 75%, 100%)
# ═════════════════════════════════════════════════════════════════════════════

function run_scalability()
    csv_path = joinpath(DATA_DIR, "scalability_results.csv")
    println("\n" * "═"^70)
    println("  e) SCALABILITY — Retail subsets (10%, 25%, 50%, 75%, 100%)")
    println("═"^70)
    
    fpath = joinpath(BENCHMARK_DIR, "retail.txt")
    if !isfile(fpath)
        println("  ⚠ SKIP: retail.txt not found")
        return
    end
    
    all_txs = read_spmf_file(fpath)
    n_total = length(all_txs)
    println("  Total transactions: $(n_total)")
    minsup_pct = 0.005  # 0.5%
    
    open(csv_path, "w") do f
        println(f, "Subset_Pct,Num_Trans,Minsup_Count,Num_FI_Basic,Num_FI_Opt,Time_Basic_s,Mem_Basic_MB,Time_Opt_s,Mem_Opt_MB")
        
        for pct in [0.10, 0.25, 0.50, 0.75, 1.00]
            n_sub = Int(ceil(pct * n_total))
            subset = all_txs[1:n_sub]
            mc = max(1, Int(ceil(minsup_pct * n_sub)))
            
            print("  $(Int(pct*100))% ($(n_sub) trans, minsup=$(mc))... ")
            try
                (rb, tb, mb) = measure(() -> relim_mine(subset, mc))
                (ro, to, mo) = measure(() -> relim_opt(subset, mc))
                println("Basic: $(round(tb,digits=4))s ($(length(rb)) FI) | Opt: $(round(to,digits=4))s ($(length(ro)) FI)")
                println(f, "$(Int(pct*100)),$(n_sub),$(mc),$(length(rb)),$(length(ro)),$(round(tb,digits=4)),$(mb),$(round(to,digits=4)),$(mo)")
            catch e
                println("ERROR: $e")
                println(f, "$(Int(pct*100)),$(n_sub),$(mc),ERROR,ERROR,ERROR,ERROR,ERROR,ERROR")
            end
        end
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# f) ẢNH HƯỞNG ĐỘ DÀI GIAO DỊCH (Transaction Length)
# ═════════════════════════════════════════════════════════════════════════════

function generate_synthetic_sparse(n_trans::Int, n_items::Int, avg_len::Int)
    # Tạo CSDL tổng hợp với độ dài giao dịch tăng dần
    txs = Vector{Vector{Int}}(undef, n_trans)
    for i in 1:n_trans
        len = max(1, rand(max(1, avg_len-2):avg_len+2))
        txs[i] = sort!(unique(rand(1:n_items, len)))
    end
    return txs
end

function run_txlen_experiment()
    csv_path = joinpath(DATA_DIR, "txlen_results.csv")
    println("\n" * "═"^70)
    println("  f) ẢNH HƯỞNG ĐỘ DÀI GIAO DỊCH (avg_len: 3, 5, 8, 10, 15, 20)")
    println("═"^70)
    
    n_trans = 10_000
    n_items = 5_000  # Tạo không gian items lớn để tránh combinatorial explosion
    minsup_pct = 0.05  # 5% - đủ cao để tránh OOM
    
    println("  n_trans=$(n_trans), n_items=$(n_items), minsup=$(minsup_pct*100)%")
    
    open(csv_path, "w") do f
        println(f, "Avg_TxLen,Num_FI_Basic,Num_FI_Opt,Time_Basic_s,Mem_Basic_MB,Time_Opt_s,Mem_Opt_MB")
        
        for avg_len in [3, 5, 8, 10, 15, 20]
            txs = generate_synthetic_sparse(n_trans, n_items, avg_len)
            mc = max(1, Int(ceil(minsup_pct * n_trans)))
            print("  avg_len=$(avg_len)... ")
            try
                (rb, tb, mb) = measure(() -> relim_mine(txs, mc))
                (ro, to, mo) = measure(() -> relim_opt(txs, mc))
                println("Basic: $(round(tb,digits=4))s ($(mb)MB, $(length(rb)) FI) | Opt: $(round(to,digits=4))s ($(mo)MB, $(length(ro)) FI)")
                println(f, "$(avg_len),$(length(rb)),$(length(ro)),$(round(tb,digits=4)),$(mb),$(round(to,digits=4)),$(mo)")
            catch e
                println("ERROR: $e")
                println(f, "$(avg_len),ERROR,ERROR,ERROR,ERROR,ERROR,ERROR")
            end
        end
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# MAIN
# ═════════════════════════════════════════════════════════════════════════════

function main()
    println("╔══════════════════════════════════════════════════════════════╗")
    println("║         RELIM BENCHMARK - All Requirements a-f              ║")
    println("╚══════════════════════════════════════════════════════════════╝")
    
    # a) Correctness vs SPMF
    run_correctness_with_spmf()
    
    # b) Time vs minsup, c) FI count, d) Memory
    run_main_benchmark()
    
    # e) Scalability
    run_scalability()
    
    # f) Transaction length
    run_txlen_experiment()
    
    println("\n" * "═"^70)
    println("  🎉 HOÀN TẤT TẤT CẢ BENCHMARK!")
    println("═"^70)
    println("\n  📊 CSV Outputs:")
    println("    - correctness_results.csv (a)")
    println("    - benchmark_results.csv (b, c, d)")
    println("    - scalability_results.csv (e)")
    println("    - txlen_results.csv (f)")
    println("\n  ⚠️  Lưu ý:")
    println("    - SPMF timing yêu cầu Java installed")
    println("    - SPMF reference chỉ có sẵn cho 1 minsup/dataset")
    println("    - Chess thiếu SPMF reference")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

# ═════════════════════════════════════════════════════════════════════════════
# a) CORRECTNESS — So sánh với SPMF
# ═════════════════════════════════════════════════════════════════════════════

# SPMF file naming không nhất quán, map lại
const SPMF_FILENAME = Dict(
    "chess.txt" => "spmf_chess.txt",
    "mushroom.txt" => "spmf_mushrooms.txt",
    "retail.txt" => "spmf_retail.txt",
    "accidents.txt" => "spmf_accidents.txt",
    "T10I4D100K.txt" => "spmf_T10I4D100K.txt",
)

function compare_with_spmf(our_result::Vector{Tuple{Vector{Int},Int}}, spmf_result::Vector{Tuple{Vector{Int},Int}})
    our_set = Set{UInt64}(hash((sort(is), s)) for (is, s) in our_result)
    spmf_set = Set{UInt64}(hash((sort(is), s)) for (is, s) in spmf_result)
    
    matched   = length(intersect(our_set, spmf_set))
    total     = length(union(our_set, spmf_set))
    rate      = total == 0 ? 100.0 : round(matched / total * 100, digits=2)
    only_ours = length(setdiff(our_set, spmf_set))
    only_spmf = length(setdiff(spmf_set, our_set))
    
    return (matched, total, rate, only_ours, only_spmf)
end

function run_correctness_with_spmf()
    csv_path = joinpath(DATA_DIR, "correctness_results.csv")
    println("\n" * "═"^70)
    println("  a) CORRECTNESS — So sánh với SPMF")
    println("═"^70)
    
    open(csv_path, "w") do f
        println(f, "Dataset,Minsup_Pct,Num_FI_Our,Num_FI_SPMF,Matched,Match_Rate_Pct,Only_Our,Only_SPMF")
        
        for (fname, dname, _) in DATASETS
            fpath = joinpath(BENCHMARK_DIR, fname)
            spmf_fname = get(SPMF_FILENAME, fname, "spmf_$(fname)")
            spmf_path = joinpath(BENCHMARK_DIR, spmf_fname)
            
            if !isfile(fpath); continue; end
            
            m = get(CORRECTNESS_MINSUP, dname, 0.50)
            transactions = read_spmf_file(fpath)
            n = length(transactions)
            mc = max(1, Int(ceil(m * n)))
            pct = round(m * 100, digits=2)
            
            print("  $(dname) — minsup=$(pct)%... ")
            
            try
                our_result = relim_mine(transactions, mc)
                
                if isfile(spmf_path)
                    spmf_result = read_spmf_output(spmf_path)
                    (matched, total, rate, our_only, spmf_only) = compare_with_spmf(our_result, spmf_result)
                    
                    if rate == 100.0
                        println("✅ PASS vs SPMF — $(length(our_result)) FI")
                    else
                        println("⚠ SPMF mismatch — Ours=$(length(our_result)), SPMF=$(length(spmf_result)), Khớp $(rate)%")
                    end
                    println(f, "$(dname),$(pct),$(length(our_result)),$(length(spmf_result)),$(matched),$(rate),$(our_only),$(spmf_only)")
                else
                    println("ℹ No SPMF reference — $(length(our_result)) FI found")
                    println(f, "$(dname),$(pct),$(length(our_result)),N/A,N/A,N/A,N/A,N/A")
                end
            catch e
                println("ERROR: $e")
            end
        end
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# b) TIME vs MINSUP (có SPMF comparison) & c) FI COUNT vs MINSUP & d) MEMORY
# ═════════════════════════════════════════════════════════════════════════════

function run_main_benchmark()
    csv_path = joinpath(DATA_DIR, "benchmark_results.csv")
    println("\n" * "═"^70)
    println("  b) TIME vs MINSUP, c) FI COUNT, d) MEMORY")
    println("═"^70)
    
    open(csv_path, "w") do f
        println(f, "Dataset,Minsup_Pct,Time_Basic_s,Mem_Basic_MB,Time_Opt_s,Mem_Opt_MB,Num_FI_Our,Num_FI_SPMF")
        
        for (fname, dname, minsups) in DATASETS
            fpath = joinpath(BENCHMARK_DIR, fname)
            spmf_fname = get(SPMF_FILENAME, fname, "spmf_$(fname)")
            spmf_path = joinpath(BENCHMARK_DIR, spmf_fname)
            
            if !isfile(fpath); continue; end
            
            println("\n──── Dataset: $(dname) ────")
            transactions = read_spmf_file(fpath)
            n = length(transactions)
            
            # Đọc SPMF results nếu có để so sánh số lượng FI
            spmf_fi_counts = nothing
            if isfile(spmf_path)
                try
                    spmf_result = read_spmf_output(spmf_path)
                    spmf_fi_counts = length(spmf_result)
                    println("  SPMF reference: $(spmf_fi_counts) FI")
                catch e
                    println("  ⚠ Cannot read SPMF file")
                end
            end
            
            for m in minsups
                mc = max(1, Int(ceil(m * n)))
                pct = round(m * 100, digits=2)
                print("  minsup=$(pct)%... ")
                
                try
                    (rb, tb, mb) = measure(() -> relim_mine(transactions, mc))
                    (ro, to, mo) = measure(() -> relim_opt(transactions, mc))
                    
                    # SPMF FI count - so sánh từ file reference
                    spmf_count = spmf_fi_counts !== nothing ? spmf_fi_counts : -1
                    
                    println("Basic: $(round(tb,digits=2))s ($(mb)MB) | Opt: $(round(to,digits=2))s ($(mo)MB)")
                    println(f, "$(dname),$(pct),$(round(tb,digits=4)),$(mb),$(round(to,digits=4)),$(mo),$(length(rb)),$(spmf_count)")
                catch e
                    println("ERROR: $e")
                end
            end
        end
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# e) SCALABILITY — Retail subsets (10%, 25%, 50%, 75%, 100%)
# ═════════════════════════════════════════════════════════════════════════════

function run_scalability()
    csv_path = joinpath(DATA_DIR, "scalability_results.csv")
    println("\n" * "═"^70)
    println("  e) SCALABILITY — Retail subsets")
    println("═"^70)
    
    fpath = joinpath(BENCHMARK_DIR, "retail.txt")
    if !isfile(fpath)
        println("  ⚠ SKIP: retail.txt not found")
        return
    end
    
    all_txs = read_spmf_file(fpath)
    n_total = length(all_txs)
    minsup_pct = 0.005  # 0.5%
    
    open(csv_path, "w") do f
        println(f, "Subset_Pct,Num_Trans,Minsup_Count,Num_FI_Basic,Num_FI_Opt,Time_Basic_s,Mem_Basic_MB,Time_Opt_s,Mem_Opt_MB")
        
        for pct in [0.10, 0.25, 0.50, 0.75, 1.00]
            n_sub = Int(ceil(pct * n_total))
            subset = all_txs[1:n_sub]
            mc = max(1, Int(ceil(minsup_pct * n_sub)))
            
            print("  $(Int(pct*100))% ($(n_sub) trans)... ")
            try
                (rb, tb, mb) = measure(() -> relim_mine(subset, mc))
                (ro, to, mo) = measure(() -> relim_opt(subset, mc))
                println("Basic: $(round(tb,digits=4))s | Opt: $(round(to,digits=4))s")
                println(f, "$(Int(pct*100)),$(n_sub),$(mc),$(length(rb)),$(length(ro)),$(round(tb,digits=4)),$(mb),$(round(to,digits=4)),$(mo)")
            catch e
                println("ERROR: $e")
            end
        end
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# f) ẢNH HƯỞNG ĐỘ DÀI GIAO DỊCH
# ═════════════════════════════════════════════════════════════════════════════

function generate_synthetic_sparse(n_trans::Int, n_items::Int, avg_len::Int)
    txs = Vector{Vector{Int}}(undef, n_trans)
    for i in 1:n_trans
        len = max(1, rand(max(1, avg_len-2):avg_len+2))
        txs[i] = sort!(unique(rand(1:n_items, len)))
    end
    return txs
end

function run_txlen_experiment()
    csv_path = joinpath(DATA_DIR, "txlen_results.csv")
    println("\n" * "═"^70)
    println("  f) ẢNH HƯỞNG ĐỘ DÀI GIAO DỊCH")
    println("═"^70)
    
    n_trans = 10_000
    n_items = 5_000
    minsup_pct = 0.05
    
    open(csv_path, "w") do f
        println(f, "Avg_TxLen,Num_FI_Basic,Num_FI_Opt,Time_Basic_s,Mem_Basic_MB,Time_Opt_s,Mem_Opt_MB")
        
        for avg_len in [3, 5, 8, 10, 15, 20]
            txs = generate_synthetic_sparse(n_trans, n_items, avg_len)
            mc = max(1, Int(ceil(minsup_pct * n_trans)))
            print("  avg_len=$(avg_len)... ")
            try
                (rb, tb, mb) = measure(() -> relim_mine(txs, mc))
                (ro, to, mo) = measure(() -> relim_opt(txs, mc))
                println("Basic: $(round(tb,digits=4))s ($(length(rb)) FI) | Opt: $(round(to,digits=4))s ($(length(ro)) FI)")
                println(f, "$(avg_len),$(length(rb)),$(length(ro)),$(round(tb,digits=4)),$(mb),$(round(to,digits=4)),$(mo)")
            catch e
                println("ERROR: $e")
            end
        end
    end
end

function main()
    run_correctness_with_spmf()  # a)
    run_main_benchmark()         # b), c), d)
    run_scalability()           # e)
    run_txlen_experiment()       # f)
    println("\n🎉 HOÀN TẤT TẤT CẢ BENCHMARK!")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end