import { useEffect, useState } from 'react'
import { api, showTime, showHour } from '../api.js'

export default function MyBookings() {
  const [bookings, setBookings] = useState([])
  const [error, setError] = useState('')

  async function load() {
    try {
      setBookings(await api('/bookings/mine'))
    } catch (err) {
      setError(err.message)
    }
  }

  useEffect(() => { load() }, [])

  async function cancel(id) {
    if (!window.confirm('Cancel this booking?')) return
    setError('')
    try {
      await api(`/bookings/${id}/cancel`, { method: 'POST' })
      load()
    } catch (err) {
      setError(err.message)
    }
  }

  return (
    <div>
      <h2>My upcoming bookings</h2>
      {error && <p className="error">{error}</p>}
      {bookings.length === 0 ? (
        <p>You have no upcoming bookings.</p>
      ) : (
        <table>
          <thead>
            <tr><th>Room</th><th>When</th><th>People</th><th>Equipment</th><th>Status</th><th></th></tr>
          </thead>
          <tbody>
            {bookings.map(b => (
              <tr key={b.BookingID} className={b.Status === 'Cancelled' ? 'muted' : ''}>
                <td>{b.RoomName}</td>
                <td>{showTime(b.StartTime)}–{showHour(b.EndTime)}</td>
                <td>{b.People}</td>
                <td>{b.Equipment || '—'}</td>
                <td>{b.Status}</td>
                <td>
                  {b.Status === 'Active' && <button className="danger" onClick={() => cancel(b.BookingID)}>Cancel</button>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}
