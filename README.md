# Kiro Builder Lab — Static Workshop Guide

Website statis berbahasa Indonesia untuk hands-on **Building a Full-Stack App with Spec-Driven Development** menggunakan Kiro.

Workshop ini ditujukan untuk peserta pemula. Dalam 60 menit, peserta menggunakan Kiro untuk mengubah kebutuhan menjadi `requirements.md`, `design.md`, `tasks.md`, lalu membangun satu vertical slice aplikasi Task Tracker.

> Materi ini adalah community guide dan bukan publikasi resmi AWS.

## Hasil akhir peserta

Peserta akan membuat aplikasi **Task Tracker full-stack satu halaman** dengan tiga kemampuan inti:

1. Melihat seluruh task.
2. Menambahkan task dengan judul wajib.
3. Menandai task selesai atau belum selesai.

Scope sengaja dibatasi menjadi satu entity `Task`, satu halaman, dan tiga endpoint agar realistis untuk workshop 60 menit dan guardrail maksimal 50 credits.

## High-Level Design (HLD)

```text
┌───────────────────────────────────────────────────────────────┐
│ Browser                                                       │
│                                                               │
│  React Task Tracker                                           │
│  ├─ TaskForm        → input dan tambah task                   │
│  ├─ TaskList        → daftar dan empty/loading state          │
│  └─ TaskItem        → status dan tombol/checkbox toggle       │
└───────────────────────────────┬───────────────────────────────┘
                                │ Native fetch / JSON
                                │ /api/*
                                ▼
┌───────────────────────────────────────────────────────────────┐
│ Vite Development Server :5173                                 │
│ Proxy /api → http://localhost:3001                            │
└───────────────────────────────┬───────────────────────────────┘
                                ▼
┌───────────────────────────────────────────────────────────────┐
│ Express API :3001                                             │
│ ├─ GET   /api/tasks                                           │
│ ├─ POST  /api/tasks                                           │
│ └─ PATCH /api/tasks/:id/toggle                                │
└───────────────────────────────┬───────────────────────────────┘
                                ▼
┌───────────────────────────────────────────────────────────────┐
│ Array<Task> in-memory                                         │
│ id · title · completed · createdAt                            │
│ Data kembali kosong ketika server restart                     │
└───────────────────────────────────────────────────────────────┘
```

### Cara kerja aplikasi

#### 1. Membuka halaman

```text
Browser → GET /api/tasks → Express → in-memory array → JSON array → React
```

React menampilkan loading state saat request berjalan. Jika array kosong, UI menampilkan empty state.

#### 2. Menambahkan task

```text
User isi title → POST /api/tasks → validasi server → task dibuat → HTTP 201 → UI diperbarui
```

Judul kosong atau whitespace ditolak dengan pesan `Task title is required`.

#### 3. Mengubah status task

```text
User klik toggle → PATCH /api/tasks/:id/toggle → completed dibalik → HTTP 200 → UI diperbarui
```

Jika ID tidak ditemukan, API merespons HTTP `404` dengan pesan `Task not found`.

#### 4. Menangani error

Client tidak melakukan optimistic update. Perubahan UI hanya dianggap berhasil setelah API mengembalikan response sukses. Kegagalan koneksi atau response non-2xx ditampilkan sebagai visible error.

### Yang tidak dibangun

Workshop tidak mencakup authentication, database, edit/delete, search, filter, pagination, Docker, deployment cloud, test framework, atau styling kompleks. Batas lengkap tersedia di `.kiro/specs/task-tracker/requirements.md`.

## Struktur repository guide

```text
workshop-kiro/
├── index.html
├── styles.css
├── app.js
├── README.md
└── .kiro/
    └── specs/
        └── task-tracker/
            ├── requirements.md
            ├── design.md
            └── tasks.md
```

- `index.html` — seluruh modul workshop dan prompt peserta.
- `styles.css` — visual AWS Workshops-inspired, responsive, dark mode, dan print style.
- `app.js` — navigasi, progress, clipboard, theme, dan credit tracker.
- `.kiro/specs/task-tracker/` — spec scope-locked untuk aplikasi yang dibangun peserta.

## Prerequisites peserta

Peserta memerlukan:

- Kiro IDE dan akun untuk sign-in.
- Node.js **versi LTS** yang kompatibel dengan Vite.
- npm, yang otomatis disertakan dalam installer Node.js.
- Browser modern.
- Terminal di dalam Kiro.

Akun AWS tidak diperlukan untuk lab lokal ini.

## Instalasi Kiro

1. Buka [Kiro Downloads](https://kiro.dev/downloads/).
2. Unduh installer sesuai sistem operasi.
3. Jalankan installer dan buka Kiro.
4. Sign-in menggunakan metode yang tersedia, misalnya GitHub, Google, atau AWS Builder ID.
5. Buka dashboard usage dan catat credit balance sebelum memulai lab.

## Instalasi Node.js dan npm

### Windows — installer grafis, direkomendasikan untuk pemula

1. Buka [Node.js Downloads](https://nodejs.org/en/download).
2. Pilih rilis **LTS**, bukan Current.
3. Unduh dan jalankan Windows Installer `.msi`.
4. Pertahankan pilihan default, termasuk npm dan penambahan Node.js ke `PATH`.
5. Tutup dan buka kembali Kiro setelah instalasi.

### Windows — menggunakan winget

Jalankan PowerShell atau Windows Terminal:

```powershell
winget install OpenJS.NodeJS.LTS
```

Tutup dan buka kembali Kiro setelah proses selesai.

### macOS

Gunakan installer LTS dari [Node.js Downloads](https://nodejs.org/en/download), atau jika Homebrew sudah tersedia:

```bash
brew install node
```

### Linux atau WSL

Gunakan installer/version manager yang direkomendasikan pada [Node.js Downloads](https://nodejs.org/en/download). Pilih rilis LTS. Hindari package Node.js distro yang terlalu lama karena mungkin tidak kompatibel dengan Vite yang dihasilkan.

### Verifikasi instalasi

Buka terminal baru di Kiro lalu jalankan:

```bash
node --version
npm --version
```

Contoh hasil yang benar:

```text
vXX.YY.ZZ
XX.YY.ZZ
```

Nomor aktual dapat berbeda. Yang penting kedua command menampilkan versi dan tidak menghasilkan `command not found` atau `not recognized`.

Jika command tidak ditemukan:

1. Tutup seluruh terminal dan restart Kiro.
2. Pastikan Node.js telah ditambahkan ke `PATH`.
3. Pada Windows, coba restart komputer setelah installer selesai.
4. Jalankan kembali `node --version` dan `npm --version`.

## Menjalankan website guide ini

Website guide tidak memiliki dependency atau build step. Anda dapat membuka `index.html` langsung di browser.

Untuk clipboard dan routing yang lebih konsisten, jalankan static server dari root repository:

```bash
python3 -m http.server 8080
```

Jika Windows hanya menyediakan command `python`, gunakan:

```powershell
python -m http.server 8080
```

Kemudian buka:

```text
http://localhost:8080
```

## Menggunakan spec yang sudah dikunci

Spec tersedia di:

```text
.kiro/specs/task-tracker/
├── requirements.md
├── design.md
└── tasks.md
```

Ketiga file tersebut menetapkan:

- Tepat satu entity: `Task`.
- Tepat satu halaman.
- Tepat tiga endpoint.
- Dependency yang diperbolehkan.
- Struktur file target.
- Lima required implementation tasks.
- Out-of-scope dan change-control rules.

Untuk dry run fasilitator, buat folder kosong terpisah bernama `kiro-task-tracker`, lalu salin `.kiro/specs/task-tracker` dari repository guide ini ke folder `.kiro/specs/task-tracker` pada project baru. Buka project baru tersebut di Kiro dan gunakan panel **Specs → task-tracker**.

> Jangan menjalankan implementation task langsung di repository website guide. Struktur target pada `design.md` mengasumsikan root project aplikasi yang kosong.

Untuk alur workshop penuh, peserta dapat membuat spec melalui prompt pada website. File scope-locked ini berfungsi sebagai baseline fasilitator, checkpoint, atau pengganti ketika waktu/credit tidak memungkinkan regenerasi spec.

## Mengapa Kiro menampilkan dua pilihan Run All Tasks?

Pada versi Kiro IDE yang diuji untuk workshop ini, Kiro membedakan **required task** dan **optional task** pada `tasks.md` dengan format berikut. Konvensi marker dan wording label UI dapat berubah pada versi Kiro berikutnya.

```md
- [ ] 1. Implementasikan fitur inti
- [ ]* 1.1 Tambahkan property-based tests
```

- `- [ ]` adalah required task.
- `- [ ]*` adalah optional task.

Pilihan pada UI dapat sedikit berbeda menurut versi Kiro, tetapi semantiknya adalah:

| Pilihan | Yang dijalankan | Kapan digunakan |
|---|---|---|
| **Run all required tasks** | Semua required task yang belum selesai | Implementasi inti atau workshop dengan scope ketat |
| **Run all required and optional tasks** | Semua required dan optional task yang belum selesai | Stretch goal ketika waktu dan credit masih cukup |

Kiro menganalisis dependency antar-task dan menjalankannya dalam beberapa wave. Task independen dapat berjalan paralel; task yang bergantung pada task lain akan menunggu dependency selesai.

### Mengapa pilihan itu tetap dapat muncul?

Chooser merupakan bagian dari fitur eksekusi massal Kiro. Ia memungkinkan plan yang memiliki pekerjaan non-inti—misalnya property-based test—untuk tetap memprioritaskan implementasi wajib. Wording dan kapan chooser tampil dapat berubah antarversi Kiro.

### Pilihan untuk workshop ini

`tasks.md` workshop berisi **lima required task dan tidak memiliki optional task**. Karena itu:

- Cara paling aman: jalankan task **satu per satu**.
- Jika perlu bulk run untuk dry run fasilitator: pilih **Run all required tasks**.
- Jangan memilih required + optional untuk menambahkan pekerjaan baru.
- Jika kedua opsi tetap tampil saat tidak ada task optional, scope efektif seharusnya sama; tetap pilih required-only agar intent jelas.

Eksekusi satu per satu direkomendasikan karena peserta dapat:

1. Meninjau diff setelah setiap task.
2. Mendeteksi scope creep lebih awal.
3. Mencatat credit balance per fase.
4. Berhenti sebelum guardrail 40/50 credits.
5. Menjalankan smoke test sebelum spec dinyatakan selesai.

Optional task tidak boleh menjadi dependency bagi required task. Jika itu terjadi, perbaiki `tasks.md` lebih dahulu.

## Menjalankan aplikasi Task Tracker hasil implementasi

Jalankan bagian ini setelah Task 1–4 pada `tasks.md` selesai.

### 1. Pastikan terminal berada di root project

Root project adalah folder yang berisi:

```text
package.json
client/
server/
```

### 2. Pasang dependency

```bash
npm install
```

Npm workspaces akan memasang dependency root, client, dan server dari satu command.

### 3. Jalankan Client dan API

```bash
npm run dev
```

Script root menjalankan keduanya melalui `concurrently`:

| Komponen | URL | Fungsi |
|---|---|---|
| React Client | `http://localhost:5173` | UI Task Tracker |
| Express API | `http://localhost:3001/api/tasks` | Endpoint data task |

Buka `http://localhost:5173` di browser.

> Development server adalah proses jangka panjang. Jalankan secara manual pada terminal Kiro dan biarkan terminal tetap terbuka selama smoke test.

### 4. Hentikan aplikasi

Pada terminal yang menjalankan project, tekan:

```text
Ctrl + C
```

Karena data menggunakan array in-memory, task akan hilang ketika API dihentikan atau dimulai ulang. Ini adalah perilaku yang disengaja oleh spec.

### 5. Validasi production build

Setelah menghentikan development server, jalankan:

```bash
npm run build
```

Build dianggap berhasil jika command selesai tanpa error dan Vite menghasilkan output Client.

## Smoke test wajib

Spec baru dianggap accepted/complete setelah peserta mengonfirmasi seluruh test berikut:

```text
[ ] Empty state tampil saat server baru dijalankan
[ ] Task dengan title valid berhasil dibuat
[ ] Title kosong menampilkan "Task title is required"
[ ] Toggle mengubah status completed
[ ] API yang dihentikan menghasilkan visible error pada Client
[ ] Restart API mengosongkan seluruh task
```

Build yang berhasil tanpa smoke test hanya berarti **implementation ready for acceptance**, belum berarti spec selesai.

## Troubleshooting project

### Port sudah digunakan

Jika port `5173` atau `3001` sedang digunakan, hentikan process lama dengan `Ctrl + C`. Jangan mengubah port dalam workshop tanpa memperbarui design karena proxy telah dikunci ke port `3001`.

### `npm install` gagal

- Pastikan koneksi internet tersedia.
- Jalankan kembali `node --version` dan `npm --version`.
- Pastikan terminal berada di root project.
- Jangan memasang package tambahan untuk mengatasi error tanpa Requirement ID.

### UI tampil tetapi API gagal

- Pastikan output terminal menunjukkan Client dan API berjalan.
- Periksa bahwa request menggunakan path relatif `/api/tasks`.
- Periksa Vite proxy menuju `http://localhost:3001`.
- Jangan menambahkan CORS package; design menggunakan Vite proxy.

## Hosting website guide

Folder guide dapat di-host apa adanya pada GitHub Pages, AWS Amplify Hosting, Amazon S3 + CloudFront, atau static hosting lain. Pastikan `index.html`, `styles.css`, dan `app.js` berada pada path yang sama.

## Guardrail credit

Angka 50 mengikuti Kiro Free tier yang tercantum pada halaman pricing saat materi dibuat. Konsumsi aktual tidak dapat dipastikan sebelum eksekusi karena dipengaruhi kompleksitas, model, refinement, dan task. Guide meminta peserta mencatat saldo aktual dari dashboard Kiro pada setiap fase.

Rekomendasi:

- `0–19.99`: lanjutkan sesuai task.
- `20–39.99`: prioritaskan vertical slice, lewati polish.
- `40–49.99`: hentikan refinement dan gunakan hanya perbaikan terarah.
- `≥50`: hentikan eksperimen sesuai guardrail.

## Referensi resmi

- [Kiro Pricing](https://kiro.dev/pricing/)
- [Kiro Specs](https://kiro.dev/docs/specs/)
- [Requirements-First workflow](https://kiro.dev/docs/specs/feature-specs/requirements-first/)
- [Spec best practices dan Run all Tasks](https://kiro.dev/docs/specs/best-practices/)
- [Correctness dan optional property-based tests](https://kiro.dev/docs/specs/correctness/)
- [Kiro Billing](https://kiro.dev/docs/billing/)
- [Node.js Downloads](https://nodejs.org/en/download)

Informasi produk dapat berubah. Periksa dokumentasi resmi sebelum workshop. Konten dari sumber resmi telah diparafrasekan untuk mematuhi ketentuan lisensi.
