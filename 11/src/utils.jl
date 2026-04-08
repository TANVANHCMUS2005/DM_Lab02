module Utils

export read_spmf_file, write_spmf_file

"""
    read_spmf_file(filepath::String)

Đọc file dataset theo định dạng SPMF chuẩn (mỗi giao dịch là một hàng, các item cách nhau bởi khoảng trắng).
Trả về một mảng chứa các mảng con, mỗi mảng con là một giao dịch (Vector{Vector{Int}}).
"""
function read_spmf_file(filepath::String)
    transactions = Vector{Vector{Int}}()
    
    # Mở file và đọc từng dòng
    for line in eachline(filepath)
        # Loại bỏ khoảng trắng thừa hai đầu
        line = strip(line)
        if isempty(line)
            continue
        end
        
        # Tách dòng bằng khoảng trắng, chuyển từng phần tử thành số nguyên (Int)
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
            # Quan trọng: Các item trong 1 itemset PHẢI sắp xếp số học tăng dần 
            # để đảm bảo chuỗi ký tự khớp 100% với Format của thư viện SPMF Java
            sorted_items = sort(itemset)
            
            # Nối các item bằng khoảng trắng
            item_str = join(sorted_items, " ")
            # Ghi ra file kèm chuỗi #SUP:
            println(file, "$item_str #SUP: $support")
        end
    end
end

end # module Utils
