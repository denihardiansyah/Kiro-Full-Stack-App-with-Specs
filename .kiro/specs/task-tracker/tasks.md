# Implementation Plan — Task Tracker

## Execution Rules

1. Jalankan task **satu per satu sesuai urutan**. Jangan gunakan Run All Tasks dalam alur peserta.
2. Implementasikan hanya output task aktif.
3. Jangan membuat fitur, endpoint, dependency, file, component, state, atau abstraction di luar `requirements.md` dan `design.md`.
4. Jika task memerlukan perubahan scope, hentikan implementasi dan minta approval.
5. Setelah task selesai, tampilkan file yang diubah dan berhenti; jangan otomatis melanjutkan.
6. Jangan membuat optional task, test framework, dokumentasi tambahan, atau improvement.
7. Simpan package dengan versi exact tanpa `^` atau `~` menggunakan npm `--save-exact`.

## Required Tasks

- [ ] 1. Scaffold workspace dan scripts minimum
  - Buat root `package.json` sebagai private npm workspace untuk `frontend` dan `backend`.
  - Tambahkan hanya root dev dependency `concurrently` dengan versi exact.
  - Buat `frontend/package.json` hanya dengan `react`, `react-dom`, `vite`, dan `@vitejs/plugin-react`, semua exact.
  - Buat `backend/package.json` hanya dengan `express`, versi exact.
  - Buat script root `dev`/`build`, frontend `dev`/`build`, dan backend `dev`/`start` sesuai design.
  - Buat `frontend/index.html`, `frontend/vite.config.js`, dan placeholder minimum `frontend/src/main.jsx`.
  - Proxy Vite `/api` ke `http://localhost:3001`.
  - Jalankan `npm install` dari root untuk menghasilkan `package-lock.json`.
  - Jangan gunakan project generator atau membuat file lain.
  - **Definition of done:** Struktur sama dengan design; manifest hanya memiliki allowed exact dependencies dan required scripts.
  - _Requirements: 5.1, 6.1, 6.2, 6.4, 6.5, 6.6_

- [ ] 2. Implementasikan Express API dan Task Store in-memory
  - Buat seluruh server hanya di `backend/src/index.js`.
  - Deklarasikan array task module-scope dan gunakan `crypto.randomUUID()`.
  - Implementasikan tepat `GET /api/tasks`, `POST /api/tasks`, dan `PATCH /api/tasks/:id/toggle`.
  - Title invalid menghasilkan `400` dengan `{ "message": "Task title is required" }`.
  - Task baru hanya memiliki `id`, trimmed `title`, `completed: false`, dan ISO `createdAt`.
  - ID toggle yang tidak ditemukan menghasilkan `404` dengan `{ "message": "Task not found" }`.
  - Semua error berbentuk `{ "message": "..." }`; server memakai port `3001`.
  - Jangan menambah endpoint, persistence, seed, CORS, controller, service, model, atau repository.
  - **Definition of done:** Tiga contract terpenuhi dan restart menghasilkan store kosong.
  - _Requirements: 2.2–2.4, 3.2–3.4, 4.4, 5.3, 5.4, 6.1, 6.3–6.6_

- [ ] 3. Implementasikan React page untuk load dan render task
  - Buat `frontend/src/App.jsx` dan `frontend/src/styles.css`; semua component tetap di `App.jsx`.
  - Hubungkan `main.jsx` ke App dan stylesheet.
  - Gunakan hanya state `tasks`, `title`, `loading`, `submitting`, `togglingId`, dan `error`.
  - Fetch `GET /api/tasks` pada initial mount menggunakan native `fetch`.
  - Render loading, empty, atau list sesuai design.
  - Buat satu form title dan satu kontrol toggle per task; wiring mutation diselesaikan Task 4.
  - Ikuti struktur DOM dan token warna pada design §9.5: judul halaman `Task Tracker`, kartu putih di tengah halaman dengan latar `#eef1f5`, form sejajar horizontal, baris task dengan checkbox-judul-status, dan task selesai memakai strikethrough plus warna pudar.
  - Tulis CSS di `frontend/src/styles.css` sesuai token warna dan layout pada design §9.5, tanpa UI framework atau icon package.
  - Jangan menambah router, context, global store, cache, localStorage, UI library, icon, atau component file.
  - **Definition of done:** Satu halaman memuat dan menampilkan array, loading, serta empty state, dengan tampilan sesuai design §9.5.
  - _Requirements: 1.1–1.4, 4a.1–4a.9, 4a.11, 6.1, 6.2, 6.4–6.6_

- [ ] 4. Integrasikan create, toggle, dan error handling
  - Implementasikan `POST /api/tasks` dan `PATCH /api/tasks/:id/toggle` dengan native `fetch`.
  - Abaikan submit/toggle jika `submitting === true` atau `togglingId !== null`.
  - Validasi title kosong di Client dengan `Task title is required`.
  - Create sukses meng-append Task dan mengosongkan input tanpa reload.
  - Toggle sukses hanya me-replace task ber-ID sama.
  - Gunakan `submitting` dan `togglingId`; nonaktifkan form dan semua toggle selama mutation.
  - Non-2xx/network error tampil pada region `role="alert"` dengan styling `.error` sesuai design §9.5 (bukan `alert()` browser); jangan optimistic update.
  - Hapus/ganti error lama ketika operasi baru dimulai.
  - Jangan menambah retry, notification package, edit, delete, filter, search, sort, pagination, atau fitur lain.
  - **Definition of done:** Create, validation, toggle, errors, dan serialisasi mutation sesuai design.
  - _Requirements: 1.5, 2.1–2.6, 3.1–3.5, 4.1–4.4, 4a.10, 6.5, 6.6_

- [ ] 5. Validasi build, vertical slice, dan batas scope
  - Jalankan `npm install` dari root jika dependency belum terpasang.
  - Jalankan `npm run build`; perbaiki hanya error build tanpa refactor/dependency baru.
  - Pastikan hanya allowed exact dependencies, tiga endpoint, satu entity, satu halaman, dan fixed structure.
  - Jangan memulai dev server/watch otomatis; minta peserta menjalankan `npm run dev` manual.
  - Minta peserta menjalankan dan mengonfirmasi:
    1. Empty state tampil.
    2. Task valid dibuat.
    3. Title kosong ditolak.
    4. Toggle mengubah status.
    5. API mati menghasilkan visible error.
    6. Restart API mengosongkan task.
    7. Tampilan sesuai design §9.5: kartu putih di tengah halaman, task selesai bergaris coret dan pudar, error tampil sebagai kotak merah muda di atas form.
  - Jangan memasang test framework atau membuat file laporan.
  - Jika test gagal, perbaiki hanya defect requirement dan ulangi test terkait.
  - Jika test belum dijalankan, biarkan Task 5 dan acceptance pending.
  - **Definition of done:** Build lulus, scope bersih, dan peserta mengonfirmasi ketujuh smoke test berhasil.
  - _Requirements: 1.1–1.5, 2.1–2.6, 3.1–3.5, 4.1–4.4, 4a.1–4a.11, 5.1–5.5, 6.1–6.6_

## Completion Gate

```text
[ ] Exactly 1 domain entity: Task
[ ] Exactly 1 application page
[ ] Exactly 3 API endpoints
[ ] Only allowed dependencies with exact versions
[ ] No cloud/database/auth/deployment implementation
[ ] No edit/delete/filter/search/pagination feature
[ ] No test framework added
[ ] Root client build passes
[ ] All 7 manual smoke tests pass and are confirmed by the participant
[ ] UI matches design §9.5: page structure, color tokens, and completed-task styling
```

Build tanpa konfirmasi smoke test hanya berarti **implementation ready for acceptance**, bukan spec complete. Jika scope check gagal, hapus implementasi di luar scope; jangan membuat task baru untuk mempertahankannya.
