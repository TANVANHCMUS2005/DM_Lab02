module Structures

export Transaction, ItemList

"""
Định danh một tập giao dịch (Transaction).
Sử dụng AbstractVector{Int} thay vì Vector{Int} tĩnh để ta có thể dùng `view` (SubArray) 
mà không phải tốn RAM và chi phí copy mảng khi cắt bỏ các phần tử đầu của tập dữ liệu.
"""
const Transaction = AbstractVector{Int}

"""
Cấu trúc đóng vai trò "danh sách liên kết" như bài báo của tác giả Christian Borgelt.
Lưu trữ thông tin cho một item:
- item: Tên (ID) của item.
- support: Bộ đếm số lượng giao dịch chứa item này.
- transactions: Danh sách các giao dịch đi theo item này.
"""
mutable struct ItemList
    item::Int
    support::Int
    transactions::Vector{Transaction}
end

# Constructor đơn giản hóa việc khởi tạo ban đầu (chỉ cần truyền ID của item)
ItemList(item::Int) = ItemList(item, 0, Vector{Transaction}())

end # module Structures
