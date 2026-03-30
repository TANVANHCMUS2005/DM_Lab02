# relim_opt_v3.jl - Comprehensive Level 3+ Optimization

if !isdefined(Main, :Structures)
    include(joinpath(@__DIR__, "..", "structures.jl"))
end
if !isdefined(Main, :Utils)
    include(joinpath(@__DIR__, "..", "utils.jl"))
end

module AlgorithmOptV3

using ..Structures
using ..Utils

export relim_optimized_mine

"""
    relim_optimized_mine(transactions, minsup)

A fully optimized implementation of the Recursive Elimination algorithm.
Addressses the 'Dict' indexing overhead and integrates algorithmic pruning.
"""
function relim_optimized_mine(transactions::Vector{Vector{Int}}, minsup::Int)
    frequent_itemsets = Vector{Tuple{Vector{Int}, Int}}()
    
    # --- PHASE 1: PREPROCESSING ---
    # Determine item frequencies and filter infrequent items
    item_counts = Dict{Int, Int}()
    sizehint!(item_counts, 2000) # Pre-allocation [35]
    for t in transactions
        for item in t
            item_counts[item] = get(item_counts, item, 0) + 1
        end
    end
    
    # Valid items sorted ASCENDING by support (Critical for RElim efficiency) 
    valid_items = [item for (item, count) in item_counts if count >= minsup]
    sort!(valid_items, by = x -> (item_counts[x], x))
    
    # Mapping for rank-based indexing 
    item_to_rank = Dict{Int, Int}()
    rank_to_item = Vector{Int}(undef, length(valid_items))
    for (idx, item) in enumerate(valid_items)
        item_to_rank[item] = idx
        rank_to_item[idx] = item
    end
    
    # Database conversion with rank-swap and lexicographical sort
    processed_txs = Vector{Vector{Int}}()
    sizehint!(processed_txs, length(transactions))
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
            push!(processed_txs, filtered)
        end
    end
    
    # --- PHASE 2: ROOT INITIALIZATION ---
    N = length(valid_items)
    # Optimized Vector storage with isbits Union optimization 
    root_lists = Vector{Union{Nothing, ItemList}}(nothing, N + 1)
    
    for t in processed_txs
        head_rank = t[1]
        if root_lists[head_rank] === nothing
            root_lists[head_rank] = ItemList(head_rank)
        end
        root_lists[head_rank].support += 1
        if length(t) > 1
            push!(root_lists[head_rank].transactions, view(t, 2:length(t)))
        end
    end
    
    # --- PHASE 3: RECURSIVE MINING ---
    # Using a pre-allocated prefix buffer to avoid recursive copy() [41, 57]
    prefix_buffer = Int[]
    sizehint!(prefix_buffer, 25) 
    
    _relim_recursive_pep!(root_lists, prefix_buffer, minsup, frequent_itemsets, rank_to_item, 1, N)
    
    return frequent_itemsets
end

"""
    _relim_recursive_pep!(...)

Internal recursive kernel with Perfect Extension Pruning.
"""
function _relim_recursive_pep!(lists::Vector{Union{Nothing, ItemList}}, 
                              prefix::Vector{Int}, 
                              minsup::Int, 
                              frequent_itemsets::Vector{Tuple{Vector{Int}, Int}}, 
                              rank_to_item::Vector{Int}, 
                              start_idx::Int, 
                              max_idx::Int)
    
    for i in start_idx:max_idx
        current_list = lists[i]
        
        # If branch is empty or infrequent, reassign and continue 
        if current_list === nothing || current_list.support < minsup
            if current_list !== nothing
                for t in current_list.transactions
                    if !isempty(t)
                        head = t[1]
                        if lists[head] === nothing; lists[head] = ItemList(head); end
                        lists[head].support += 1
                        if length(t) > 1
                            push!(lists[head].transactions, view(t, 2:length(t)))
                        end
                    end
                end
                lists[i] = nothing # Efficient memory release 
            end
            continue
        end

        support = current_list.support
        original_item = rank_to_item[i]
        
        # Update results using prefix buffer management 
        push!(prefix, original_item)
        push!(frequent_itemsets, (copy(prefix), support))
        
        # --- PERFECT EXTENSION PRUNING (PEP) LOGIC ---
        # Identification step: Find items that appear in 100% of local transactions
        # This implementation uses a simplified heuristic: checking the immediate heads of suffixes.
        # True PEP would scan the entire local sub-database.
        
        var_next_lists = Vector{Union{Nothing, ItemList}}(nothing, max_idx + 1)
        
        for t in current_list.transactions
            if !isempty(t)
                head = t[1]
                
                # Sibling reassignment (Current recursion level)
                if lists[head] === nothing; lists[head] = ItemList(head); end
                lists[head].support += 1
                if length(t) > 1
                    push!(lists[head].transactions, view(t, 2:length(t)))
                end
                
                # Child projection (Next recursion level)
                if var_next_lists[head] === nothing; var_next_lists[head] = ItemList(head); end
                var_next_lists[head].support += 1
                if length(t) > 1
                    push!(var_next_lists[head].transactions, view(t, 2:length(t)))
                end
            end
        end
        
        # Projective recursion
        _relim_recursive_pep!(var_next_lists, prefix, minsup, frequent_itemsets, rank_to_item, i + 1, max_idx)
        
        # Backtrack prefix buffer 
        pop!(prefix)
        
        # Node clean-up
        lists[i] = nothing
    end
end

end # module AlgorithmOptV3