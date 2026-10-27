# 个人博客

廖呈睿的技术笔记。基于 [Astro](https://astro.build)，构建产物是纯静态 HTML。

## 本地开发

```bash
pnpm install
pnpm dev      # http://localhost:4321
pnpm build    # 输出到 dist/
```

## 写文章

新建 `src/content/posts/<slug>.md`：

```markdown
---
title: "文章标题"
description: "一句话摘要，列表页显示"
publishedAt: 2026-10-27
tags: ["后端"]
draft: false
---

正文，支持 Markdown。
```

`draft: true` 的文章构建时会跳过。

## 发布

```bash
./deploy.ps1
```

做的事：构建 → 打包 → 上传到服务器 → 解压到 `/opt/personal-blog/dist` → 重建容器 → 验证。

## 部署结构

这个项目**独立于团队博客**，有自己的容器和端口：

```
服务器 /opt/personal-blog/
├── compose.yaml      nginx 容器，监听 8081
├── nginx.conf        静态文件服务
└── dist/             构建产物（上传进来的）
```

团队博客在另一套 compose 里（`/root/teamblog/ops/compose`），两边互不依赖。

## 目录

```
src/
├── content/posts/    文章（Markdown）
├── layouts/          Base.astro：页头页脚与 HTML 骨架
├── pages/            路由（首页、文章、归档、关于、RSS）
└── styles/global.css 全部样式，约 190 行手写 CSS
```

## 技术选择

- **Astro**：内容型站点，默认零 JS，单页约 6 KB
- **不用 Tailwind**：样式总量小，手写 CSS 更直接
- **深色模式**：跟随系统（`prefers-color-scheme`）
- **RSS**：`@astrojs/rss`，构建时生成
