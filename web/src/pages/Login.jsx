import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, saveUser } from '../api.js'

export default function Login({ onLogin }) {
  const [email, setEmail] = useState('karl@uni.edu')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const navigate = useNavigate()

  async function handleSubmit(e) {
    e.preventDefault()
    setError('')
    try {
      const user = await api('/auth/login', { method: 'POST', body: { email, password } })
      saveUser(user)
      onLogin(user)
      navigate('/')
    } catch (err) {
      setError(err.message)
    }
  }

  return (
    <div className="login">
      <h1>Campus Room Booking</h1>
      <form className="card" onSubmit={handleSubmit}>
        <label>E-mail
          <input type="email" value={email} onChange={e => setEmail(e.target.value)} required />
        </label>
        <label>Password
          <input type="password" value={password} onChange={e => setPassword(e.target.value)} required />
        </label>
        {error && <p className="error">{error}</p>}
        <button type="submit">Log in</button>
        <p className="hint">Demo: admin@uni.edu, bruno@uni.edu, karl@uni.edu — password Password123!</p>
      </form>
    </div>
  )
}
