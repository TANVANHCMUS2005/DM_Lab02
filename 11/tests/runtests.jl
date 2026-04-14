# tests/runtests.jl
# =============================================================================
# Chạy: julia --project tests/runtests.jl  (từ thư mục 11/)
# =============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "algorithm", "relim.jl"))
include(joinpath(@__DIR__, "..", "src", "algorithm", "relim_opt.jl"))

using .Algorithm: relim_mine
using .AlgorithmOptV3: relim_optimized_mine
using .Utils: read_spmf_file

const relim_opt = relim_optimized_mine

const DATA_DIR = joinpath(@__DIR__, "..", "data")
const BENCHMARK_DIR = joinpath(DATA_DIR, "benchmark")
const RESULTS_DIR = joinpath(DATA_DIR, "results")
const SPMF_JAR_PATH = joinpath(DATA_DIR, "tools", "spmf.jar")

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
    cmd = ignorestatus(`java -Xmx16G -jar $SPMF_JAR_PATH run Relim $input_file $output_file $spmf_min`)
    try
        t = @elapsed is_success = success(pipeline(cmd, stdout=devnull, stderr=devnull))
        return is_success ? t : -1.0
    catch e
        return -1.0
    end
end

function compare_with_spmf(our_result::Vector{Tuple{Vector{Int},Int}}, spmf_result::Vector{Tuple{Vector{Int},Int}})
    our_set = Set{UInt64}(hash((sort(is), s)) for (is, s) in our_result)
    spmf_set = Set{UInt64}(hash((sort(is), s)) for (is, s) in spmf_result)
    matched = length(intersect(our_set, spmf_set))
    total = length(union(our_set, spmf_set))
    rate = total == 0 ? 100.0 : round(matched / total * 100, digits=2)
    return (matched, total, rate)
end

function compare_outputs(actual::Vector{Tuple{Vector{Int},Int}}, expected::Vector{Tuple{Vector{Int},Int}})
    a = sort([(sort(is), s) for (is, s) in actual])
    e = sort([(sort(is), s) for (is, s) in expected])
    @test a == e
end

function test_both(txs::Vector{Vector{Int}}, ms::Int, exp::Vector{Tuple{Vector{Int},Int}})
    @testset "Basic"     begin compare_outputs(relim_mine(txs, ms), exp) end
    @testset "Optimized" begin compare_outputs(relim_opt(txs, ms), exp) end
end

function test_cross(txs::Vector{Vector{Int}}, ms::Int; n::Union{Int,Nothing}=nothing)
    rb = relim_mine(txs, ms); ro = relim_opt(txs, ms)
    sb = sort([(sort(is),s) for (is,s) in rb])
    so = sort([(sort(is),s) for (is,s) in ro])
    @test sb == so
    if n !== nothing; @test length(rb)==n; @test length(ro)==n; end
end

@testset "Relim Correctness — 6 Datasets" begin

    @testset "DS1: CSDL TV1 — demo.txt (minsup=3)" begin
        path = joinpath(@__DIR__,"..","data","toy","demo.txt")
        @test isfile(path)
        txs = read_spmf_file(path)
        @test length(txs) == 6
        exp = [([1],4),([2],5),([3],5),([4],3),([5],3),
               ([1,2],3),([1,3],3),([1,4],3),([2,3],4),([2,5],3)]
        test_both(txs, 3, exp)
    end

    @testset "DS2: Tập thưa — cặp rời (minsup=2)" begin
        txs = [[1,2],[3,4],[5,6],[1,2],[3,4]]
        exp = [([1],2),([2],2),([3],2),([4],2),([1,2],2),([3,4],2)]
        test_both(txs, 2, exp)
    end

    @testset "DS3: Single Path (minsup=2)" begin
        txs = [[1,2,3,4,5],[1,2,3,4,5],[1,2,3,4,5]]
        test_cross(txs, 2; n=31)
    end

    @testset "DS4: Minsup quá cao — rỗng (minsup=4)" begin
        txs = [[1,2,3],[1,2,3],[1,2]]
        test_both(txs, 4, Vector{Tuple{Vector{Int},Int}}())
    end

    @testset "DS5: Chồng chéo phức tạp (minsup=3)" begin
        txs = [[1,2,4,5],[2,3,5],[1,2,4,5],[1,2,3,5],[1,2,4,5],[2,3,4]]
        exp = [([1],4),([2],6),([3],3),([4],4),([5],5),
               ([1,2],4),([1,4],3),([1,5],4),([2,3],3),([2,4],4),([2,5],5),([4,5],3),
               ([1,2,4],3),([1,2,5],4),([1,4,5],3),([2,4,5],3),([1,2,4,5],3)]
        test_both(txs, 3, exp)
    end

    @testset "DS6: Mỗi giao dịch 1 item (minsup=2)" begin
        txs = [[10],[20],[10],[30],[20],[10]]
        exp = [([10],3),([20],2)]
        test_both(txs, 2, exp)
    end
end

@testset "Relim Correctness vs SPMF" begin
    @testset "SPMF jar exists" begin
        @test isfile(SPMF_JAR_PATH)
    end

    DATASETS_SPMF = [
        ("chess.txt", "Chess", [0.85, 0.80, 0.75]), 
        ("mushroom.txt", "Mushroom", [0.30, 0.25, 0.20]), 
        ("retail.txt", "Retail", [0.05, 0.03, 0.02]),
        ("accidents.txt", "Accidents", [0.90, 0.85, 0.80]), 
        ("T10I4D100K.txt", "T10I4D100K", [0.05, 0.04, 0.03]),
    ]

    for (fname, dname, correctness_minsups) in DATASETS_SPMF
        fpath = joinpath(BENCHMARK_DIR, fname)
        @testset "$(fname)" begin
            @test isfile(fpath)
            
            txs = read_spmf_file(fpath)
            n = length(txs)
            
            for m in correctness_minsups
                mc = max(1, Int(ceil(m * n)))
                pct = round(m * 100, digits=1)
                
                @testset "minsup_$(pct)pct" begin
                    our_result = relim_opt(txs, mc)
                    
                    out_spmf = joinpath(BENCHMARK_DIR, "temp_test_spmf_$(dname).txt")
                    try
                        spmf_t = run_spmf_external(fpath, out_spmf, m)
                        if spmf_t >= 0 && isfile(out_spmf)
                            spmf_result = read_spmf_output(out_spmf)
                            (matched, total, rate) = compare_with_spmf(our_result, spmf_result)
                            @test rate == 100.0
                        end
                    finally
                        rm(out_spmf, force=true)
                    end
                end
            end
        end
    end
end

println("\n Tất cả bài Test đã PASS!")