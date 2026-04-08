module Structures

export TransPtr, ItemList

"""
Con trỏ giao dịch (Transaction Pointer) nhằm loại bỏ chi phí sao chép vùng nhớ và giải quyết 
tình trạng Type Instability sinh ra Garbage Collection liên tục do AbstractVector.
- items: Tham chiếu tới mảng giao dịch đã lọc.
- idx: Vị trí hiện tại của phần tử đầu tiên (thay thế cho việt cắt mảng).
"""
struct TransPtr
    items::Vector{Int}
    idx::Int
end

"""
Cấu trúc đóng vai trò "danh sách liên kết" như bài báo của tác giả Christian Borgelt.
Lưu trữ thông tin cho một item:
- item: Tên (ID) của item.
- support: Bộ đếm số lượng giao dịch chứa item này.
- transactions: Danh sách các giao dịch (kiểu TransPtr) đi theo item này.
"""
mutable struct ItemList
    item::Int
    support::Int
    transactions::Vector{TransPtr}
end

# Constructor đơn giản hóa việc khởi tạo ban đầu (chỉ cần truyền ID của item)
ItemList(item::Int) = ItemList(item, 0, Vector{TransPtr}())

end # module Structures
