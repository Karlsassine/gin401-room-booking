import { useEffect, useState } from 'react'
import { api, toDateText } from '../api.js'

const emptyRoom = { roomId: null, roomName: '', roomType: 'Study', capacity: 4 }
const emptyUser = { fullName: '', email: '', password: '', role: 'Student' }

function firstOfMonth() {
  const d = new Date()
  return toDateText(new Date(d.getFullYear(), d.getMonth() - 1, 1))
}

export default function Admin() {
  const [rooms, setRooms] = useState([])
  const [room, setRoom] = useState(emptyRoom)
  const [unit, setUnit] = useState({ equipmentName: '', serialNumber: '' })
  const [newUser, setNewUser] = useState(emptyUser)
  const [from, setFrom] = useState(firstOfMonth())
  const [to, setTo] = useState(toDateText(new Date()))
  const [report, setReport] = useState(null)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  async function loadRooms() {
    setRooms(await api('/rooms'))
  }
  useEffect(() => { loadRooms().catch(err => setError(err.message)) }, [])

  // Runs an action and shows its success or error message
  async function run(action, successText) {
    setError('')
    setMessage('')
    try {
      await action()
      setMessage(successText)
    } catch (err) {
      setError(err.message)
    }
  }

  function saveRoom(e) {
    e.preventDefault()
    run(async () => {
      await api('/admin/rooms', { method: 'POST', body: { ...room, capacity: Number(room.capacity) } })
      setRoom(emptyRoom)
      await loadRooms()
    }, 'Room saved.')
  }

  function addUnit(e) {
    e.preventDefault()
    run(async () => {
      await api('/admin/equipment', { method: 'POST', body: unit })
      setUnit({ equipmentName: unit.equipmentName, serialNumber: '' })
    }, 'Equipment unit added.')
  }

  function createUser(e) {
    e.preventDefault()
    run(async () => {
      await api('/admin/users', { method: 'POST', body: newUser })
      setNewUser(emptyUser)
    }, 'Account created.')
  }

  function loadReport(e) {
    e.preventDefault()
    run(async () => setReport(await api(`/admin/report?from=${from}&to=${to}`)), 'Report loaded.')
  }

  return (
    <div>
      <h2>Admin</h2>
      {message && <p className="success">{message}</p>}
      {error && <p className="error">{error}</p>}

      <div className="grid">
        {/* ---------- Rooms ---------- */}
        <section className="card">
          <h3>{room.roomId ? `Edit room ${room.roomName}` : 'Add a room'}</h3>
          <form onSubmit={saveRoom}>
            <label>Name
              <input value={room.roomName} onChange={e => setRoom({ ...room, roomName: e.target.value })} required />
            </label>
            <label>Type
              <select value={room.roomType} onChange={e => setRoom({ ...room, roomType: e.target.value })}>
                <option>Study</option>
                <option>Lab</option>
              </select>
            </label>
            <label>Capacity
              <input type="number" min="1" value={room.capacity} onChange={e => setRoom({ ...room, capacity: e.target.value })} />
            </label>
            <button type="submit">Save</button>
            {room.roomId && <button type="button" className="link" onClick={() => setRoom(emptyRoom)}>Cancel edit</button>}
          </form>

          <table>
            <thead><tr><th>Room</th><th>Type</th><th>Capacity</th><th></th></tr></thead>
            <tbody>
              {rooms.map(r => (
                <tr key={r.RoomID}>
                  <td>{r.RoomName}</td><td>{r.RoomType}</td><td>{r.Capacity}</td>
                  <td>
                    <button className="link" onClick={() =>
                      setRoom({ roomId: r.RoomID, roomName: r.RoomName, roomType: r.RoomType, capacity: r.Capacity })}>
                      Edit
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>

        <div>
          {/* ---------- Equipment ---------- */}
          <section className="card">
            <h3>Add an equipment unit</h3>
            <form onSubmit={addUnit}>
              <label>Equipment type (new or existing)
                <input value={unit.equipmentName} placeholder="e.g. Laptop"
                       onChange={e => setUnit({ ...unit, equipmentName: e.target.value })} required />
              </label>
              <label>Serial number
                <input value={unit.serialNumber} placeholder="e.g. LAP-11"
                       onChange={e => setUnit({ ...unit, serialNumber: e.target.value })} required />
              </label>
              <button type="submit">Add unit</button>
            </form>
          </section>

          {/* ---------- Users ---------- */}
          <section className="card">
            <h3>Create an account</h3>
            <form onSubmit={createUser}>
              <label>Full name
                <input value={newUser.fullName} onChange={e => setNewUser({ ...newUser, fullName: e.target.value })} required />
              </label>
              <label>E-mail
                <input type="email" value={newUser.email} onChange={e => setNewUser({ ...newUser, email: e.target.value })} required />
              </label>
              <label>Password (min 8 characters)
                <input type="password" value={newUser.password} onChange={e => setNewUser({ ...newUser, password: e.target.value })} required />
              </label>
              <label>Role
                <select value={newUser.role} onChange={e => setNewUser({ ...newUser, role: e.target.value })}>
                  <option>Student</option>
                  <option>Faculty</option>
                  <option>Admin</option>
                </select>
              </label>
              <button type="submit">Create</button>
            </form>
          </section>
        </div>
      </div>

      {/* ---------- Report ---------- */}
      <section className="card">
        <h3>Bookings per room</h3>
        <form className="row" onSubmit={loadReport}>
          <label>From <input type="date" value={from} onChange={e => setFrom(e.target.value)} /></label>
          <label>To <input type="date" value={to} onChange={e => setTo(e.target.value)} /></label>
          <button type="submit">Show report</button>
        </form>
        {report && (
          <table>
            <thead><tr><th>Room</th><th>Type</th><th>Bookings</th></tr></thead>
            <tbody>
              {report.map(r => (
                <tr key={r.RoomID}><td>{r.RoomName}</td><td>{r.RoomType}</td><td>{r.TotalBookings}</td></tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  )
}
