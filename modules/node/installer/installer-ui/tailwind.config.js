export default {
  content: ['./index.html', './src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      boxShadow: {
        glass: '0 24px 80px rgba(0, 0, 0, 0.45)',
      },
      colors: {
        accent: {
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
        },
      },
    },
  },
  plugins: [],
};
