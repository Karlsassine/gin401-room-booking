import { useState } from 'react'
import { api, HALF_HOURS, tomorrow } from '../api.js'

export default function FindRoom({ user }) {
  const [day, setDay] = useState(tomorrow())
  const [start, setStart] = useState('10:00')
  const [end, setEnd] = useState('11:00')
  const [people, setPeople] = useState(1)

  const [rooms, setRooms] = useState(null)       // null = not searched yet
  const [equipment, setEquipment] = useState([])
  const [equipmentId, setEquipmentId] = useState('')
  const [quantity, setQuantity] = useState(1)

  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  const startTime = `${day}T${start}:00`
  const endTime = `${day}T${end}:00`

  async function search(e) {
    e?.preventDefault()
    setError('')
    try {
      const query = `start=${startTime}&end=${endTime}`
      setRooms(await api(`/rooms/free?${query}&people=${people}`))
      setEquipment(await api(`/equipment/free?${query}`))
    } catch (err) {
      setError(err.message)
    }
  }

  async function book(room) {
    setError('')
    setMessage('')
    try {
      const result = await api('/bookings', {
        method: 'POST',
        body: {
          roomId: room.RoomID,
          start: startTime,
          end: endTime,
          people: Number(people),
          equipmentId: equipmentId ? Number(equipmentId) : null,
          quantity: equipmentId ? Number(quantity) : 0
        }
      })
      setMessage(`Booked ${room.RoomName} on ${day}, ${start}–${end} (booking #${result.BookingID}).`)
      setEquipmentId('')
      search()   // refresh: the room is no longer free
    } catch (err) {
      setError(err.message)   // e.g. "This room is already booked at that time."
    }
  }

  return (
    <div>
      <h2>Find a free room</h2>

      <form className="card row" onSubmit={search}>
        <label>Date
          <input type="date" value={day} onChange={e => setDay(e.target.value)} required />
        </label>
        <label>From
          <select value={start} onChange={e => setStart(e.target.value)}>
            {HALF_HOURS.slice(0, -1).map(t => <option key={t}>{t}</option>)}
          </select>
        </label>
        <label>To
          <select value={end} onChange={e => setEnd(e.target.value)}>
            {HALF_HOURS.slice(1).map(t => <option key={t}>{t}</option>)}
          </select>
        </label>
        <label>People
          <input type="number" min="1" value={people} onChange={e => setPeople(e.target.value)} />
        </label>
        <button type="submit">Search</button>
      </form>

      {message && <p className="success">{message}</p>}
      {error && <p className="error">{error}</p>}

      {rooms && (
        <>
          <div className="card row">
            <label>Borrow equipment (optional)
              <select value={equipmentId} onChange={e => setEquipmentId(e.target.value)}>
                <option value="">None</option>
                {equipment.map(eq => (
                  <option key={eq.EquipmentID} value={eq.EquipmentID} disabled={eq.FreeUnits === 0}>
                    {eq.Name} — {eq.FreeUnits} of {eq.TotalUnits} free
                  </option>
                ))}
              </select>
            </label>
            {equipmentId && (
              <label>How many
                <input type="number" min="1" value={quantity} onChange={e => setQuantity(e.target.value)} />
              </label>
            )}
          </div>

          <h3>{rooms.length} free room(s)</h3>
          {user.role === 'Student' && <p className="hint">Students can book study rooms only. Labs are for faculty.</p>}
          <table>
            <thead>
              <tr><th>Room</th><th>Type</th><th>Capacity</th><th></th></tr>
            </thead>
            <tbody>
              {rooms.map(room => (
                <tr key={room.RoomID}>
                  <td>{room.RoomName}</td>
                  <td>{room.RoomType}</td>
                  <td>{room.Capacity}</td>
                  <td><button onClick={() => book(room)}>Book</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </div>
  )
}
