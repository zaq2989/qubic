/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async rewrites() {
    return [
      {
        source: '/api/relay/:path*',
        destination: process.env.RELAY_API_URL || 'http://localhost:8080/api/:path*',
      },
    ];
  },
};

module.exports = nextConfig;