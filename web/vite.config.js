import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Every call to /api is forwarded to the C# API on port 5000.
// So React never needs to know where the API is, and there is no CORS problem.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:5000'
    }
  }
})
