# Chuyển quy trình và memory của Claude Code sang máy khác

Repo này giúp mang toàn bộ cấu hình Claude Code từ máy chính sang máy khác (hoặc lên phiên cloud),
để máy mới làm việc giống hệt máy cũ.

## Những gì được chuyển

| Trên máy chính                                   | Nội dung                                    |
|--------------------------------------------------|---------------------------------------------|
| `~/.claude/CLAUDE.md`                            | Memory chung (quy tắc, thói quen làm việc)  |
| `~/.claude/projects/<dự án>/memory/`             | Auto memory của từng dự án                  |
| `~/.claude/skills/`, `commands/`, `agents/`      | Quy trình: skill, lệnh `/...`, subagent     |
| `~/.claude/settings.json`, `keybindings.json`    | Quyền, hook, phím tắt, plugin đang bật      |
| `~/.claude.json` → `mcpServers`                  | Các MCP server                              |

**Không** chuyển: thông tin đăng nhập, lịch sử chat, cache. Ở máy mới bạn đăng nhập lại Claude Code.

Trên Windows, `~` là `C:\Users\<tên bạn>`.

---

## Cách 1: Một file nén, copy tay sang máy kia (khuyên dùng)

### Bước 1. Tải script về máy chính

1. Mở https://github.com/ngoichson-droid/projects/tree/claude/affectionate-lovelace-3a6a46
2. Bấm nút xanh **Code** → **Download ZIP**.
3. Giải nén. Bạn sẽ có thư mục chứa `scripts\`.

> Đừng tải từng file bằng cách bấm chuột phải "Save as" trên trang GitHub: bạn sẽ nhận file HTML chứ không phải script.

### Bước 2. Tạo file nén trên máy chính

**Windows:**

1. Mở thư mục `scripts` trong File Explorer.
2. Bấm vào thanh địa chỉ, gõ `powershell`, Enter. Cửa sổ PowerShell mở sẵn ở đúng thư mục.
3. Chạy:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\claude-export.ps1
   ```
4. Dòng cuối in ra `Created: ...\claude-backup-<ngày-giờ>.tar.gz`. Đó là file cần mang đi.

**macOS / Linux** (mở Terminal trong thư mục `scripts`):
```bash
bash claude-export.sh
```

Script sẽ liệt kê các file có thể chứa API key/token. Hãy giữ file nén ở chỗ riêng tư,
không gửi qua kênh công khai, không đưa lên git.

### Bước 3. Mang sang máy mới

Copy **file nén** và **thư mục `scripts`** sang máy mới (USB, Google Drive, ...).
Đặt file nén **vào cùng thư mục `scripts`**.

### Bước 4. Cài Claude Code trên máy mới

Cài và đăng nhập Claude Code một lần, rồi **thoát** Claude Code trước khi chạy bước 5.

### Bước 5. Cài đặt cấu hình trên máy mới

**Windows** (mở PowerShell trong thư mục `scripts` như ở bước 2):
```powershell
powershell -ExecutionPolicy Bypass -File .\claude-import.ps1
```
Không cần gõ tên file nén: script tự lấy file `claude-backup-*` mới nhất trong thư mục.

**macOS / Linux:**
```bash
bash claude-import.sh claude-backup-*.tar.gz
```

Trước khi ghi đè, script sao lưu cấu hình cũ thành `.claude.bak-<ngày-giờ>` và `.claude.json.bak-<ngày-giờ>`.

### Bước 6. Kiểm tra

1. Mở lại Claude Code.
2. Gõ `/memory` để xem memory đã có chưa.
3. Gõ `/` để xem các lệnh và skill của bạn.
4. Chạy `claude mcp list` để kiểm tra MCP server.

### Bước 7. Việc có thể phải làm tay

- **Auto memory theo đường dẫn dự án.** Memory được lưu trong thư mục mang tên đường dẫn dự án,
  ví dụ `C:\Users\son\app` → `C--Users-son-app`, `/Users/son/app` → `-Users-son-app`.
  Nếu dự án ở máy mới nằm chỗ khác, đổi tên thư mục tương ứng trong `~/.claude/projects/`.
- **MCP server trên Windows.** Server chạy bằng `npx` có thể cần đổi lệnh thành `cmd /c npx ...`.
- **Hook gọi script bash.** Trên Windows cần cài Git Bash, hoặc viết lại hook.
- **API key.** Nếu bạn đã xoá key khỏi file nén, nhập lại trên máy mới.

---

## Khi PowerShell báo lỗi

| Thông báo lỗi (một phần)                                    | Cách sửa |
|-------------------------------------------------------------|----------|
| `running scripts is disabled on this system`                | Chạy đúng dạng `powershell -ExecutionPolicy Bypass -File .\tên-script.ps1`, không chạy `.\tên-script.ps1` trực tiếp. |
| `The '<' operator is reserved for future use`               | Bạn đã gõ nguyên `<ngày-giờ>`. Bỏ tên file đi (script tự tìm), hoặc gõ `.\claude-backup-` rồi bấm **Tab** để tự điền. |
| `The argument '.\claude-export.ps1' ... does not exist`     | PowerShell không đứng ở thư mục `scripts`. Gõ `cd "đường\dẫn\tới\scripts"` rồi chạy lại. Gõ `dir` để thấy file `.ps1`. |
| `Not found: C:\Users\...\.claude`                           | Máy này chưa từng chạy Claude Code, hoặc bạn đang chạy nhầm tài khoản Windows. |
| `is not digitally signed` / `cannot be loaded`              | Chạy `Unblock-File .\*.ps1` trong thư mục `scripts`, rồi chạy lại. |
| `Unexpected token` / `Missing closing '}'`                  | File script bị hỏng khi tải. Tải lại bằng **Code → Download ZIP** như ở bước 1. |
| `tar.exe failed`                                            | File nén bị hỏng khi copy. Tạo lại ở bước 2. |
| `Could not merge MCP servers`                               | Phần còn lại vẫn đã cài xong. Thêm MCP server bằng tay từ `.claude\mcp-servers.from-backup.json`. |

Lỗi khác: copy **toàn bộ** chữ đỏ PowerShell in ra và gửi cho Claude.

---

## Cách 2: Đưa cấu hình vào repo (dùng cho phiên cloud)

Phiên Claude Code trên cloud không đọc `~/.claude` của máy bạn, mà đọc cấu hình nằm **trong repo**.

1. Trên máy chính, clone repo này và chạy (macOS/Linux, hoặc Git Bash trên Windows):
   ```bash
   bash scripts/sync-claude-to-repo.sh
   ```
2. Script copy quy trình và memory vào `.claude/` của repo, rồi liệt kê file nghi chứa key. Xoá key khỏi các file đó.
3. Đổi tên `.claude/settings.from-local.json` → `.claude/settings.json`
   và `.mcp.from-local.json` → `.mcp.json` (sau khi đã xem lại).
4. Thêm dòng `@.claude/memory/auto/<tên>/MEMORY.md` vào `CLAUDE.md` để phiên cloud đọc auto memory.
5. Commit và push. Mọi phiên cloud mở repo này sẽ tự nạp cấu hình.

API key cho phiên cloud đặt trong biến môi trường của cloud environment, không đặt trong git.
