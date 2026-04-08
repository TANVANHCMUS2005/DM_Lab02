# Bắt đầu file relim.jl - Bao gồm cả thư viện và phần chạy chính để thỏa mãn đúng cấu trúc thư mục

# Guard: chỉ include nếu module chưa tồn tại (tránh xung đột khi test include nhiều file)
if !isdefined(Main, :Structures)
    include(joinpath(@__DIR__, "..", "structures.jl"))
end
if !isdefined(Main, :Utils)
    include(joinpath(@__DIR__, "..", "utils.jl"))
end

module Algorithm

using ArgParse
using ..Structures
using ..Utils

export relim_mine, main_cli

"""
    relim_mine(transactions::Vector{Vector{Int}}, minsup::Int)

Hàm chính của thuật toán Relim. Nhận vào dữ liệu gốc và ngưỡng minsup.
Trả về danh sách các tập phổ biến (Frequent Itemsets).
"""
function relim_mine(transactions::Vector{Vector{Int}}, minsup::Int)
    frequent_itemsets = Vector{Tuple{Vector{Int}, Int}}()
    
    # === GIAI ĐOẠN 1: TIỀN XỬ LÝ (PREPROCESSING) ===
    item_counts = Dict{Int, Int}()
    for t in transactions
        for item in t
            item_counts[item] = get(item_counts, item, 0) + 1
        end
    end
    
    valid_items = [item for (item, count) in item_counts if count >= minsup]
    sort!(valid_items, by = x -> (item_counts[x], x))
    
    item_to_rank = Dict{Int, Int}()
    rank_to_item = Vector{Int}(undef, length(valid_items))
    for (idx, item) in enumerate(valid_items)
        item_to_rank[item] = idx
        rank_to_item[idx] = item
    end
    
    # === GIAI ĐOẠN 2: KHỞI TẠO MẢNG LISTS CHO CÂY THƯ MỤC ẢO (ROOT LEVEL) ===
    N = length(valid_items)
    lists = [ItemList(j) for j in 1:N]
    
    for t in transactions
        filtered = Int[]
        for item in t
            if haskey(item_to_rank, item)
                push!(filtered, item_to_rank[item])
            end
        end
        if !isempty(filtered)
            sort!(filtered)
            
            # Lấy item đầu tiên
            head_rank = filtered[1]
            lists[head_rank].support += 1
            
            # Tách phần còn lại vào TransPtr thay vì cắt mảng
            if length(filtered) > 1
                push!(lists[head_rank].transactions, TransPtr(filtered, 2))
            end
        end
    end
    
    # === GIAI ĐOẠN 3: ĐỆ QUY (RECURSIVE ELIMINATION) ===
    _relim_recursive!(lists, Int[], minsup, frequent_itemsets, rank_to_item, 1)
    
    return frequent_itemsets
end

function _relim_recursive!(lists::Vector{ItemList}, prefix::Vector{Int}, minsup::Int, 
                           frequent_itemsets::Vector{Tuple{Vector{Int}, Int}}, 
                           rank_to_item::Vector{Int}, start_idx::Int)
    for i in start_idx:length(lists)
        current_list = lists[i]
        support = current_list.support
        
        is_frequent = support >= minsup
        
        # Nếu nhánh hiện tại không đủ minsup, ta KHÔNG đệ quy sâu thêm.
        # Nhưng ta VẪN PHẢI tái phân bổ (reassign) giao dịch của list này sang 
        # các list phía sau trong cùng cấp độ để tránh làm mất dữ liệu của chúng.
        
        # Khởi tạo mảng cấp dưới nếu nhánh này phổ biến
        var_next_lists = is_frequent ? [ItemList(j) for j in 1:length(lists)] : nothing
        new_prefix = prefix
        
        if is_frequent
            original_item = rank_to_item[current_list.item]
            new_prefix = copy(prefix)
            push!(new_prefix, original_item)
            push!(frequent_itemsets, (new_prefix, support))
        end
        
        for t_ptr in current_list.transactions
            # Do t_ptr chỉ chứa những giao dịch còn phần tử hợp lệ
            head = t_ptr.items[t_ptr.idx]
            
            # Kiểm tra xem giao dịch này còn phần tử phía sau không
            has_next = t_ptr.idx < length(t_ptr.items)
            next_ptr = TransPtr(t_ptr.items, t_ptr.idx + 1)
            
            # 1. Tái phân bổ vào mảng lists của Cấp Hiện Tại (BẮT BUỘC ĐỂ KHÔNG MẤT ITEM PHÍA SAU)
            lists[head].support += 1
            if has_next
                push!(lists[head].transactions, next_ptr)
            end
            
            # 2. Sinh nhánh mới trên Cấp Thấp Hơn (Chỉ khi is_frequent == true)
            if is_frequent
                var_next_lists[head].support += 1
                if has_next
                    push!(var_next_lists[head].transactions, next_ptr)
                end
            end
        end
        
        # Nếu tỏa điều kiện thì mới đi sâu xuống nhánh
        if is_frequent
            _relim_recursive!(var_next_lists, new_prefix, minsup, frequent_itemsets, rank_to_item, i + 1)
        end
    end
end

"""
    parse_commandline()
Hàm bắt các tham số được người dùng truyền vào từ giao diện Terminal.
"""
function parse_commandline()
    s = ArgParseSettings(description = "Relim Algorithm - Frequent Itemset Mining")
    
    @add_arg_table! s begin
        "--input", "-i"
            help = "Đường dẫn tới file Dữ liệu gốc (Dataset) chuẩn SPMF"
            required = true
        "--output", "-o"
            help = "Đường dẫn xuất file Kết Quả"
            default = "output_fim.txt"
        "--minsup", "-m"
            help = "Ngưỡng độ hỗ trợ tối thiểu (Ví dụ: 0.5 là 50%, 2 là số lượng 2)"
            arg_type = Float64
            required = true
        "--algo", "-a"
            help = "Phiên bản thuật toán: 'basic' (mặc định) hoặc 'opt' (tối ưu)"
            default = "basic"
    end
    
    return parse_args(s)
end

function main_cli()
    parsed_args = parse_commandline()
    input_file  = parsed_args["input"]
    output_file = parsed_args["output"]
    minsup_val  = parsed_args["minsup"]
    algo_choice = parsed_args["algo"]
    
    # Chọn hàm khai thác theo --algo
    if algo_choice == "opt"
        include(joinpath(@__DIR__, "relim_opt.jl"))
        mine_fn = Main.AlgorithmOptV3.relim_optimized_mine
        println(">>> Sử dụng phiên bản: Relim OPTIMIZED")
    else
        mine_fn = relim_mine
        println(">>> Sử dụng phiên bản: Relim BASIC")
    end
    
    println(">>> Đang nạp dataset: ", input_file)
    transactions = read_spmf_file(input_file)
    n_transactions = length(transactions)
    println("Đã tải ", n_transactions, " giao dịch.")
    
    minsup_count = minsup_val <= 1.0 ? Int(ceil(minsup_val * n_transactions)) : Int(minsup_val)
    println("Min Support Tuyệt Đối: ", minsup_count)
    
    println(">>> Bắt đầu chạy Đệ quy...")
    elapsed_time = @elapsed begin
        itemsets = mine_fn(transactions, minsup_count)
    end
    
    sort!(itemsets, by = x -> length(x[1]))
    
    println("Khai thác hoàn tất! Tìm thấy ", length(itemsets), " tập phổ biến.")
    println("Thời gian chạy: ", round(elapsed_time, digits=4), " giây.")
    
    println(">>> Đang xuất file vào: ", output_file)
    write_spmf_file(output_file, itemsets)
    println("Mọi quy trình hoàn thành!")
end

end # module Algorithm

# Kích hoạt CLI nếu chạy trực tiếp file này từ terminal
if abspath(PROGRAM_FILE) == @__FILE__
    Algorithm.main_cli()
end
end
