/**
 * Simple Express API demonstrating Nix-based development
 * This API provides information about the Nix + Turborepo setup
 */
import express from 'express'
import cors from 'cors'

const app = express()
const PORT = process.env.PORT || 3001

// Middleware
app.use(cors())
app.use(express.json())

// Routes

/**
 * Health check endpoint
 * Used by container orchestrators (ECS, K8s) to verify the service is running
 */
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development',
  })
})

/**
 * Root endpoint with API information
 */
app.get('/', (req, res) => {
  res.json({
    name: 'Nix + Turborepo Sample API',
    version: '1.0.0',
    description: 'API demonstrating Nix-based development and OCI image building',
    endpoints: {
      '/': 'API information',
      '/health': 'Health check',
      '/api/info': 'Detailed system information',
    },
  })
})

/**
 * System information endpoint
 * Returns details about the runtime environment
 */
app.get('/api/info', (req, res) => {
  res.json({
    node_version: process.version,
    platform: process.platform,
    arch: process.arch,
    uptime: process.uptime(),
    memory: {
      rss: `${Math.round(process.memoryUsage().rss / 1024 / 1024)}MB`,
      heapTotal: `${Math.round(process.memoryUsage().heapTotal / 1024 / 1024)}MB`,
      heapUsed: `${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)}MB`,
    },
    environment: process.env.NODE_ENV || 'development',
  })
})

// Start server
app.listen(PORT, () => {
  console.log(`
🚀 API Server running on http://localhost:${PORT}

Available endpoints:
  - GET  /           API information
  - GET  /health     Health check
  - GET  /api/info   System information

Environment: ${process.env.NODE_ENV || 'development'}
Node: ${process.version}
  `)
})

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server')
  process.exit(0)
})

process.on('SIGINT', () => {
  console.log('SIGINT signal received: closing HTTP server')
  process.exit(0)
})
