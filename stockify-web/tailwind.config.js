/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        brand: "#18DAAE",
        accent: "#8532D9",
        ink: "#000000",
        cloud: "#F6F8F9",
        line: "#E7EAEE",
        muted: "#6C757D",
      },
      fontFamily: {
        sans: ["Product Sans", "Avenir Next", "Segoe UI", "sans-serif"],
      },
      boxShadow: {
        soft: "0 24px 60px rgba(12, 17, 29, 0.08)",
        panel: "0 10px 30px rgba(12, 17, 29, 0.06)",
      },
    },
  },
  plugins: [],
};
