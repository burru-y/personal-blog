---
title: "把一个六容器的项目塞进 2 核 2G 的服务器"
description: "从本机 Docker 到公网部署：内存怎么分配、构建为什么慢、备份怎么验证。"
publishedAt: 2026-10-26
tags: ["部署", "Docker"]
---

项目本身不大，但要跑起来需要六个容器：数据库、后端、前端、AI 服务、nginx、备份。
一开始我把它们丢在一台 2 核 2G 的轻量服务器上，第一次构建就卡了 20 分钟没结束。

这篇文章记录把它跑通的过程。

## 先看内存够不够

各服务的实际占用：

| 服务 | 内存上限 | 说明 |
|---|---|---|
| api（Spring Boot） | 640 MB | JVM 堆压到 384 MB |
| web（Next.js） | 512 MB | Node 运行时 |
| ai（Python） | 384 MB | uvicorn |
| postgres | 约 150 MB | 默认配置 |
| nginx + backup | 约 50 MB | 几乎可以忽略 |

加起来 1.2–1.5 GB，2G 内存的机器**跑得动，但没有余量给构建**。

第一次失败就发生在这里：编译时 Node 和 Maven 的峰值各接近 1 GB，两个一起跑直接把内存吃光，进程被内核杀掉，日志里只有一行 `Killed`。

### 解法是加 swap，而不是换机器

```bash
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

swap 跑在云盘上，比内存慢几百倍，**它只该用来兜底构建**。如果服务稳定运行后 swap 一直不降，说明内存是真的不够，得改配置而不是硬扛。

## 构建慢不是机器的问题

20 分钟没跑完，直觉是「配置太低」。把每一步耗时打印出来才发现问题在别处：

```
apk add tzdata curl          285 秒   ← Alpine 官方源
mvn dependency:go-offline    380 秒   ← Maven Central
拉 maven 镜像 145MB          251 秒   ← 3M 带宽已跑满
编译代码                      几十秒
```

**真正编译只占几十秒，90% 时间在等下载。** 换成国内镜像源后：

```
apk     285 秒 → 9 秒
Maven   380 秒 → 200 秒
```

而且构建要**逐个服务做**，不能并行：

```bash
docker compose build api
docker compose build web
docker compose build ai
```

并行构建会让两个编译进程同时抢内存，回到上面那个 `Killed`。

## 数据迁移：报错不一定代表数据坏了

从本机导出数据库，传到服务器恢复，刷了 15 行红字：

```
ERROR: role "ai_reader" does not exist
Command was: GRANT SELECT ON TABLE public.users TO ai_reader;
```

看起来像数据全废了。仔细看报错内容是 `GRANT` 语句，也就是**权限授予失败，数据本身没问题**。

原因是这个只读角色由本地数据库初始化脚本创建，而生产的 compose 没有挂载那个脚本，新库自然没有它。

修法是把初始化脚本挂进 compose——但**只挂角色脚本，不挂测试库脚本**：

```yaml
volumes:
  - ../init/01-roles.sql:/docker-entrypoint-initdb.d/01-roles.sql:ro
```

## 备份必须验证能恢复

存了 dump 不等于有备份。我遇到过「文件存在、大小正常、恢复时才发现缺表」。

验证方法是建一个临时库，把 dump 恢复进去数行数：

```bash
psql -U blog -d postgres -c "create database blog_verify;"
pg_restore -U blog -d blog_verify /backup/2026-10-26.dump
psql -U blog -d blog_verify -c "select count(*) from users;"
psql -U blog -d postgres -c "drop database blog_verify;"
```

行数对得上，这份备份才算存在过。

更进一步，备份不能和数据库在同一台机器上：

```
应用备份    每天 03:10  →  服务器本地卷
异地备份    每天 03:30  →  OSS（保留 30 天）
```

## 一个部署细节：容器重建后 nginx 指向旧 IP

部署后页面 502，但 `docker ps` 显示 api 是 healthy。

原因是 **nginx 启动时解析并缓存了 upstream 的地址**，api 容器重建后 IP 变了，nginx 还在往旧 IP 转发。

所以部署脚本最后一定要重启 nginx：

```bash
docker compose restart nginx
```

这类问题最费时间的地方在于：所有容器都显示正常，只有页面打不开。

## 现在的结果

```
首页 gzip 后约 88 KB
6 个容器全部 healthy
构建：首次 15 分钟，改前端后 2 分钟
```

回头看，整个过程真正难的不是配置，而是**在错误的方向上排查**：
以为内存不够去加 swap（其实够）、以为数据坏了去重新导库（其实没坏）、以为服务挂了去看日志（其实是 nginx 缓存）。

先量一量，比先改配置有用。
