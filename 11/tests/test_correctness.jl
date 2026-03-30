# tests/test_correctness.jl
# =============================================================================
# TV3 - Level 2: Kiểm thử tự động trên ít nhất 5 CSDL khác nhau
# Chạy: julia --project=. tests/test_correctness.jl  (từ thư mục 11/)
# =============================================================================

using Test

# Include thuật toán cơ bản (sẽ tự include structures.jl & utils.jl nhờ guard bên trong)
include(joinpath(@__DIR__, "..", "src", "algorithm", "relim.jl"))
# Include thuật toán tối ưu (guard isdefined ngăn load lại structures/utils)
include(joinpath(@__DIR__, "..", "src", "algorithm", "relim_opt.jl"))

using .Algorithm: relim_mine
using .AlgorithmOptV3: relim_optimized_mine as relim_opt_mine

"""
So sánh kết quả trả về với bộ expected. Sort cả 2 trước khi so.
"""
function compare_outputs(actual::Vector{Tuple{Vector{Int}, Int}}, expected::Vector{Tuple{Vector{Int}, Int}})
    actual_sorted  = sort([(sort(is), s) for (is, s) in actual])
    expected_sorted = sort([(sort(is), s) for (is, s) in expected])
    @test actual_sorted == expected_sorted
end

# =============================================================================
@testset "Relim Correctness Tests (5 Datasets)" begin

    # ─────────────────────────────────────────────────────────
    @testset "Dataset 1: Toy demo.txt (minsup=2)" begin
        transactions = [
            [1, 2, 3],
            [1, 2],
            [1, 3],
            [2, 3],
            [1, 2, 3]
        ]
        expected = [
            ([1], 4),
            ([2], 4),
            ([3], 4),
            ([1, 2], 3),
            ([1, 3], 3),
            ([2, 3], 3),
            ([1, 2, 3], 2)
        ]

        @testset "Basic" begin
            result = relim_mine(transactions, 2)
            compare_outputs(result, expected)
        end
        @testset "Optimized" begin
            result = relim_opt_mine(transactions, 2)
            compare_outputs(result, expected)
        end
    end

    # ─────────────────────────────────────────────────────────
    @testset "Dataset 2: Tập thưa - Các cặp rời nhau (minsup=2)" begin
        transactions = [
            [1, 2],
            [3, 4],
            [5, 6],
            [1, 2],
            [3, 4]
        ]
        expected = [
            ([1], 2), ([2], 2), ([3], 2), ([4], 2),
            ([1, 2], 2), ([3, 4], 2)
        ]
        @testset "Basic" begin compare_outputs(relim_mine(transactions, 2), expected) end
        @testset "Optimized" begin compare_outputs(relim_opt_mine(transactions, 2), expected) end
    end

    # ─────────────────────────────────────────────────────────
    @testset "Dataset 3: Single Path - Mọi giao dịch giống nhau (minsup=2)" begin
        transactions = [
            [1, 2, 3, 4, 5],
            [1, 2, 3, 4, 5],
            [1, 2, 3, 4, 5]
        ]
        # Mọi tập con không rỗng đều có support = 3. Tổng cộng 2^5 - 1 = 31 itemsets.
        result_basic = relim_mine(transactions, 2)
        result_opt   = relim_opt_mine(transactions, 2)

        @test length(result_basic) == 31
        @test length(result_opt) == 31

        # So sánh chéo Basic vs Opt
        basic_sorted = sort([(sort(is), s) for (is, s) in result_basic])
        opt_sorted   = sort([(sort(is), s) for (is, s) in result_opt])
        @test basic_sorted == opt_sorted
    end

    # ─────────────────────────────────────────────────────────
    @testset "Dataset 4: Minsup quá cao - Không có FI nào (minsup=4)" begin
        transactions = [
            [1, 2, 3],
            [1, 2, 3],
            [1, 2]
        ]
        expected = Vector{Tuple{Vector{Int}, Int}}()
        @testset "Basic" begin compare_outputs(relim_mine(transactions, 4), expected) end
        @testset "Optimized" begin compare_outputs(relim_opt_mine(transactions, 4), expected) end
    end

    # ─────────────────────────────────────────────────────────
    @testset "Dataset 5: CSDL chồng chéo phức tạp (minsup=3)" begin
        transactions = [
            [1, 2, 4, 5],
            [2, 3, 5],
            [1, 2, 4, 5],
            [1, 2, 3, 5],
            [1, 2, 4, 5],
            [2, 3, 4]
        ]
        expected = [
            ([1], 4), ([2], 6), ([3], 3), ([4], 4), ([5], 5),
            ([1, 2], 4), ([1, 4], 3), ([1, 5], 4),
            ([2, 3], 3), ([2, 4], 4), ([2, 5], 5), ([4, 5], 3),
            ([1, 2, 4], 3), ([1, 2, 5], 4), ([1, 4, 5], 3), ([2, 4, 5], 3),
            ([1, 2, 4, 5], 3)
        ]
        @testset "Basic" begin compare_outputs(relim_mine(transactions, 3), expected) end
        @testset "Optimized" begin compare_outputs(relim_opt_mine(transactions, 3), expected) end
    end

end # @testset

println("\n✅ Tất cả bài Test đã được thực thi thành công!")
