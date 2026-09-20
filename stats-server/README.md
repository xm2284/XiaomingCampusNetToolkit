# 「小明」工具箱 · 匿名统计服务端

Flask + SQLite + matplotlib 的单文件统计后端，Docker 一键部署。接收工具箱的匿名上报，
生成可直接放进 README 的统计图片。

## 收集的数据（全部匿名、可在客户端关闭）

| 字段 | 示例 | 用途 |
|---|---|---|
| tool_version | 0.1.0 | 版本分布 |
| os / build | Windows 11 / 26200 | 系统兼容性 |
| vendor / adapter_type | Intel / wireless | 网卡厂商适配优先级 |
| mode | campus / gaming / proxy_clean | 哪个功能最常用 |
| success / opt_count | 1 / 7 | 优化成功率 |
| latency_before/after、loss_before/after | 23.4 / 15.2 | 延迟改善效果 |
| install_id | 随机 GUID | 粗略去重，**非硬件指纹**，卸载即失效 |

**数据库不记录** IP、主机名、MAC、账号、地理位置。

## 接口

- `POST /api/report`        上报（JSON）
- `GET  /health`            健康检查
- `GET  /api/stats`         聚合统计 JSON
- `GET  /chart?type=usage`  统计图片，type ∈ `usage` / `vendor` / `os` / `mode` / `latency`
- `GET  /`                  看板页面

> README 引用图片：`![](https://你的域名或IP/chart?type=usage)`，加 `&t=1` 之类参数可绕过缓存取最新。

## 一键部署（服务器已装 Docker）

```bash
# 1. 上传整个 stats-server 目录到服务器，例如 /opt/xm-stats
#    （或 git clone 后进入 stats-server 目录）
cd /opt/xm-stats

# 2. 构建并后台启动
docker compose up -d --build

# 3. 查看状态 / 日志
docker compose ps
docker compose logs -f
```

启动后服务监听容器内 8080，compose 默认映射到宿主机 **80** 端口：
- 看板：`http://服务器IP/`
- 图片：`http://服务器IP/chart?type=usage`

> 若宿主机 80 端口被占用，把 `docker-compose.yml` 的 `"80:8080"` 改成 `"8080:8080"`，
> 并在云防火墙放行 8080。

### 阿里云轻量应用服务器防火墙

轻量服务器需在控制台单独放行端口（不是 ECS 安全组）：

1. 进入 轻量应用服务器控制台 → 实例详情 → **防火墙** 标签
2. 添加规则：应用类型自定义，协议 TCP，端口 `80`（或你改的端口）
3. 80/443/22/ICMP 通常默认已放行

## 更新代码后重新部署

```bash
cd /opt/xm-stats
docker compose up -d --build
```

## 数据备份

数据库就是挂载出来的单文件 `./data/stats.db`，备份它即可：

```bash
cp ./data/stats.db  stats-backup-$(date +%F).db
```

## 卸载

```bash
docker compose down            # 停止并删除容器
rm -rf ./data                  # （可选）删除统计数据
```

## 本地非 Docker 运行（调试用）

```bash
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python app.py
```
