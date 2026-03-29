# PHÂN CÔNG NHIỆM VỤ ĐỒ ÁN 2 - KHAI THÁC TẬP PHỔ BIẾN (FIM)

**Môn học:** Khai thác dữ liệu và ứng dụng (CSC14004)

**Nhóm:** 4 thành viên

**Thuật toán đã chọn:** Relim

---

## PHÂN CÔNG CHI TIẾT

### THÀNH VIÊN 1 (TV1): Lead Lý thuyết & Ví dụ tay (Trọng số ~40% điểm Report)
*Yêu cầu: Cẩn thận, trình bày logic, giỏi Toán/LaTeX, vẽ hình đẹp.*

**Nhiệm vụ:**
- [ ] **Chương 1 (Nền tảng lý thuyết):** 
  - Gõ các định nghĩa hình thức (CSDL, Support, FIM, Tập đóng/tối đại).
  - Chứng minh tính chất Apriori (Downward Closure).
  - Viết Giả mã (Pseudocode) thuật toán, giải thích cấu trúc dữ liệu.
  - Phân tích độ phức tạp (Thời gian, Không gian) & Lịch sử thuật toán.
- [ ] **Chương 2 (Ví dụ minh họa tay):**
  - Tự tạo 1 CSDL đồ chơi (5-7 giao dịch, 5-6 item) và chọn minsup.
  - Vẽ tay/Kẻ bảng toàn bộ các bước chạy thuật toán (Step-by-step).
  - Liệt kê tập kết quả và kiểm tra chéo (Cross-check).
  - Thiết kế 1 "Tình huống đặc biệt" (Ví dụ 2) và giải thích cách thuật toán xử lý.

### THÀNH VIÊN 2 (TV2): Lead Core Code & I/O (Trọng số ~20% điểm Code)
*Yêu cầu: Kỹ năng code tốt, hiểu sâu cấu trúc dữ liệu (Cây, Đồ thị, Bitset...)*

**Nhiệm vụ:**
- [ ] **Khởi tạo Project:** Tạo cấu trúc thư mục chuẩn theo yêu cầu của Thầy (`src/`, `algorithm/`, `structures.jl`, `Project.toml`...).
- [ ] **Level 1 (Code cơ bản):** Cài đặt đúng thuật toán gốc từ giấy ra code. Phải xuất ra đủ itemset và support tương ứng.
- [ ] **Level 4 (Đầu vào/Đầu ra):** 
  - Viết hàm đọc file `.txt` chuẩn SPMF (space-separated).
  - Viết hàm xuất file kết quả đúng chuẩn định dạng.
  - Thiết lập tham số dòng lệnh (CLI) để truyền `minsup` và `file_path`.
- [ ] **Bảo chứng:** Viết `docstring` đầy đủ cho mọi hàm và struct. Đảm bảo output khớp 100% với tool SPMF.

### THÀNH VIÊN 3 (TV3): Lead Tối ưu hóa & Testing (Trọng số ~20% điểm Code/Thực nghiệm)
*Yêu cầu: Tư duy thuật toán tốt, biết viết Unit Test và tối ưu bộ nhớ/tốc độ.*

**Nhiệm vụ:**
- [ ] **Level 2 (Tự động hóa Test):** Viết script (`test_correctness.jl`) test tự động thuật toán trên ít nhất 5 CSDL khác nhau (lấy luôn CSDL của TV1 làm test case). Đảm bảo pass 100%.
- [ ] **Level 3 (Tối ưu hóa):** 
  - Nghiên cứu áp dụng ít nhất **1 kỹ thuật tối ưu** (Ví dụ: Dùng `BitArray` trong Julia, nén cây FP-Tree, tỉa nhánh sớm...).
  - Cài đặt bản code Tối ưu song song với bản Basic của TV2.
- [ ] **Benchmark Script:** Viết script (`test_benchmark.jl`) để chạy vòng lặp đo *Thời gian chạy* và *RAM tối đa (Peak Memory)* trên 4 tập datasets chuẩn. Xuất ra file `.csv` đưa cho TV4.

### THÀNH VIÊN 4 (TV4): Lead Dữ liệu, Ứng dụng & Tổng hợp Báo cáo (Trọng số 30% điểm Report)
*Yêu cầu: Nhạy bén với số liệu, kỹ năng vẽ biểu đồ đẹp, văn phong báo cáo mượt mà.*

**Nhiệm vụ:**
- [ ] **Chương 4 (Thực nghiệm & Đánh giá):** 
  - Dữ liệu: Tải 4 tập CSDL chuẩn (Chess, Mushroom, Retail, Accidents).
  - Từ file `.csv` của TV3, vẽ biểu đồ: Thời gian chạy theo minsup, Số lượng itemset theo minsup, RAM usage, Scalability.
  - Viết nhận xét, giải thích kết quả dựa trên lý thuyết Chương 1. Đề xuất 2 hướng tối ưu tiếp.
- [ ] **Chương 5 (Ứng dụng thực tế):**
  - Chạy code thuật toán trên 1 tập data thực tế (Bán lẻ/Log/Sinh học).
  - Code thêm script nhỏ để sinh Luật kết hợp (Association Rules) từ FIM. Lọc Top-10 luật theo hệ số *Lift* và giải thích ý nghĩa kinh doanh.
- [ ] **Đóng gói Đồ án:** 
  - Gom file Word/LaTeX của TV1 + Biểu đồ ráp thành file Báo cáo PDF (Tối thiểu 15 trang, đánh caption đầy đủ).
  - Chốt file `README.md` hướng dẫn cách chạy code cụ thể.
  - Nén toàn bộ theo chuẩn `Group_ID.zip` (Restart & Run All các file notebook trước khi nộp).

---