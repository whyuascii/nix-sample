/**
 * Shared Button component
 * This demonstrates sharing React components across the monorepo
 * Used by web app and potentially other apps in the future
 */
import React from 'react'

interface ButtonProps {
  children: React.ReactNode
  onClick?: () => void
  variant?: 'primary' | 'secondary'
}

export function Button({ children, onClick, variant = 'primary' }: ButtonProps) {
  const styles: React.CSSProperties = {
    padding: '12px 24px',
    fontSize: '16px',
    fontWeight: 600,
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    transition: 'all 0.2s',
    backgroundColor: variant === 'primary' ? '#667eea' : '#48bb78',
    color: 'white',
  }

  return (
    <button style={styles} onClick={onClick}>
      {children}
    </button>
  )
}
