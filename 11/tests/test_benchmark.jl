# tests/test_benchmark.jl
# =============================================================================
# YÊU CẦU LAB 2:
# a) Correctness vs SPMF
# b) Time vs minsup + SPMF comparison
# c) FI count vs minsup
# d) Memory usage (Basic vs Opt) tại minsup trung bình
# e) Scalability (Retail subsets)
# f) Transaction length effect
# =============================================================================

include(joinpath(@__DIR__, "..", "src", "algorithm", "relim.jl"))
include(joinpath(@__DIR__, "..", "src", "algorithm", "relim_opt.jl"))
using .Algorithm: relim_mine
using .AlgorithmOptV3: relim_optimized_mine
using .Utils: read_spmf_file

const relim_opt = relim_optimized_mine

const DATA_DIR      = joinpath(@__DIR__, "..", "data")
const BENCHMARK_DIR = joinpath(DATA_DIR, "benchmark")
const SPMF_JAR_PATH = joinpath(BENCHMARK_DIR, "spmf.jar")  

DATASETS = [
    ("chess.txt", "Chess", [0.90, 0.85, 0.80, 0.75, 0.70, 0.65]), 
    ("mushroom.txt", "Mushroom", [0.40, 0.35, 0.30, 0.25, 0.20, 0.15]), 
    ("retail.txt", "Retail", [0.10, 0.07, 0.05, 0.03, 0.02]),
    ("accidents.txt", "Accidents", [0.95, 0.90, 0.85, 0.80, 0.75, 0.70]), 
    ("T10I4D100K.txt", "T10I4D100K", [0.10, 0.07, 0.06, 0.05, 0.4, 0.03]),
]

const CORRECTNESS_MINSUP = Dict(
    "Chess"      => [0.85, 0.80, 0.75],
    "Mushroom"   => [0.30, 0.25, 0.20],
    "Retail"     => [0.05, 0.03, 0.02],
    "Accidents"  => [0.90, 0.85, 0.80],
    "T10I4D100K" => [0.05, 0.04, 0.03],
)

function measure(f)
    GC.gc(true) 
    stats = @timed f()
    GC.gc(true)
    return (stats.value, stats.time, round(stats.bytes / 1024^2, digits=2))
end

function read_spmf_output(filepath::String)
    result = Vector{Tuple{Vector{Int},Int}}()
    for line in eachline(filepath)
        parts = split(line, "#SUP:")
        if length(parts) == 2
            items_str = split(strip(parts[1]), " ", keepempty=false)
            items = parse.(Int, items_str)
            sup = parse(Int, strip(parts[2]))
            push!(result, (items, sup))
        end
    end
    return result
end

function run_spmf_external(input_file::String, output_file::String, minsup_pct::Float64)
    if !isfile(SPMF_JAR_PATH)
        return -1.0
    end
    spmf_min = "$(round(minsup_pct * 100, digits=2))%"
    
    # CẢI TIẾN 1: Thêm cờ -Xmx16G để cấp 16GB RAM cho JVM tránh lỗi OOM.
    # CẢI TIẾN 2: Dùng ignorestatus() để Julia không bị crash nếu SPMF thất bại.
    cmd = ignorestatus(`java -Xmx16G -jar $SPMF_JAR_PATH run Relim $input_file $output_file $spmf_min`)
    
    try
        # Đo thời gian tiến trình, nhưng đồng thời kiểm tra xem tiến trình có success() không
        t = @elapsed is_success = success(pipeline(cmd, stdout=devnull, stderr=devnull))
        return is_success ? t : -1.0
    catch e
        return -1.0
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# a) CORRECTNESS — So sánh với SPMF
# ═════════════════════════════════════════════════════════════════════════════

function compare_with_spmf(our_result::Vector{Tuple{Vector{Int},Int}}, spmf_result::Vector{Tuple{Vector{Int},Int}})
    our_set = Set{UInt64}(hash((sort(is), s)) for (is, s) in our_result)
    spmf_set = Set{UInt64}(hash((sort(is), s)) for (is, s) in spmf_result)
    
    matched   = length(intersect(our_set, spmf_set))
    total     = length(union(our_set, spmf_set))
    rate      = total == 0 ? 100.0 : round(matched / total * 100, digits=2)
    return (matched, total, rate)
end

function run_correctness_with_spmf()
    csv_path = joinpath(DATA_DIR, "correctness_results.csv")
    println("\n" * "═"^70)
    println("  a) CORRECTNESS — So sánh với SPMF tại nhiều minsup")
    println("═"^70)
    
    if !isfile(SPMF_JAR_PATH)
        println("  ⚠ Không tìm thấy spmf.jar tại $(SPMF_JAR_PATH). Bỏ qua SPMF.")
    end

    open(csv_path, "w") do f
        println(f, "Dataset,Minsup_Pct,Minsup_Count,Num_FI_Our,Num_FI_SPMF,Matched,Match_Rate_Pct,Analysis")
        for (fname, dname, _) in DATASETS
            fpath = joinpath(BENCHMARK_DIR, fname)
            out_spmf = joinpath(BENCHMARK_DIR, "temp_spmf_out_$(dname).txt")
            if !isfile(fpath); continue; end
            
            correctness_minsups = get(CORRECTNESS_MINSUP, dname, [0.5])
            transactions = read_spmf_file(fpath)
            n = length(transactions)
            
            for m in correctness_minsups
                mc = max(1, Int(ceil(m * n)))
                pct = round(m * 100, digits=2)
                print("  $(dname) — minsup=$(pct)% ($(mc)/$(n))... ")
                
                try
                    our_result = relim_opt(transactions, mc)
                    
                    if isfile(SPMF_JAR_PATH)
                        try
                            spmf_t = run_spmf_external(fpath, out_spmf, m)
                            if spmf_t >= 0 && isfile(out_spmf)
                                spmf_result = read_spmf_output(out_spmf)
                                (matched, total, rate) = compare_with_spmf(our_result, spmf_result)
                                analysis = rate == 100.0 ? "MATCH" : (rate >= 99.0 ? "Near_MATCH" : "MISMATCH")
                                println("$(length(our_result)) vs SPMF $(length(spmf_result)) — khớp $(rate)% [$(analysis)]")
                                println(f, "$(dname),$(pct),$(mc),$(length(our_result)),$(length(spmf_result)),$(matched),$(rate),$(analysis)")
                            else
                                println("$(length(our_result)) FI (SPMF Failed/Crashed)")
                                println(f, "$(dname),$(pct),$(mc),$(length(our_result)),N/A,N/A,N/A,SPMF_Crash")
                            end
                        finally
                            rm(out_spmf, force=true)
                        end
                    else
                        println("$(length(our_result)) FI (Bỏ qua SPMF)")
                        println(f, "$(dname),$(pct),$(mc),$(length(our_result)),N/A,N/A,N/A,No_SPMF")
                    end
                catch e
                    println("ERROR: $e")
                end
            end
        end
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# b) TIME vs MINSUP & c) FI COUNT vs MINSUP
# ═════════════════════════════════════════════════════════════════════════════

function run_time_and_fi_benchmark()
    csv_path = joinpath(DATA_DIR, "time_fi_results.csv")
    println("\n" * "═"^70)
    println("  b) TIME vs MINSUP & c) FI COUNT vs MINSUP")
    println("  (*Lưu ý: Thời gian SPMF bị cộng dồn ~0.15s overhead khởi động Java)")
    println("═"^70)
    
    open(csv_path, "w") do f
        println(f, "Dataset,Minsup_Pct,Time_Basic_ms,Time_Opt_ms,Time_SPMF_ms,Num_FI")
        
        for (fname, dname, minsups) in DATASETS
            fpath = joinpath(BENCHMARK_DIR, fname)
            out_spmf = joinpath(BENCHMARK_DIR, "temp_spmf_out.txt")
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
                    
                    spmf_time_s = -1.0
                    if isfile(SPMF_JAR_PATH)
                        try
                            spmf_time_s = run_spmf_external(fpath, out_spmf, m)
                        finally
                            rm(out_spmf, force=true)
                        end
                    end

                    tb_ms = round(tb * 1000, digits=2)
                    to_ms = round(to * 1000, digits=2)
                    ts_ms = spmf_time_s >= 0 ? round(spmf_time_s * 1000, digits=2) : -1.0
                    
                    println("Basic: $(tb_ms)ms | Opt: $(to_ms)ms | SPMF: $(ts_ms)ms | $(length(rb)) FI")
                    println(f, "$(dname),$(pct),$(tb_ms),$(to_ms),$(ts_ms),$(length(rb))")
                catch e
                    println("ERROR: OOM hoặc System Limit")
                end
            end
        end
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# d) MEMORY USAGE TẠI MINSUP TRUNG BÌNH
# ═════════════════════════════════════════════════════════════════════════════

function run_memory_benchmark()
    csv_path = joinpath(DATA_DIR, "memory_results.csv")
    println("\n" * "═"^70)
    println("  d) MEMORY USAGE (Tại minsup trung bình - đo bằng Allocated Bytes)")
    println("═"^70)
    
    open(csv_path, "w") do f
        println(f, "Dataset,Minsup_Pct,Mem_Basic_MB,Mem_Opt_MB")
        
        for (fname, dname, minsups) in DATASETS
            fpath = joinpath(BENCHMARK_DIR, fname)
            if !isfile(fpath); continue; end
            
            m = minsups[Int(ceil(length(minsups)/2))]
            transactions = read_spmf_file(fpath)
            mc = max(1, Int(ceil(m * length(transactions))))
            pct = round(m * 100, digits=2)
            
            print("  $(dname) (minsup=$(pct)%)... ")
            try
                (_, _, mb) = measure(() -> relim_mine(transactions, mc))
                (_, _, mo) = measure(() -> relim_opt(transactions, mc))
                
                println("Basic: $(mb) MB | Opt: $(mo) MB")
                println(f, "$(dname),$(pct),$(mb),$(mo)")
            catch e
                println("ERROR: $e")
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
    minsup_pct = 0.02  # 2%
    
    open(csv_path, "w") do f
        println(f, "Subset_Pct,Num_Trans,Minsup_Count,Time_Basic_ms,Time_Opt_ms,Num_FI_Basic,Num_FI_Opt,Trend")
        
        prev_time_basic = 0.0
        prev_trans = 0
        
        for pct in [0.10, 0.25, 0.50, 0.75, 1.00]
            n_sub = Int(ceil(pct * n_total))
            subset = all_txs[1:n_sub]
            mc = max(1, Int(ceil(minsup_pct * n_sub)))
            
            print("  $(Int(pct*100))% ($(n_sub) trans, minsup=$(mc))... ")
            try
                (rb, tb, _) = measure(() -> relim_mine(subset, mc))
                (ro, to, _) = measure(() -> relim_opt(subset, mc))
                
                tb_ms = round(tb * 1000, digits=2)
                to_ms = round(to * 1000, digits=2)
                
                trend = ""
                if prev_trans > 0
                    time_ratio = tb / prev_time_basic
                    trans_ratio = n_sub / prev_trans
                    if time_ratio < trans_ratio * 0.8
                        trend = "Sublinear"
                    elseif time_ratio > trans_ratio * 1.2
                        trend = "Superlinear"
                    else
                        trend = "Linear"
                    end
                else
                    trend = "Baseline"
                end
                prev_time_basic = tb
                prev_trans = n_sub
                
                println("Basic: $(tb_ms)ms | Opt: $(to_ms)ms | FI: $(length(rb)) [$(trend)]")
                println(f, "$(Int(pct*100)),$(n_sub),$(mc),$(tb_ms),$(to_ms),$(length(rb)),$(length(ro)),$(trend)")
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
    
    println("  n_trans=$(n_trans), n_items=$(n_items), minsup=$(minsup_pct*100)%")
    
    open(csv_path, "w") do f
        println(f, "Avg_TxLen,Time_Basic_ms,Time_Opt_ms,Num_FI_Basic,Num_FI_Opt,Analysis")
        
        for avg_len in [3, 4, 5, 6, 7, 8, 9, 10]
            txs = generate_synthetic_sparse(n_trans, n_items, avg_len)
            mc = max(1, Int(ceil(minsup_pct * n_trans)))
            print("  avg_len=$(avg_len)... ")
            try
                (rb, tb, _) = measure(() -> relim_mine(txs, mc))
                (ro, to, _) = measure(() -> relim_opt(txs, mc))
                
                tb_ms = round(tb * 1000, digits=2)
                to_ms = round(to * 1000, digits=2)
                
                analysis = avg_len <= 5 ? "Low_impact" : (avg_len <= 15 ? "Medium_impact" : "High_impact")
                
                println("Basic: $(tb_ms)ms ($(length(rb)) FI) | Opt: $(to_ms)ms ($(length(ro)) FI) [$(analysis)]")
                println(f, "$(avg_len),$(tb_ms),$(to_ms),$(length(rb)),$(length(ro)),$(analysis)")
            catch e
                println("ERROR: $e")
            end
        end
    end
end

function main()
    run_correctness_with_spmf()  # a)
    run_time_and_fi_benchmark()  # b) & c)
    run_memory_benchmark()       # d)
    run_scalability()            # e)
    run_txlen_experiment()       # f)
    println("\n🎉 HOÀN TẤT TẤT CẢ BENCHMARK CỦA LAB 2!")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end