import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: "https://voice.getreadyjob.com/",
      lastModified: new Date("2026-08-09T00:00:00.000Z"),
      changeFrequency: "daily",
      priority: 1,
    },
  ];
}
