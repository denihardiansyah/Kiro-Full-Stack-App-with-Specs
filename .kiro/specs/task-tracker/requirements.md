# Requirements Document — Task Tracker

## 1. Introduction

Task Tracker adalah aplikasi full-stack satu halaman untuk workshop pemula Kiro. Aplikasi hanya mendemonstrasikan satu vertical slice: melihat task, menambahkan task, dan mengubah status selesai. Dokumen ini adalah sumber kebenaran untuk perilaku aplikasi.

Implementasi **MUST NOT** menambahkan fitur yang tidak dinyatakan di dokumen ini. Perubahan scope hanya boleh dilakukan setelah `requirements.md`, `design.md`, dan `tasks.md` diperbarui serta disetujui kembali.

## 2. Glossary

- **System**: Keseluruhan aplikasi Task Tracker.
- **Client**: Antarmuka web React satu halaman.
- **API**: Server HTTP Express.
- **Task**: Item pekerjaan dengan `id`, `title`, `completed`, dan `createdAt`.
- **Task Store**: Array in-memory pada proses server; data hilang saat server restart.
- **Valid Title**: String yang masih memiliki minimal satu karakter setelah whitespace di awal dan akhir dihapus.
- **API Error**: Response non-2xx atau kegagalan koneksi antara Client dan API.

## 3. Requirements

### Requirement 1 — Melihat daftar task

**User Story:** Sebagai pengguna, saya ingin melihat seluruh task agar mengetahui pekerjaan yang tersedia.

#### Acceptance Criteria

1.1. **WHEN** halaman pertama kali dibuka, **THE SYSTEM SHALL** meminta daftar task melalui `GET /api/tasks`.

1.2. **WHEN** API mengembalikan satu atau lebih task, **THE SYSTEM SHALL** menampilkan setiap `title` dan status `completed` task tersebut.

1.3. **WHEN** API mengembalikan array kosong, **THE SYSTEM SHALL** menampilkan empty state yang menjelaskan bahwa belum ada task.

1.4. **WHILE** permintaan daftar task masih berjalan, **THE SYSTEM SHALL** menampilkan loading state.

1.5. **WHEN** task berhasil dibuat atau di-toggle, **THE SYSTEM SHALL** memperbarui daftar yang terlihat tanpa reload halaman manual.

### Requirement 2 — Menambahkan task

**User Story:** Sebagai pengguna, saya ingin menambahkan task agar pekerjaan baru tercatat.

#### Acceptance Criteria

2.1. **THE SYSTEM SHALL** menyediakan satu input judul dan satu tombol untuk menambahkan task.

2.2. **WHEN** pengguna mengirim Valid Title, **THE SYSTEM SHALL** mengirim `POST /api/tasks` dengan body JSON yang hanya memerlukan properti `title`.

2.3. **WHEN** API menerima Valid Title, **THE SYSTEM SHALL** menghapus whitespace di awal dan akhir judul, membuat task baru dengan `completed: false`, lalu merespons HTTP `201` dengan task yang dibuat.

2.4. **WHEN** pengguna mengirim judul kosong atau hanya whitespace, **THE SYSTEM SHALL** menolak pembuatan task dan menampilkan pesan `Task title is required`.

2.5. **WHEN** task berhasil dibuat, **THE SYSTEM SHALL** mengosongkan input dan menampilkan task baru pada daftar.

2.6. **WHILE** pembuatan task sedang diproses, **THE SYSTEM SHALL** mencegah submit berulang untuk operasi yang sama.

### Requirement 3 — Mengubah status task

**User Story:** Sebagai pengguna, saya ingin mengubah status task agar dapat menandai pekerjaan selesai atau belum selesai.

#### Acceptance Criteria

3.1. **THE SYSTEM SHALL** menyediakan satu kontrol toggle untuk setiap task yang ditampilkan.

3.2. **WHEN** pengguna mengaktifkan kontrol toggle, **THE SYSTEM SHALL** mengirim `PATCH /api/tasks/:id/toggle` untuk task tersebut.

3.3. **WHEN** API menemukan task, **THE SYSTEM SHALL** membalik nilai `completed`, merespons HTTP `200`, dan mengembalikan task yang diperbarui.

3.4. **WHEN** API tidak menemukan task, **THE SYSTEM SHALL** merespons HTTP `404` dengan pesan `Task not found`.

3.5. **WHEN** toggle berhasil, **THE SYSTEM SHALL** menampilkan status terbaru tanpa reload halaman manual.

### Requirement 4 — Menangani kegagalan

**User Story:** Sebagai pengguna, saya ingin mendapat informasi saat operasi gagal agar tidak mengira perubahan telah disimpan.

#### Acceptance Criteria

4.1. **WHEN** Client mengalami API Error saat memuat, membuat, atau mengubah task, **THE SYSTEM SHALL** menampilkan pesan error yang terlihat.

4.2. **WHEN** operasi create atau toggle gagal, **THE SYSTEM SHALL NOT** menampilkan perubahan tersebut sebagai hasil yang berhasil.

4.3. **WHEN** pengguna memulai operasi baru setelah error, **THE SYSTEM SHALL** menghapus atau mengganti pesan error lama dengan status operasi terbaru.

4.4. **THE API SHALL** mengirim response error dalam bentuk JSON `{ "message": "..." }`.

### Requirement 5 — Dapat dijalankan untuk workshop

**User Story:** Sebagai peserta workshop, saya ingin menjalankan seluruh aplikasi dari workspace lokal dengan langkah minimum.

#### Acceptance Criteria

5.1. **THE SYSTEM SHALL** menyediakan konfigurasi workspace root sehingga `npm install` dari root memasang seluruh dependency dan `npm run dev` dari root menjalankan Client serta API dalam mode development.

5.2. **WHEN** build Client dijalankan, **THE SYSTEM SHALL** menyelesaikan build tanpa error.

5.3. **THE API SHALL** menyimpan task hanya pada Task Store in-memory.

5.4. **WHEN** proses API dimulai ulang, **THE SYSTEM SHALL** memulai dengan daftar task kosong.

5.5. **THE SYSTEM SHALL** dapat diselesaikan tanpa akun AWS, credential cloud, atau layanan eksternal.

### Requirement 6 — Batas scope wajib

**User Story:** Sebagai fasilitator, saya ingin scope tetap kecil agar peserta dapat menyelesaikan lab dalam 60 menit dan maksimal 50-credit guardrail.

#### Acceptance Criteria

6.1. **THE SYSTEM SHALL** memiliki tepat satu entity domain, yaitu `Task`.

6.2. **THE SYSTEM SHALL** memiliki tepat satu halaman aplikasi.

6.3. **THE API SHALL** mengekspos hanya tiga endpoint berikut:

- `GET /api/tasks`
- `POST /api/tasks`
- `PATCH /api/tasks/:id/toggle`

6.4. **THE SYSTEM SHALL** menggunakan React dengan Vite, native `fetch`, Node.js, Express, dan Task Store in-memory.

6.5. **THE SYSTEM SHALL NOT** mengimplementasikan fitur yang tercantum pada bagian Out of Scope.

6.6. **IF** sebuah keputusan implementasi tidak diperlukan untuk memenuhi Requirements 1–5, **THEN THE SYSTEM SHALL NOT** menambahkannya.

## 4. Out of Scope / Non-Goals

Item berikut secara eksplisit dilarang dalam implementasi workshop ini:

- Authentication, login, logout, user profile, session, role, dan authorization.
- Database, ORM, repository pattern, migration, seed framework, atau persistence file/localStorage.
- Deployment AWS/cloud, Infrastructure as Code, Docker, container, CI/CD, dan monitoring.
- Entity selain Task; kategori, project, user, tag, comment, attachment, due date, atau priority.
- Edit title, delete task, bulk action, filter, sort, search, pagination, dan real-time update.
- Routing multi-page, global state library, UI component library, CSS framework, dan styling kompleks.
- GraphQL, WebSocket, caching layer, background job, dan third-party API.
- Test framework baru, coverage tooling, atau end-to-end test suite. Validasi workshop dibatasi pada build dan smoke test manual.
- Endpoint selain tiga endpoint pada Requirement 6.3, termasuk health endpoint.

## 5. Scope Change Control

Sebelum menambahkan fitur, endpoint, dependency, entity, halaman, atau abstraction baru, implementer harus:

1. Menunjukkan Requirement ID yang mengharuskannya.
2. Jika tidak ada Requirement ID, menghentikan implementasi fitur tersebut.
3. Meminta persetujuan perubahan scope.
4. Setelah disetujui, memperbarui requirements, design, dan tasks secara berurutan.

Tanpa empat langkah tersebut, permintaan dianggap **out of scope** dan tidak boleh diimplementasikan.
