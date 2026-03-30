# Tài liệu Tổng hợp Cấu trúc Thuật toán Relim Tối ưu (Level 3+)
**Phiên bản:** `AlgorithmOptV3`
**File:** `src/algorithm/relim_opt.jl`
**Thực hiện:** TV3 (Tối ưu hóa Hiệu năng & Bộ nhớ)

---

## 1. Tổng quan về bản tối ưu (Relim Opt V3)
Thuật toán Relim (Recursive Elimination) thuộc họ thuật toán giao nhau - khai phá tập phổ biến. Dù Relim là một cách tiếp cận thanh lịch, việc thao tác với các danh sách liên kết trên các "hậu tố" (suffixes) ở từng cấp có thể gây ra hiện tượng "*rác bộ nhớ*" (Garbage/Memory Overhead) lớn ở ngôn ngữ kịch bản nếu không được quản lý tốt. 

Bản cài đặt `relim_opt_v3` được thiết kế nhằm giải quyết bài toán cốt lõi đó thông qua 3 yếu tố: **Index thay vì Mapping (đối với Cấu trúc lá)**, **Tránh cấp phát động bằng bộ đệm (Prefix Buffer)**, và **Dọn dẹp cực đoan (Node Clean-up)**.

---

## 2. Các pha xử lý chi tiết (Phases of Execution)

### Pha 1: Tiền xử lý (Preprocessing)
1. **Quét và lọc:** Quét toàn bộ CSDL một lần đầu tiên để xác định tần suất (support) của tất cả item thông qua một `Dict{Int, Int}`. 
   - *Tối ưu:* `sizehint!` được chỉ định để giới hạn tần suất cấp phát lại bảng băm bên dưới Dict.
2. **Loại bỏ & Sắp xếp:** Mọi item không đạt `minsup` lập tức bị khai trừ. Mảng valid được sắp xếp **TĂNG DẦN** theo tần suất xuất hiện.
   - *Nguyên lý Relim:* Việc xét item có tần suất thấp nhất trước tiên đảm bảo cây tìm kiếm không phân nhánh quá sâu sớm.
3. **Từ điển Rank (Mã hóa):** Chuyển tất cả item gốc thành `rank` (0, 1, 2...N). Việc thay một ID xa lạ bằng các số integer tuyến tính liên tiếp cho phép thuật toán sử dụng Mảng thông thường `[ ]` thay vì Bảng Băm `Dict` để tra cứu cực nhanh (O(1)).
4. **Cắt mảng dư:** Những Transaction rỗng sau khi loại bỏ item sẽ bị vứt đi. Các Transaction còn lại được nén vào mảng mới.

### Pha 2: Cấu trúc Rễ (Root Initialization)
- Sử dụng siêu kiểu (Union Type): `Vector{Union{Nothing, ItemList}}(nothing, N + 1)`
- **Tại sao lại ưu việt?** Ở phiên bản cũ (Level 1), một mảng `ItemList` gồm mọi Item (`[ItemList(j) for j in 1:N]`) luôn được khởi tạo bất kể chúng có giao dịch (Transactions) bên trong hay không gây lãng phí, còn `Dict` lại làm tốn CPU vì phải băm key (O(1) trên lý thuyết nhưng Overhead thực tế cao).
- Việc dùng mảng `Nothing` thay thế cho `Dict` giúp ta có tốc độ của Mảng tĩnh (chỉ dùng Index), nhưng lại tối ưu hoá bộ nhớ 100% của cấu trúc thưa (Sparse Array).

### Pha 3: Khai phá Đệ quy (Recursive Mining)
Pha này được tinh chỉnh để giảm thiểu việc Copy Array – nguyên nhân chính gây chậm khi đào sâu nhánh (Depth).

- **Prefix Buffer:** Thay vì `copy(prefix)` mỗi khi đệ quy, ta truyền theo một vùng nhớ đệm `prefix_buffer = Int[]` duy nhất cho toàn bộ quá trình đệ quy.
  - Khi đào sâu (Descend): Gọi hàm `push!(prefix, ...)`
  - Khi hoàn thành nhánh (Backtrack): Gọi hàm `pop!(prefix)` để phục hồi trạng thái cho nhánh cha.
- **Tái phân mảnh cho Cấp Hiện Tại (Sibling Reassignment):** Giao dịch được tách đuôi (hậu tố) để tiếp tục duy trì cho những Item chưa xét ở cùng cấp độ. 
- **Hình chiếu cho Cấp Con (Child Projection):** Thu thập các giao dịch hậu tố chuyển xuống cấp độ đệ quy con.

---

## 3. Hoán đổi & Tỉa cành Thông minh (Perfect Extension Pruning - Khái niệm tĩnh)
Code có đề cập logic **PEP (Perfect Extension Pruning)**. Ý tưởng gốc của PEP là nhận diện các phần tử (Items) đi kèm với tần suất đạt mức tuyệt đối (100% so với tổ tiên). Tuy nhiên hàm code V3 của bạn đã tự động cấy Heuristic tối giản:

**Cơ chế Nhảy tắt Thưa (Sparse Bypass):** 
```julia
if current_list === nothing || current_list.support < minsup
    ... (Tự dọn dẹp và Continue vòng For)
```
Thay vì tạo ra mốc Đệ quy (Gọi hàm) rồi mới báo rỗng, thuật toán chủ động quét, dồn rác về các node Sibling khác, chặn triệt để cuộc gọi Hàm đệ quy con. Điều này ngăn cho ngăn xếp (Call Stack) của Julia bị quá tải (Stack Overflow).

---

## 4. Dọn Rác Sớm Cuối Node (Node Clean-up)
Tại phần cuối của hàm đệ quy:
```julia
lists[i] = nothing
```
Đây là bước cực tinh tế. Julia dùng Grabage Collector (Bộ dọn rác cơ chế Tự động). Khi một Node trên nhánh đệ quy hiện tại (ví dụ đã xét xong Item ID 1) không còn cần thiết, thay vì chờ rễ cha kết thúc tiến trình, ta huỷ liên kết tham chiếu (`= nothing`). Nhờ đó GC của Julia lập tức thu hồi mảng CSDL thuộc List đó ngay lập tức lúc thuật toán duyệt sang Item ID 2. Không bao giờ xảy ra bùng nổ RAM Peak!

---

## 5. Đánh giá Big-O của Relim Opt V3
- **Độ phức tạp Thời Gian (Time):** `O(M * 2^K)` với M là số Giao dịch cuối cùng, và K là số item trung bình. Việc tránh hàm Copy Array và dùng O(1) Vector Index giúp hằng số thời gian được bóp tới giới hạn.
- **Độ phức tạp Không Gian (Space):** `O(N_Active_Nodes)` tại bất kỳ thời điểm thay vì `O(V * Depth)`. Với cơ chế Cleanup và Union Sparse Memory, tiêu chuẩn bộ nhớ RAM đã xuống cực thấp.

## Tổng Kết
Code của bạn (`src/algorithm/relim_opt.jl` - V3) hoàn toàn đạt chuẩn trình độ Cấp 3/4 của Đồ án Môn Khai thác dữ liệu. Có thể ghi điểm xuất sắc ở kỹ thuật kiểm soát luồng đệm tự thủ công (`Prefix Buffer`), tận dụng triệt để DataType linh hoạt trong thế giới tĩnh của Julia!
