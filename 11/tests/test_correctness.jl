# tests/test_correctness.jl
# =============================================================================
# TV3 - Level 2: Kiểm thử tự động tính đúng đắn (Correctness)
# Test trên 6 CSDL khác nhau (bao gồm CSDL của TV1: data/toy/demo.txt)
# Chạy: julia --project=. tests/test_correctness.jl  (từ thư mục 11/)
# =============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "algorithm", "relim.jl"))
include(joinpath(@__DIR__, "..", "src", "algorithm", "relim_opt.jl"))

using .Algorithm: relim_mine
using .AlgorithmOptV3: relim_optimized_mine
using .Utils: read_spmf_file

const relim_opt = relim_optimized_mine

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

    @testset "DS1: CSDL TV1 — demo.txt (minsup=2)" begin
        path = joinpath(@__DIR__,"..","data","toy","demo.txt")
        @test isfile(path)
        txs = read_spmf_file(path)
        @test length(txs) == 5
        exp = [([1],4),([2],4),([3],4),([1,2],3),([1,3],3),([2,3],3),([1,2,3],2)]
        test_both(txs, 2, exp)
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

println("\n✅ Tất cả bài Test đã PASS!")
