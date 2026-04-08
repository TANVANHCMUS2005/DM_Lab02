module Utils

export read_spmf_file, write_spmf_file, read_spmf_output

"""
    read_spmf_file(filepath::String)

Đọc file dataset theo định dạng SPMF chuẩn (mỗi giao dịch là một hàng, các item cách nhau bởi khoảng trắng).
Trả về một mảng chứa các mảng con, mỗi mảng con là một giao dịch (Vector{Vector{Int}}).
"""
function read_spmf_file(filepath::String)
    transactions = Vector{Vector{Int}}()
    
    for line in eachline(filepath)
        line = strip(line)
        if isempty(line)
            continue
        end
        
        items = parse.(Int, split(line))
        push!(transactions, items)
    end
    
    return transactions
end

"""
    write_spmf_file(filepath::String, itemsets::Vector{Tuple{Vector{Int}, Int}})

Xuất kết quả Frequent Itemsets ra file theo định dạng SPMF:
[item1] [item2] ... #SUP: [support]
"""
function write_spmf_file(filepath::String, itemsets::Vector{Tuple{Vector{Int}, Int}})
    open(filepath, "w") do file
        for (itemset, support) in itemsets
            sorted_items = sort(itemset)
            item_str = join(sorted_items, " ")
            println(file, "$item_str #SUP: $support")
        end
    end
end

"""
    read_spmf_output(filepath::String)

Đọc file KẾT QUẢ từ SPMF (định dạng: "item1 item2 ... #SUP: support").
Trả về Vector{Tuple{Vector{Int}, Int}} — danh sách (itemset, support).
Dùng để so sánh output của nhóm với SPMF reference.
"""
function read_spmf_output(filepath::String)
    itemsets = Vector{Tuple{Vector{Int}, Int}}()
    
    for line in eachline(filepath)
        line = strip(line)
        isempty(line) && continue
        
        parts = split(line, "#SUP:")
        length(parts) != 2 && continue
        
        items = sort(parse.(Int, split(strip(parts[1]))))
        support = parse(Int, strip(parts[2]))
        push!(itemsets, (items, support))
    end
    
    return itemsets
end

end # module Utils
