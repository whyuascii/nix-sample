/** @type {import('next').NextConfig} */
const nextConfig = {
  // Enable React strict mode for better development experience
  reactStrictMode: true,

  // Configure output for standalone deployment (useful for OCI images)
  // Uncomment this for smaller production images:
  // output: 'standalone',

  // Transpile packages from the monorepo
  transpilePackages: ['ui'],
}

module.exports = nextConfig
