# Kafka Demo - Scripts

Thư mục này chứa các scripts để quản lý và vận hành Kafka Demo.

---

## 📁 Danh Sách Scripts

| Script | Mục đích | Môi trường |
|--------|----------|------------|
| `setup-vps.sh` | Cài đặt VPS từ đầu | VPS/Server |
| `setup-runner.sh` | Cài đặt GitHub Actions Runner | VPS/Server |
| `dev.sh` | Quản lý nhanh cho development | Local |
| `prod.sh` | Quản lý đầy đủ cho production | Production |

---

## 🔧 setup-vps.sh

Script cài đặt tự động cho VPS Ubuntu 22.04/24.04.

### Tính năng
- ✅ Kiểm tra system requirements (RAM, disk)
- ✅ Cài đặt Docker & Docker Compose
- ✅ Cấu hình system limits cho Kafka
- ✅ Cấu hình UFW firewall
- ✅ Pre-flight check trước khi cài

### Sử dụng

```bash
# Chỉ kiểm tra, không làm gì
./setup-vps.sh --check

# Cài đặt với xác nhận
./setup-vps.sh

# Cài đặt không hỏi (CI/CD)
./setup-vps.sh --yes

# Cài đặt + Deploy luôn
REPO_URL=git@github.com:user/repo.git ./setup-vps.sh --with-deploy

# Xem help
./setup-vps.sh --help
```

### Options

| Option | Mô tả |
|--------|-------|
| `--check` | Dry-run, chỉ hiện những gì sẽ làm |
| `--yes`, `-y` | Bỏ qua confirmation prompts |
| `--with-deploy` | Clone repo và start services |
| `--help`, `-h` | Hiển thị help |

### Environment Variables

| Variable | Default | Mô tả |
|----------|---------|-------|
| `PROJECT_DIR` | `~/kafka-demo` | Thư mục cài đặt project |
| `REPO_URL` | _(empty)_ | Git repository URL |

---

## 🤖 setup-runner.sh

Script cài đặt GitHub Actions Self-Hosted Runner trên VPS.

### Tính năng
- ✅ Tự động tạo user runner với đầy đủ quyền
- ✅ Tự động download và cài đặt runner
- ✅ Cấu hình runner với GitHub repository
- ✅ Cài đặt như systemd service (auto-start on boot)
- ✅ Hỗ trợ nhiều runners cho nhiều repos
- ✅ Hỗ trợ Organization runner

### Yêu cầu
- GitHub Personal Access Token với scope `repo`
- Đã chạy `setup-vps.sh` trước (cần Docker)

### Quick Start (3 bước)

```bash
# Bước 1: Tạo user runner (chạy với root)
./setup-runner.sh --setup-user

# Bước 2: Chuyển sang user runner
su - runner

# Bước 3: Clone repo và chạy setup
git clone https://github.com/YOUR_USER/YOUR_REPO.git ~/YOUR_REPO
cd ~/YOUR_REPO/demo/scripts
GITHUB_REPO_URL=https://github.com/YOUR_USER/YOUR_REPO \
GITHUB_TOKEN=ghp_xxxx \
./setup-runner.sh
```

### Options

| Option | Mô tả | Chạy với |
|--------|-------|----------|
| `--setup-user` | Tạo và cấu hình user runner | root |
| `--check` | Kiểm tra trạng thái tất cả runners | any |
| `--list` | Liệt kê tất cả runners đã cài | any |
| `--update` | Update runner lên version mới nhất | runner user |
| `--uninstall` | Gỡ cài đặt runner | runner user |
| `--help`, `-h` | Hiển thị help | any |

### Environment Variables

| Variable | Default | Mô tả |
|----------|---------|-------|
| `GITHUB_REPO_URL` | _(required)_ | URL repository hoặc organization |
| `GITHUB_TOKEN` | _(required)_ | Personal Access Token |
| `RUNNER_NAME` | `hostname-reponame` | Tên runner |
| `RUNNER_LABELS` | `self-hosted,linux,x64,vps` | Labels cho runner |
| `RUNNER_SCOPE` | `repo` | `repo` hoặc `org` |

### Cách lấy GitHub Token

1. Vào **GitHub Settings** > **Developer settings** > **Personal access tokens**
2. Click **Generate new token (classic)**
3. Chọn scope `repo` (hoặc `admin:org` cho org runner)
4. Copy token và sử dụng

### Multi-Runner (nhiều repos)

```bash
# Runner cho repo 1
GITHUB_REPO_URL=https://github.com/user/repo1 \
GITHUB_TOKEN=ghp_xxx ./setup-runner.sh

# Runner cho repo 2
GITHUB_REPO_URL=https://github.com/user/repo2 \
GITHUB_TOKEN=ghp_xxx ./setup-runner.sh

# Xem danh sách
./setup-runner.sh --list
```

### Cấu trúc thư mục

```
/home/runner/
├── demo-kafka/              # Repo clone từ git
├── actions-runners/         # Runners (tự động tạo)
│   ├── demo-kafka/          # Runner cho demo-kafka
│   ├── project-2/           # Runner cho project khác
│   └── .cache/              # Cache chung
```

### Quản lý Runner Service

```bash
# Xem trạng thái
./setup-runner.sh --check

# Hoặc trực tiếp
sudo ~/actions-runners/demo-kafka/svc.sh status

# Xem logs
journalctl -u actions.runner.* -f

# Restart runner
sudo ~/actions-runners/demo-kafka/svc.sh restart
```

---

## 🛠 dev.sh

Script quản lý nhanh cho môi trường development.

### Sử dụng

```bash
# Start tất cả services
./dev.sh start

# Stop services
./dev.sh stop

# Restart services
./dev.sh restart

# Xem logs (Ctrl+C để thoát)
./dev.sh logs

# Xem trạng thái
./dev.sh status

# Rebuild backend & frontend
./dev.sh rebuild

# Xóa tất cả data (sẽ hỏi confirm)
./dev.sh clean

# Mở Kafka CLI shell
./dev.sh kafka
```

### Commands

| Command | Mô tả |
|---------|-------|
| `start` | Start tất cả services |
| `stop` | Stop tất cả services |
| `restart` | Restart tất cả services |
| `logs` | Follow logs của tất cả services |
| `status` | Hiển thị trạng thái services |
| `rebuild` | Rebuild và restart backend/frontend |
| `clean` | Stop và xóa tất cả data volumes |
| `kafka` | Mở Kafka CLI shell trong container |

---

## 🚀 prod.sh

Script quản lý đầy đủ cho môi trường production với các tính năng an toàn.

### Service Management

```bash
# Start services với health check
./prod.sh start

# Stop services (có confirmation)
./prod.sh stop

# Restart services
./prod.sh restart

# Xem trạng thái + resource usage
./prod.sh status

# Chạy health check
./prod.sh health
```

### Logs & Monitoring

```bash
# Follow logs của tất cả services
./prod.sh logs

# Follow logs của 1 service cụ thể
./prod.sh logs backend
./prod.sh logs frontend
./prod.sh logs kafka-1

# Xem metrics nhanh
./prod.sh metrics
```

### Maintenance

```bash
# Rebuild zero-downtime (backend + frontend)
./prod.sh rebuild

# Rebuild 1 service cụ thể
./prod.sh rebuild frontend
./prod.sh rebuild backend

# Pull code mới và rebuild
./prod.sh update

# Backup data và configs
./prod.sh backup

# Restore từ backup
./prod.sh restore

# Xóa tất cả data (DANGEROUS - cần confirm 2 lần)
./prod.sh clean
```

### Tools

```bash
# Mở Kafka CLI shell
./prod.sh kafka
```

### Commands Reference

| Command | Mô tả | Confirmation |
|---------|-------|--------------|
| `start` | Start + health check + hiển thị URLs | No |
| `stop` | Stop gracefully | Yes |
| `restart` | Restart + health check | No |
| `status` | Trạng thái + CPU/RAM/Network | No |
| `health` | Health check từng service | No |
| `logs [service]` | Follow logs | No |
| `metrics` | Quick metrics summary | No |
| `rebuild [service]` | Zero-downtime rebuild | No |
| `update` | Git pull + rebuild | Yes |
| `backup` | Backup Kafka + Grafana data | No |
| `restore` | Restore từ backup | Yes |
| `clean` | Xóa tất cả data | Yes (2x) |
| `kafka` | Kafka CLI shell | No |

### Backup & Restore

**Backup** sẽ tạo folder trong `backups/` với:
- `.env` - Environment config
- `docker-compose.yml`
- `monitoring/` - Prometheus & Grafana configs
- `kafka-1-data.tar.gz`, `kafka-2-data.tar.gz`, `kafka-3-data.tar.gz`
- `grafana-data.tar.gz`
- `manifest.txt` - Thông tin backup

```bash
# Tạo backup
./prod.sh backup
# Output: backups/backup_20240122_120000/

# Restore
./prod.sh restore
# Sẽ hiện danh sách backups để chọn
```

---

## 🔍 Health Check Details

`./prod.sh health` kiểm tra:

| Service | Check Method |
|---------|--------------|
| Kafka Broker 1-3 | `kafka-broker-api-versions.sh` |
| Backend | `curl http://localhost:3000/metrics` |
| Frontend | `curl http://localhost:8080` |
| Grafana | `curl http://localhost:3001/api/health` |
| Prometheus | `curl http://localhost:9090/-/healthy` |

---

## 💡 Tips

### Xem logs realtime khi debug
```bash
# Tất cả logs
./prod.sh logs

# Chỉ backend
./prod.sh logs backend

# Chỉ Kafka broker 1
./prod.sh logs kafka-1
```

### Rebuild sau khi sửa code
```bash
# Development
./dev.sh rebuild

# Production (zero-downtime)
./prod.sh rebuild
```

### Kiểm tra trước khi deploy lên VPS mới
```bash
./setup-vps.sh --check
```

### Backup định kỳ
```bash
# Thêm vào crontab để backup hàng ngày lúc 2:00 AM
0 2 * * * /path/to/demo/scripts/prod.sh backup >> /var/log/kafka-backup.log 2>&1
```

### Quick troubleshooting
```bash
# 1. Check health
./prod.sh health

# 2. Nếu unhealthy, xem logs
./prod.sh logs

# 3. Thử restart
./prod.sh restart

# 4. Nếu vẫn lỗi, rebuild
./prod.sh rebuild
```

---

## 📋 Yêu Cầu

- **OS**: Ubuntu 22.04/24.04 LTS (hoặc Linux với Docker)
- **Docker**: 20.10+
- **Docker Compose**: v2.0+ (plugin)
- **RAM**: 4GB minimum, 8GB+ recommended
- **Disk**: 10GB+ free space

---

## 🚀 CI/CD với GitHub Actions

Project có sẵn GitHub Actions workflow tại `.github/workflows/deploy.yml`.

### Workflow Features

- ✅ Lint & Test code trước khi deploy
- ✅ Build Docker images
- ✅ Zero-downtime deployment
- ✅ Health checks sau deploy
- ✅ Hỗ trợ manual trigger với options

### Trigger

- **Automatic**: Push vào branch `main` hoặc `master` (thay đổi trong folder `demo/`)
- **Manual**: Workflow dispatch từ GitHub Actions UI

### Setup CI/CD

1. **Setup VPS**:
   ```bash
   ./setup-vps.sh --yes
   ```

2. **Cài đặt GitHub Runner**:
   ```bash
   GITHUB_REPO_URL=https://github.com/your-user/kafka \
   GITHUB_TOKEN=ghp_your_token \
   ./setup-runner.sh
   ```

3. **Verify runner** tại:
   ```
   https://github.com/your-user/kafka/settings/actions/runners
   ```

4. **(Optional) Thêm repository variables**:
   - Vào **Settings** > **Secrets and variables** > **Actions** > **Variables**
   - Thêm `PROJECT_DIR` nếu khác default (`~/kafka-demo`)
   - Thêm `APP_URL` cho environment URL

5. **Push code** - workflow sẽ tự động chạy!

### Manual Deploy

```bash
# Từ GitHub Actions UI:
# 1. Vào tab Actions
# 2. Chọn "Deploy Kafka Demo"
# 3. Click "Run workflow"
# 4. Chọn options và click "Run workflow"
```

### Workflow Jobs

| Job | Runner | Mô tả |
|-----|--------|-------|
| `lint-test` | `ubuntu-latest` | Lint & test code |
| `build` | `ubuntu-latest` | Build Docker images |
| `deploy` | `self-hosted` | Deploy lên VPS |
| `notify-failure` | `ubuntu-latest` | Notify nếu fail |

---

## 🔗 Xem Thêm

- [README.md](../README.md) - Tài liệu chính
- [ARCHITECTURE.md](../docs/ARCHITECTURE.md) - Chi tiết kiến trúc
- [.env.example](../.env.example) - Cấu hình environment
- [deploy.yml](../../.github/workflows/deploy.yml) - GitHub Actions workflow
