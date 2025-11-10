/**
 * Root layout component for the Next.js application
 * This wraps all pages and provides common HTML structure
 */
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Nix + Turborepo Sample - Web',
  description: 'Sample web app demonstrating Nix-based development and OCI image building',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body style={{ margin: 0, fontFamily: 'system-ui, sans-serif' }}>
        {children}
      </body>
    </html>
  )
}
