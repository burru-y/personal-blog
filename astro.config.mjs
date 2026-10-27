import { defineConfig } from "astro/config";

// 独立端口部署：http://47.111.71.156:8081/
// 不挂在主站 /blog 下——个人博客有自己的地址，不与团队站互相牵连。
export default defineConfig({
  site: "http://47.111.71.156",
  base: "/",
  trailingSlash: "ignore",
  build: {
    // 静态资源也带上前缀，避免和主站 /_astro/ 冲突
    assets: "_assets",
  },
  markdown: {
    shikiConfig: {
      // 代码高亮用双主题，跟随系统的深色/浅色
      themes: { light: "github-light", dark: "github-dark" },
      wrap: false,
    },
  },
});
