import type { Metadata } from "next";
import { Manrope, Newsreader } from "next/font/google";
import "./globals.css";

const productionUrl = "https://voice.getreadyjob.com";

const manrope = Manrope({
  variable: "--font-manrope",
  subsets: ["latin"],
});

const newsreader = Newsreader({
  variable: "--font-newsreader",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL || productionUrl),
  title: {
    default: "AI Voice Tools, Mock Interview & Translator | Voice Shop by GetReadyJob",
    template: "%s | Voice Shop - GetReadyJob",
  },
  description: "Practice AI mock interviews, explore real-time voice translation, get study support, and build ATS-friendly resumes. Wallet rates from ₹5/min and flexible passes from ₹99.",
  keywords: [
    "AI Mock Interview Online",
    "Best AI Voice Translator Real Time",
    "AI Study Assistant Voice",
    "ATS Resume Builder AI",
    "Practice Job Interview with AI Bot",
    "AI voice tools India",
    "घर बैठे ऑनलाइन इंटरव्यू प्रैक्टिस AI",
    "AI voice translator Hindi to English",
    "AI job interview tool in Hindi",
    "Affordable AI Voice Agent India",
    "Conversational AI Voice Tools",
  ],
  authors: [{ name: "GetReadyJob India", url: "https://getreadyjob.com" }],
  creator: "GetReadyJob",
  publisher: "GetReadyJob India",
  category: "AI voice and career tools",
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
  alternates: {
    canonical: productionUrl,
  },
  openGraph: {
    title: "AI Voice & Career Tools - Mock Interviews and Voice Translation",
    description: "Practice AI mock interviews, explore voice translation, get study support, and build ATS-friendly resumes with flexible INR pricing.",
    url: productionUrl,
    siteName: "GETREADYJOB Voice Shop",
    images: [{
      url: `${productionUrl}/og-voice-shop.png`,
      width: 1200,
      height: 630,
      alt: "GetReadyJob AI Voice and Career Tools showcase",
    }],
    locale: "en_IN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Experience Next-Gen AI Voice & Career Tools",
    description: "AI mock interviews, voice translation, study support and ATS resume tools with flexible INR pricing.",
    images: [`${productionUrl}/og-voice-shop.png`],
  },
};

const structuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      "@id": `${productionUrl}/#software`,
      name: "GETREADYJOB Voice Shop & AI Career Tools",
      url: productionUrl,
      operatingSystem: "Any web browser",
      applicationCategory: "BusinessApplication",
      applicationSubCategory: "Educational and career development software",
      description: "AI voice and career workspace for mock interview practice, voice translation, study support and ATS-friendly resume tools.",
      image: `${productionUrl}/og-voice-shop.png`,
      brand: {
        "@type": "Brand",
        name: "GetReadyJob",
      },
      offers: {
        "@type": "AggregateOffer",
        priceCurrency: "INR",
        lowPrice: "99",
        highPrice: "37499",
        offerCount: "8",
        offers: [
          { "@type": "Offer", name: "Personal 1-Day Pass", price: "99", priceCurrency: "INR", availability: "https://schema.org/InStock" },
          { "@type": "Offer", name: "Personal 7-Day Pass", price: "499", priceCurrency: "INR", availability: "https://schema.org/InStock" },
          { "@type": "Offer", name: "Business 1-Day Pass", price: "249", priceCurrency: "INR", availability: "https://schema.org/InStock" },
          { "@type": "Offer", name: "Business 7-Day Pass", price: "1249", priceCurrency: "INR", availability: "https://schema.org/InStock" },
        ],
      },
    },
    {
      "@type": "FAQPage",
      "@id": `${productionUrl}/#faq`,
      mainEntity: [
        {
          "@type": "Question",
          name: "How does the AI Mock Interviewer help me practise?",
          acceptedAnswer: { "@type": "Answer", text: "The Voice Shop mock interview workspace presents realistic interview practice and is designed to help users improve confidence, communication and career preparation." },
        },
        {
          "@type": "Question",
          name: "Can I use Voice Shop without a monthly subscription?",
          acceptedAnswer: { "@type": "Answer", text: "Yes. Voice Shop offers pay-as-you-go wallet rates and fixed 1-Day, 7-Day, 30-Day and 1-Year passes without requiring a monthly subscription." },
        },
        {
          "@type": "Question",
          name: "Is there a free trial available?",
          acceptedAnswer: { "@type": "Answer", text: "When the trial program is enabled, a signed-in account can claim one 2-minute Voice Shop trial, subject to the global trial allocation." },
        },
      ],
    },
  ],
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${manrope.variable} ${newsreader.variable}`}
    >
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(c,l,a,r,i,t,y){
              c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};
              t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;
              y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);
            })(window, document, "clarity", "script", "xrbk0aa08z");`,
          }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData).replace(/</g, "\\u003c") }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
