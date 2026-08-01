# cloudflare-ddns

Cloudflare 动态 DNS（DDNS）更新工具，支持 IPv4 (A) / IPv6 (AAAA) / 双栈 (Both)。

> **注意：此版本仅支持 API Token 方式认证。** Cloudflare 已宣布废弃 API Key + Email 的认证方式，请前往 [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens) 创建 API Token。

---

## 目录

- [前置条件](#前置条件)
- [安装使用](#安装使用)
  - [用法](#用法)
  - [编译](#编译)
- [获取 API Token](#获取-api-token)
- [常见问题](#常见问题)

---

## 前置条件

1. 域名托管在 Cloudflare 且 DNS 由 Cloudflare 管理
2. 创建 Cloudflare API Token（见[获取 API Token](#获取-api-token)）
3. (Go 版本) 安装 [Go](https://go.dev/dl/) ≥ 1.16 用于自行编译

---

## 获取 API Token

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 右上角头像 → **My Profile** → 左侧 **API Tokens**
3. 点击 **Create Token**
4. 选择 **Create Custom Token**（或使用「Edit zone DNS」模板）
5. 配置权限：
   - **Permissions:** Zone — DNS — **Edit**
   - **Zone Resources:** Include — Specific zone — 选择你的域名
6. 点击 **Continue to summary** → **Create Token**
7. **立即复制 Token**（离开页面后将无法再次查看）

创建的 Token 格式类似：`cfut_aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890`

---

## 安装使用

适合路由器、NAS、嵌入式设备等资源受限的环境。

### 用法

```bash
./ddns CFTOKEN api-token CFZONE_NAME example.com CFRECORD_NAME ddns.example.com CFRECORD_TYPE Both
```

参数说明：

| 参数 | 含义 | 示例值 |
|---|---|---|
| `CFTOKEN` | 固定前缀，表示下一个参数是 API Token | `CFTOKEN` |
| `api-token` | 你的 Cloudflare API Token | `cfut_aBcDe...` |
| `CFZONE_NAME` | 固定前缀，表示下一个参数是主域名 | `CFZONE_NAME` |
| `example.com` | 你的主域名（Zone） | `example.com` |
| `CFRECORD_NAME` | 固定前缀，表示下一个参数是记录名 | `CFRECORD_NAME` |
| `ddns.example.com` | 要更新的完整 DNS 记录名 | `ddns.example.com` |
| `CFRECORD_TYPE` | 固定前缀，表示下一个参数是记录类型 | `CFRECORD_TYPE` |
| `A\|AAAA\|Both` | 记录类型：仅IPv4 / 仅IPv6 / 双栈 | `Both` |

### 编译

按目标平台选择编译命令：

```bash
# amd64 (x86_64)
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o ddns -ldflags '-buildid= -s -w -extldflags "-static"' main.go

# arm64 (树莓派 3B+/4/5, 等)
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o ddns -ldflags '-buildid= -s -w -extldflags "-static"' main.go

# armv7 (树莓派 2/3, 等)
CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -o ddns -ldflags '-buildid= -s -w -extldflags "-static"' main.go

# mipsle (部分路由器)
CGO_ENABLED=0 GOOS=linux GOARCH=mipsle go build -o ddns -ldflags '-buildid= -s -w -extldflags "-static"' main.go
```

编译产出 `ddns` 单文件，可直接 scp 到目标设备运行。

### 定时任务

```bash
# 每 5 分钟更新一次，日志写入 /var/log/cf-ddns.log
*/5 * * * * /usr/local/bin/ddns CFTOKEN api-token CFZONE_NAME example.com CFRECORD_NAME ddns.example.com CFRECORD_TYPE Both >> /var/log/cf-ddns.log 2>&1
```

---

## 常见问题

**Q: 为什么移除了 API Key 支持？**
A: Cloudflare 已宣布 [弃用 API Key 方式](https://developers.cloudflare.com/fundamentals/api/get-started/keys/)，API Token 更安全（可限制权限和范围），建议尽早迁移。

**Q: API Token 需要什么权限？**
A: 只需要 Zone → DNS → **Edit** 权限，Zone Resources 限定到你的域名即可。

**Q: 怎么确认 Token 是否有效？**
```bash
curl -s -H "Authorization: Bearer api-token" "https://api.cloudflare.com/client/v4/user/tokens/verify"
```

**Q: 可以同时更新多个子域名吗？**
A: 可以。为每个子域名分别部署一条定时任务，指向不同的子域名参数即可。

**Q: 运行报 "zone not found" 怎么办？**
A: 检查 API Token 的 Zone Resources 是否包含了该域名，以及域名拼写是否正确。
