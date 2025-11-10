/**
 * Home page component
 * Demonstrates a simple Next.js page with information about the Nix setup
 */
export default function Home() {
  return (
    <main style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '100vh',
      padding: '2rem',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      color: 'white',
    }}>
      <h1 style={{ fontSize: '3rem', marginBottom: '1rem' }}>
        Nix + Turborepo Sample
      </h1>
      <p style={{ fontSize: '1.5rem', marginBottom: '2rem', textAlign: 'center' }}>
        Web Application (Next.js)
      </p>

      <div style={{
        background: 'rgba(255,255,255,0.1)',
        borderRadius: '10px',
        padding: '2rem',
        maxWidth: '600px',
      }}>
        <h2 style={{ marginTop: 0 }}>Features:</h2>
        <ul style={{ lineHeight: '1.8' }}>
          <li>Reproducible dev environment with Nix</li>
          <li>Monorepo management with Turborepo</li>
          <li>OCI images built without Docker (using Nix)</li>
          <li>CI/CD with GitHub Actions</li>
          <li>Automatic environment loading with direnv</li>
        </ul>

        <div style={{ marginTop: '2rem', fontSize: '0.9rem', opacity: 0.8 }}>
          <p><strong>Dev:</strong> pnpm dev</p>
          <p><strong>Build:</strong> pnpm build</p>
          <p><strong>Image:</strong> nix build .#image-web</p>
        </div>
      </div>
    </main>
  )
}
