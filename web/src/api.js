// All calls to the C# API go through this file.

const USER_KEY = 'booking_user'

export function getUser() {
  try {
    return JSON.parse(localStorage.getItem(USER_KEY))
  } catch {
    return null
  }
}

export function saveUser(user) {
  localStorage.setItem(USER_KEY, JSON.stringify(user))
}

export function logout() {
  localStorage.removeItem(USER_KEY)
}

// Calls /api/<path>. Sends the login token. Throws an Error with the
// message from the API (for example "This room is already booked at that time.").
export async function api(path, { method = 'GET', body } = {}) {
  const user = getUser()
  const headers = { 'Content-Type': 'application/json' }
  if (user) headers.Authorization = `Bearer ${user.token}`

  const res = await fetch('/api' + path, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined
  })

  if (res.status === 401 && user) {   // token expired: log in again
    logout()
    window.location.href = '/login'
    return
  }

  const text = await res.text()
  let data = null
  try { data = text ? JSON.parse(text) : null } catch { data = { error: text } }

  if (!res.ok) {
    // Our API sends { error: "..." }. ASP.NET validation sends { title, errors: {...} }.
    const details = data?.errors ? ' ' + Object.values(data.errors).flat().join(' ') : ''
    const reason = data?.error || data?.title || (res.status === 403 ? 'You are not allowed to do this.' : '')
    throw new Error(`Error ${res.status}: ${reason || res.statusText || 'Request failed'}${details}`)
  }
  return data
}

// ---------- small helpers for dates and times ----------

// "08:00", "08:30", ... "16:00"
export const HALF_HOURS = Array.from({ length: 17 }, (_, i) => {
  const minutes = 480 + i * 30
  return `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`
})

// A date as "YYYY-MM-DD" in the user's own time zone
export function toDateText(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

export function tomorrow() {
  const d = new Date()
  d.setDate(d.getDate() + 1)
  return toDateText(d)
}

// "2026-11-25T10:00:00" -> "2026-11-25 10:00"
export function showTime(value) {
  return value ? value.replace('T', ' ').slice(0, 16) : ''
}

// "2026-11-25T10:00:00" -> "10:00"
export function showHour(value) {
  return value ? value.slice(11, 16) : ''
}
