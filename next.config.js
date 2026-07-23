/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Exposes /v1/* at the same paths as /api/* so the iOS client can use
  // a versioned URL (e.g. https://your-project.vercel.app/v1/items).
  // Remove this if you prefer unversioned /api/* paths.
  async rewrites() {
    return [{ source: '/v1/:path*', destination: '/api/:path*' }];
  },
};

module.exports = nextConfig;
