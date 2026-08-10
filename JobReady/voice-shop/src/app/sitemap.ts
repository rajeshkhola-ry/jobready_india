import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: "https://voice.getreadyjob.com/",
      lastModified: new Date("2026-08-09T00:00:00.000Z"),
      changeFrequency: "daily",
      priority: 1,
    },
    {
      url: "https://voice.getreadyjob.com/terms",
      lastModified: new Date("2026-08-10T00:00:00.000Z"),
      changeFrequency: "monthly",
      priority: 0.8,
    },
    {
      url: "https://voice.getreadyjob.com/about",
      lastModified: new Date("2026-08-10T00:00:00.000Z"),
      changeFrequency: "monthly",
      priority: 0.8,
    },
    {
      url: "https://voice.getreadyjob.com/privacy",
      lastModified: new Date("2026-08-10T00:00:00.000Z"),
      changeFrequency: "monthly",
      priority: 0.8,
    },
    {
      url: "https://voice.getreadyjob.com/contact",
      lastModified: new Date("2026-08-10T00:00:00.000Z"),
      changeFrequency: "monthly",
      priority: 0.8,
    },
    {
      url: "https://voice.getreadyjob.com/refund-cancellation",
      lastModified: new Date("2026-08-10T00:00:00.000Z"),
      changeFrequency: "monthly",
      priority: 0.8,
    },
  ];
}
