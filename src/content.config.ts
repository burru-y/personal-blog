import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

/**
 * 文章集合：一个 Markdown 文件 = 一篇。
 *
 * 用 glob loader 而不是旧的 content 目录约定，是为了以后加 `drafts/` 之类的子目录时
 * 不用改配置。
 */
const posts = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/posts" }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    /** 发布日期，排序用 */
    publishedAt: z.coerce.date(),
    /** 标签，用于归档页分组 */
    tags: z.array(z.string()).default([]),
    /** 草稿：构建时跳过 */
    draft: z.boolean().default(false),
  }),
});

export const collections = { posts };
