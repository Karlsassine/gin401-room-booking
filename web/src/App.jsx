import { useState } from 'react'
import { Routes, Route, NavLink, Navigate, useNavigate } from 'react-router-dom'
import { getUser, logout } from './api.js'
import Login from './pages/Login.jsx'
import FindRoom from './pages/FindRoom.jsx'
import MyBookings from './pages/MyBookings.jsx'
import Admin from './pages/Admin.jsx'

export default function App() {
  const [user, setUser] = useState(getUser())
  const navigate = useNavigate()

  function handleLogout() {
    logout()
    setUser(null)
    navigate('/login')
  }

  // Not logged in: only the login page
  if (!user) {
    return (
      <Routes>
        <Route path="*" element={<Login onLogin={setUser} />} />
      </Routes>
    )
  }

  return (
    <>
      <header className="topbar">
        <span className="brand">Campus Room Booking</span>
        <nav>
          <NavLink to="/" end>Find a room</NavLink>
          <NavLink to="/my">My bookings</NavLink>
          {user.role === 'Admin' && <NavLink to="/admin">Admin</NavLink>}
        </nav>
        <span className="who">
          {user.fullName} ({user.role})
          <button className="link" onClick={handleLogout}>Log out</button>
        </span>
      </header>

      <main>
        <Routes>
          <Route path="/" element={<FindRoom user={user} />} />
          <Route path="/my" element={<MyBookings />} />
          {user.role === 'Admin' && <Route path="/admin" element={<Admin />} />}
          <Route path="*" element={<Navigate to="/" />} />
        </Routes>
      </main>
    </>
  )
}
