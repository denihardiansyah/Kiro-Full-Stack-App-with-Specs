# Design Document — Task Tracker

## 1. Design Status

**Status:** Scope-locked for workshop implementation  
**Requirements source:** `requirements.md`  
**Change policy:** Design hanya boleh diubah jika ada Requirement ID yang memerlukan perubahan dan perubahan tersebut disetujui.

## 2. Overview

```text
Browser
  └─ React single page (localhost:5173)
       └─ native fetch ke relative path /api/*
            └─ Vite development proxy
                 └─ Express API (localhost:3001)
                      └─ Array<Task> in-memory
```

Aplikasi tidak memiliki cloud resource, database, authentication, router multi-page, atau service eksternal.

## 3. Design Goals dan Non-Goals

Goals:

1. Memenuhi seluruh acceptance criteria Requirements 1–5.
2. Menjaga satu entity, satu halaman, dan tiga endpoint sesuai Requirement 6.
3. Dapat diselesaikan peserta pemula dalam 60 menit.
4. Menggunakan dependency dan file sesedikit mungkin.

Non-goals:

- Persistence setelah server restart.
- Identity atau multi-user behavior.
- Edit, delete, filter, sort, search, pagination, priority, atau due date.
- AWS/cloud integration atau deployment artifact.
- Layer controller/service/repository, ORM, dependency injection, atau domain framework.
- Automated test suite, UI framework, icon package, atau CSS framework.

## 4. Technology Decisions

| Area | Keputusan terkunci | Alasan |
|---|---|---|
| Client | React + Vite | Requirement 6.4 |
| Client state | `useState` dan `useEffect` | Cukup untuk satu halaman |
| HTTP client | Native `fetch` | Tidak menambah dependency |
| API | Node.js + Express | Requirement 6.4 |
| Storage | Array module-scope | Reset saat restart |
| ID | `crypto.randomUUID()` | Built-in Node.js |
| Proxy | `/api` → `http://localhost:3001` | Tidak memerlukan CORS package |
| Parallel dev | `concurrently` | Satu command lintas platform |
| Validation | Build + smoke test manual | Sesuai batas workshop |

### 4.1 Allowed Dependencies

Hanya package berikut yang boleh ditambahkan:

- Root dev dependency: `concurrently`
- Client dependencies: `react`, `react-dom`
- Client dev dependencies: `vite`, `@vitejs/plugin-react`
- Server dependency: `express`

Semua dependency harus disimpan sebagai versi exact tanpa prefix `^` atau `~`, menggunakan instalasi equivalent dengan npm `--save-exact`. Dependency lain dilarang kecuali spec diubah dan disetujui terlebih dahulu.

## 5. Project Structure

```text
kiro-task-tracker/
├── package.json
├── package-lock.json
├── client/
│   ├── package.json
│   ├── index.html
│   ├── vite.config.js
│   └── src/
│       ├── main.jsx
│       ├── App.jsx
│       └── styles.css
└── server/
    ├── package.json
    └── src/
        └── index.js
```

Batas struktur:

- Array task dan tiga route berada di `server/src/index.js`; jangan membuat controller, service, model, atau repository layer.
- State dan komponen React berada di `client/src/App.jsx`; jangan membuat context, global store, atau route file.
- `package-lock.json` boleh dihasilkan otomatis oleh npm.
- Source/configuration file lain dilarang kecuali spec diubah dan disetujui.

## 6. Data Model

```ts
type Task = {
  id: string;
  title: string;
  completed: boolean;
  createdAt: string;
};
```

Invariants:

- `id` berasal dari `crypto.randomUUID()` dan unik selama proses berjalan.
- `title` selalu di-trim dan tidak kosong.
- `completed` selalu boolean dan bernilai `false` saat dibuat.
- `createdAt` adalah ISO 8601 dan tidak berubah.
- Task tidak memiliki properti domain lain.
- Store dimulai sebagai `[]` setiap server restart.

## 7. API Contract

Semua request/response menggunakan JSON. API hanya memiliki tiga endpoint.

### 7.1 GET `/api/tasks`

- Request body: tidak ada.
- Success: `200 OK` dengan `Task[]`; store kosong menghasilkan `[]`.

### 7.2 POST `/api/tasks`

Request:

```json
{ "title": "Learn Kiro Specs" }
```

Success: `201 Created` dengan Task yang dibuat.

```json
{
  "id": "7fbbf8c6-3901-4f2f-a118-a40c681f302f",
  "title": "Learn Kiro Specs",
  "completed": false,
  "createdAt": "2026-09-08T10:00:00.000Z"
}
```

Validation error: `400 Bad Request`.

```json
{ "message": "Task title is required" }
```

Validasi:

```js
typeof req.body?.title === 'string' && req.body.title.trim().length > 0
```

### 7.3 PATCH `/api/tasks/:id/toggle`

- Request body: tidak diperlukan.
- Success: `200 OK` dengan Task setelah `completed` dibalik.
- Not found: `404 Not Found` dengan `{ "message": "Task not found" }`.

### 7.4 Error Shape

Semua error memakai `{ "message": "Human-readable message" }`. Malformed JSON dapat menghasilkan `400` dengan `Invalid request body`; error tak terduga dapat menghasilkan `500` dengan `Something went wrong`.

Tidak boleh menambahkan endpoint lain, termasuk `/health`.

## 8. Server Design

`server/src/index.js` hanya:

1. Mengimpor Express dan `randomUUID` dari `node:crypto`.
2. Memasang `express.json()`.
3. Mendeklarasikan `let tasks = []` pada module scope.
4. Mendefinisikan tiga route sesuai kontrak.
5. Mengubah error parsing/unknown error menjadi JSON error shape.
6. Mendengarkan port `3001`.

Server tidak melakukan persistence, authentication, logging framework, pagination, CORS setup, atau abstraction layer.

## 9. Client Design

### 9.1 Component Boundary

Semua komponen berada dalam `client/src/App.jsx`:

```text
App / TaskPage
├── TaskForm
└── TaskList
    └── TaskItem (repeated)
```

`App` memiliki seluruh state dan fungsi HTTP. Komponen lain hanya presentational di file yang sama.

### 9.2 State

```js
const [tasks, setTasks] = useState([]);
const [title, setTitle] = useState('');
const [loading, setLoading] = useState(true);
const [submitting, setSubmitting] = useState(false);
const [togglingId, setTogglingId] = useState(null);
const [error, setError] = useState('');
```

Dilarang menambah global store, reducer framework, server-state library, cache, client persistence, atau optimistic update.

### 9.3 Client Operations

**Load**

1. Set loading dan hapus error lama.
2. Fetch `GET /api/tasks` saat initial mount.
3. Set response ke `tasks`, atau tampilkan error.
4. Selesaikan loading pada `finally`.

**Create**

1. Abaikan submit jika `submitting === true` atau `togglingId !== null`.
2. Hapus error lama; tolak title kosong dengan `Task title is required`.
3. Set `submitting = true`, lalu `POST /api/tasks` dengan `{ title }`.
4. Jika berhasil, append Task dan kosongkan title; jika gagal, tampilkan error.
5. Set `submitting = false` pada `finally`.

**Toggle**

1. Abaikan toggle jika `submitting === true` atau `togglingId !== null`.
2. Hapus error lama dan set `togglingId`.
3. `PATCH /api/tasks/:id/toggle`.
4. Jika berhasil, replace task ber-ID sama; jika gagal, pertahankan state dan tampilkan error.
5. Set `togglingId = null` pada `finally`.

Satu mutation harus selesai sebelum mutation berikutnya. Form submit dan seluruh toggle dinonaktifkan ketika `submitting === true` atau `togglingId !== null`.

### 9.4 Rendering States

1. Loading: `Loading tasks...`.
2. Empty: `No tasks yet. Add your first task.`.
3. Data: render list dan status.
4. Error: visible region dengan `role="alert"`.

## 10. Development Scripts

Root memakai npm workspaces `client` dan `server`.

- Root `npm run dev`: Client + API via `concurrently`.
- Root `npm run build`: Vite Client build.
- Client `npm run dev` dan `npm run build`.
- Server `npm run dev` dengan Node watch mode dan `npm start` tanpa watch.

Vite mem-proxy `/api` ke `http://localhost:3001`. Jangan menambah lint, format, test, deploy, Docker, database, atau seed script.

## 11. Error Matrix dan Traceability

| Kondisi | API | Client | Requirement |
|---|---|---|---|
| Load | `200` + array | Loading lalu list/empty | 1.1–1.4 |
| Create valid | `201` + Task | Append dan clear input | 2.1–2.6 |
| Title kosong | `400` + message | Error; tidak append | 2.4, 4.2 |
| Toggle valid | `200` + Task | Replace task | 3.1–3.5 |
| Toggle missing | `404` + message | Error; state tetap | 3.4, 4.2 |
| Network/server error | Error JSON jika tersedia | Error; tanpa optimistic state | 4.1–4.4 |

| Requirement | Design elements |
|---|---|
| 1 | GET contract, load, loading/list/empty states |
| 2 | POST contract, form, create, submitting state |
| 3 | PATCH contract, item control, serialized toggle |
| 4 | Error shape, role alert, no optimistic update |
| 5 | Workspaces/scripts, build, in-memory, local-only |
| 6 | Allowed dependencies, fixed tree, three endpoints, non-goals |

## 12. Validation Strategy

1. `npm install` dari root berhasil.
2. `npm run build` dari root berhasil.
3. Peserta menjalankan `npm run dev` dari root.
4. Peserta mengonfirmasi enam smoke test:
   - Empty state tampil.
   - Task valid dapat dibuat.
   - Judul kosong ditolak.
   - Status dapat di-toggle.
   - Error tampil ketika API tidak tersedia.
   - Restart API mengosongkan task.
5. Scope check: satu entity, satu halaman, tiga endpoint, allowed exact dependencies, dan tidak ada item Out of Scope.

Build berhasil hanya berarti **implementation ready for acceptance**. Spec berstatus **accepted/complete** setelah keenam smoke test manual berhasil dikonfirmasi.

## 13. Scope Guard

```text
Apakah elemen baru diwajibkan oleh Requirement ID?
├─ Tidak → jangan implementasikan.
└─ Ya
   ├─ Sudah tercantum di design → implementasikan sesuai design.
   └─ Belum tercantum → hentikan, minta approval, lalu update spec.
```

Jangan melakukan improvement, refactor, hardening, future-proofing, atau penambahan best practice di luar requirement dan design workshop.
