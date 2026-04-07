module AlgorithmOptV3

export relim_optimized_mine

struct TransactionSuffix
    tx_idx::Int
    pos::Int
end

# Không chứa Abstract Type, giữ Bool để kiểm tra trạng thái thay vì dùng `nothing`
mutable struct ItemList
    support::Int
    suffixes::Vector{TransactionSuffix}
    active::Bool 
end

# Hàm khởi tạo mặc định cho Object Pool
ItemList() = ItemList(0, TransactionSuffix[], false)


function relim_optimized_mine(transactions::Vector{Vector{Int}}, minsup::Int)
    # --- BƯỚC 1: TIỀN XỬ LÝ (PREPROCESSING) ---
    item_counts = Dict{Int, Int}()
    sizehint!(item_counts, 2000)
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
    
    master_db = Vector{Vector{Int}}()
    sizehint!(master_db, length(transactions))
    for t in transactions
        filtered = Int[]
        sizehint!(filtered, length(t))
        for item in t
            if haskey(item_to_rank, item)
                push!(filtered, item_to_rank[item])
            end
        end
        if !isempty(filtered)
            sort!(filtered)
            push!(master_db, filtered)
        end
    end
    
    N = length(valid_items)
    num_tx = length(master_db)
    frequent_itemsets = Vector{Tuple{Vector{Int}, Int}}()

    if N == 0
        return frequent_itemsets
    end
    
    # --- BƯỚC 2: KHỞI TẠO OBJECT POOLS (100% Không cấp phát RAM sau bước này) ---
    # Khởi tạo ma trận bộ đệm cho mọi độ sâu đệ quy
    buffer_cache = [[ItemList() for _ in 1:(N + 1)] for _ in 1:(N + 1)]
    
    # Cấp phát trước dung lượng (capacity) cho các mảng suffixes để push! đạt O(1)
    # Dự đoán kích thước an toàn để tránh re-allocation
    safe_capacity = min(100_000, num_tx) 
    for d in 1:(N + 1)
        for i in 1:(N + 1)
            sizehint!(buffer_cache[d][i].suffixes, safe_capacity)
        end
    end
    
    local_counters_pool = [zeros(Int, N + 1) for _ in 1:(N + 1)]
    
    # --- BƯỚC 3: GÁN DỮ LIỆU ROOT ---
    root_lists = buffer_cache[1]
    for (i, t) in enumerate(master_db)
        head = t[1]
        root_lists[head].active = true
        root_lists[head].support += 1
        if length(t) > 1
            push!(root_lists[head].suffixes, TransactionSuffix(i, 2))
        end
    end
    
    prefix_buffer = Int[]
    sizehint!(prefix_buffer, N)
    
    # Kích hoạt lõi đệ quy
    _relim_recursive_ultimate!(
        root_lists, prefix_buffer, minsup, frequent_itemsets, rank_to_item, 
        1, N, master_db, buffer_cache, local_counters_pool, 2
    )
    
    return frequent_itemsets
end

function _relim_recursive_ultimate!(
    lists::Vector{ItemList}, 
    prefix::Vector{Int}, 
    minsup::Int, 
    frequent_itemsets::Vector{Tuple{Vector{Int}, Int}}, 
    rank_to_item::Vector{Int}, 
    start_idx::Int, 
    max_idx::Int,
    master_db::Vector{Vector{Int}},
    buffer_cache::Vector{Vector{ItemList}},
    local_counters_pool::Vector{Vector{Int}},
    depth::Int
)
    for i in start_idx:max_idx
        current_list = lists[i]
        
        # Bỏ qua nếu node không có dữ liệu
        if !current_list.active
            continue
        end
        
        # Nhánh rác không đủ minsup: Bàn giao hậu tố cho anh em ngang hàng (Siblings)
        if current_list.support < minsup
            for suf in current_list.suffixes
                t = master_db[suf.tx_idx]
                if suf.pos <= length(t)
                    head = t[suf.pos]
                    lists[head].active = true
                    lists[head].support += 1
                    push!(lists[head].suffixes, TransactionSuffix(suf.tx_idx, suf.pos + 1))
                end
            end
            # Dọn dẹp Node hiện tại cực nhanh bằng empty!
            current_list.active = false
            empty!(current_list.suffixes) 
            continue
        end

        support = current_list.support
        original_item = rank_to_item[i]
        
        push!(prefix, original_item)
        push!(frequent_itemsets, (copy(prefix), support))
        
        # --- LOCAL SUPPORT PRUNING ---
        local_counters = local_counters_pool[depth]
        fill!(local_counters, 0)
        for suf in current_list.suffixes
            t = master_db[suf.tx_idx]
            for p in suf.pos:length(t)
                local_counters[t[p]] += 1
            end
        end
        
        # --- DỌN DẸP BUFFER CHO ĐỆ QUY CON (O(1) memory) ---
        var_next_lists = buffer_cache[depth]
        for idx in 1:max_idx
            var_next_lists[idx].support = 0
            var_next_lists[idx].active = false
            empty!(var_next_lists[idx].suffixes) # Xóa ảo, giữ capacity RAM
        end
        
        # --- QUY TRÌNH TÁCH NHÁNH (SPLIT) CỦA RELIM ---
        for suf in current_list.suffixes
            t = master_db[suf.tx_idx]
            if suf.pos <= length(t)
                
                # 1. Chuyển hậu tố cho anh em (Sibling Reassignment)
                head = t[suf.pos]
                lists[head].active = true
                lists[head].support += 1
                push!(lists[head].suffixes, TransactionSuffix(suf.tx_idx, suf.pos + 1))
                
                # 2. Chiếu dữ liệu xuống con (Child Projection) + Cắt tỉa (Pruning)
                pos_child = suf.pos
                while pos_child <= length(t) && local_counters[t[pos_child]] < minsup
                    pos_child += 1
                end
                
                if pos_child <= length(t)
                    child_head = t[pos_child]
                    var_next_lists[child_head].active = true
                    var_next_lists[child_head].support += 1
                    push!(var_next_lists[child_head].suffixes, TransactionSuffix(suf.tx_idx, pos_child + 1))
                end
            end
        end
        
        # --- ĐỆ QUY ---
        _relim_recursive_ultimate!(
            var_next_lists, prefix, minsup, frequent_itemsets, rank_to_item, 
            i + 1, max_idx, master_db, buffer_cache, local_counters_pool, depth + 1
        )
        
        pop!(prefix)
        
        # Dọn dẹp Node sau khi xong đệ quy
        current_list.active = false
        empty!(current_list.suffixes)
    end
end

end # module AlgorithmOptV3

# Backward-compatible alias nếu có script cũ import tên module mới hơn.
const AlgorithmOptFinal = AlgorithmOptV3
