# Deploy ke AWS ECS Fargate

Panduan menjalankan website guide statis ini sebagai container nginx di **Amazon ECS Fargate** di belakang **Application Load Balancer**.

> **Pertimbangkan dahulu.** Ini situs statis tiga file. S3 + CloudFront jauh lebih murah dan tanpa server. Fargate + ALB berbiaya tetap sekitar puluhan USD per bulan meski tidak ada pengunjung. Lihat [Perbandingan biaya](#perbandingan-biaya). Gunakan Fargate bila Anda memang ingin mendemokan container, ECS, atau menyeragamkan pola deployment dengan aplikasi lain.

## Arsitektur yang dibuat

```text
Internet
   │
   ▼
Application Load Balancer  (public, port 80 / 443)
   │  target group HTTP :8080, health check /healthz
   ▼
ECS Fargate service  (2 task, 2 Availability Zone)
   └─ container nginx-unprivileged :8080
        └─ index.html · styles.css · app.js
                │
                ▼
        CloudWatch Logs  /ecs/kiro-builder-lab
```

Stack membuat VPC sendiri agar tidak menyentuh jaringan yang sudah ada:

| Komponen | Detail |
|---|---|
| VPC | `10.20.0.0/16`, dua public subnet `/24` di dua AZ |
| ALB | internet-facing, `drop_invalid_header_fields` aktif |
| Security group ALB | inbound 80 dari `AllowedCidr`, 443 bila ada sertifikat |
| Security group task | inbound 8080 **hanya** dari security group ALB |
| Task | Fargate `X86_64`, default 0.25 vCPU + 512 MiB, non-root uid 101 |
| Task role | kosong; situs statis tidak memanggil API AWS |
| Logs | CloudWatch Logs, retensi 14 hari |

Task berada di public subnet dengan `AssignPublicIp: ENABLED` supaya bisa menarik image dari ECR tanpa NAT gateway. Trafik masuk tetap tertutup kecuali dari ALB. Alternatifnya adalah private subnet + NAT gateway atau VPC endpoint, keduanya menambah biaya.

## Prasyarat

- AWS CLI v2 sudah login dan punya izin membuat VPC, ALB, ECS, ECR, IAM role, dan CloudWatch Logs.
- Docker berjalan secara lokal. **Tidak diperlukan** bila memakai image dari GHCR.
- Bash. Pada Windows gunakan WSL atau Git Bash.

Cek cepat:

```bash
aws sts get-caller-identity
```

Khusus mode A yang build secara lokal, tambahkan:

```bash
docker info
```

## Dua sumber image

| Mode | Image berada di | Kapan dipakai |
|---|---|---|
| **A. ECR** (default) | Amazon ECR di akun Anda | Build dari laptop, semua di dalam AWS |
| **B. GHCR** | `ghcr.io/<owner>/<repo>` | Build otomatis via GitHub Actions, image tersimpan di GitHub |

Keduanya memakai `deploy.sh` yang sama. Detail mode B ada di [Memakai image dari GitHub Container Registry](#memakai-image-dari-github-container-registry).

## Deploy — mode A, build ke ECR

Dari root repository:

```bash
chmod +x deploy/deploy.sh deploy/teardown.sh
./deploy/deploy.sh
```

Script akan:

1. Membuat ECR repository `kiro-builder-lab` bila belum ada.
2. Build image untuk `linux/amd64`.
3. Push image dengan tag timestamp.
4. Deploy CloudFormation stack.
5. Menunggu service stabil, lalu mencetak URL.

Selesai, Anda akan melihat:

```text
Deployment complete.
  URL:     http://kiro-builder-lab-alb-123456789.ap-southeast-1.elb.amazonaws.com
  Image:   111122223333.dkr.ecr.ap-southeast-1.amazonaws.com/kiro-builder-lab:20260913120000
  Cluster: kiro-builder-lab-cluster
  Service: kiro-builder-lab-service
  Logs:    aws logs tail /ecs/kiro-builder-lab --follow --region ap-southeast-1
```

## Konfigurasi

Semua opsi lewat environment variable:

| Variable | Default | Keterangan |
|---|---|---|
| `PROJECT_NAME` | `kiro-builder-lab` | Prefix nama resource dan nama ECR repository. Maksimal 22 karakter karena batas nama ALB dan target group |
| `STACK_NAME` | sama dengan `PROJECT_NAME` | Nama CloudFormation stack |
| `AWS_REGION` | region CLI, fallback `ap-southeast-1` | Region tujuan |
| `IMAGE_URI` | kosong | Bila diisi, build dan push dilewati dan image ini dipakai apa adanya. Untuk GHCR, contoh `ghcr.io/owner/workshop-kiro:sha-abc123` |
| `REPOSITORY_CREDENTIALS_SECRET_ARN` | kosong | ARN Secrets Manager berisi `{"username","password"}`, hanya untuk registry privat |
| `IMAGE_TAG` | timestamp UTC | Tag image saat build ke ECR. Diabaikan bila `IMAGE_URI` diisi. ECR memakai tag immutable, jadi jangan memakai tag yang sama dua kali |
| `DESIRED_COUNT` | `2` | Jumlah task |
| `TASK_SIZE` | `256/512` | Ukuran task `CPU/memory`. Nilai valid: `256/512`, `256/1024`, `512/1024`, `512/2048`, `1024/2048`, `1024/4096` |
| `ALLOWED_CIDR` | `0.0.0.0/0` | CIDR yang boleh mengakses ALB |
| `CERTIFICATE_ARN` | kosong | ACM certificate ARN untuk HTTPS |
| `LOG_RETENTION_DAYS` | `14` | Retensi CloudWatch Logs |

Contoh:

```bash
AWS_REGION=ap-southeast-3 \
DESIRED_COUNT=2 \
TASK_SIZE=512/1024 \
ALLOWED_CIDR=203.0.113.0/24 \
./deploy/deploy.sh
```

`VpcCidr` tidak diekspos sebagai environment variable dan tetap `10.20.0.0/16`. Bila perlu mengubahnya, gunakan blok `/16` sampai `/22` karena template memotong empat subnet `/24` dari CIDR tersebut.

## Memakai image dari GitHub Container Registry

> **Penting.** Repository GitHub biasa **bukan** container registry. ECS tidak bisa menarik image dari URL file di repo, dari GitHub Releases, atau dari raw URL. Yang dipakai adalah **GitHub Container Registry (`ghcr.io`)**, yaitu registry OCI milik GitHub. Task definition ECS menerima referensi image dari registry mana pun, termasuk `ghcr.io`.

### 1. Publish image lewat GitHub Actions

Workflow `.github/workflows/publish-image.yml` sudah disiapkan. Ia berjalan otomatis di branch `main` ketika salah satu file berikut berubah: `index.html`, `styles.css`, `app.js`, `deploy/Dockerfile`, `deploy/nginx.conf`, `deploy/security-headers.conf`, `.dockerignore`, atau workflow itu sendiri. Mengubah `infrastructure.yaml`, `deploy.sh`, atau `teardown.sh` **tidak** memicu build karena tidak memengaruhi isi image. Workflow juga bisa dijalankan manual lewat **Actions → Publish container image to GHCR → Run workflow**.

Workflow memakai `GITHUB_TOKEN` bawaan dengan permission `packages: write`, jadi tidak perlu menyiapkan secret apa pun untuk proses push.

Hasilnya dua tag:

```text
ghcr.io/<owner>/<repo>:sha-<commit-sha>   ← immutable, pakai ini untuk ECS
ghcr.io/<owner>/<repo>:latest             ← mutable, hanya untuk kemudahan
```

Nama image selalu huruf kecil karena GHCR mewajibkannya. Referensi lengkap juga dicetak pada halaman ringkasan run.

### 2. Tentukan package public atau private

Package GHCR **default-nya private**. Ini menentukan apakah ECS butuh kredensial.

#### Opsi 2a — jadikan package public, paling sederhana

Buka **GitHub → repo → Packages → pilih package → Package settings → Change visibility → Public**.

Setelah itu ECS bisa menarik image tanpa kredensial sama sekali:

```bash
IMAGE_URI=ghcr.io/owner/workshop-kiro:sha-abc123 ./deploy/deploy.sh
```

Task tetap butuh jalan keluar ke internet untuk menjangkau `ghcr.io`. Stack ini sudah memakai `AssignPublicIp: ENABLED` di public subnet, jadi syarat itu terpenuhi.

#### Opsi 2b — package tetap private

ECS memerlukan kredensial registry yang disimpan di **AWS Secrets Manager**, lalu direferensikan lewat `repositoryCredentials` pada task definition. Template ini sudah mendukungnya.

Buat Personal Access Token GitHub dengan scope minimal **`read:packages`**, lalu simpan sebagai secret:

```bash
aws secretsmanager create-secret \
  --name ghcr-pull-credentials \
  --secret-string '{"username":"GITHUB_USERNAME","password":"GITHUB_PAT"}' \
  --region ap-southeast-1
```

Deploy dengan ARN secret tersebut:

```bash
IMAGE_URI=ghcr.io/owner/workshop-kiro:sha-abc123 \
REPOSITORY_CREDENTIALS_SECRET_ARN=arn:aws:secretsmanager:ap-southeast-1:111122223333:secret:ghcr-pull-credentials-AbCdEf \
./deploy/deploy.sh
```

Yang dilakukan template secara otomatis:

- Menambahkan `RepositoryCredentials.CredentialsParameter` pada container definition.
- Memberi execution role izin `secretsmanager:GetSecretValue` **hanya** untuk secret tersebut.

Catatan penting:

- Secret harus berada di **region yang sama** dengan task.
- Format nilai secret wajib JSON dengan key `username` dan `password`.
- Bila secret dienkripsi dengan **customer managed KMS key**, tambahkan izin `kms:Decrypt` pada key itu ke execution role. Dengan key bawaan Secrets Manager hal ini tidak diperlukan.
- Simpan PAT hanya di Secrets Manager. Jangan menaruhnya di task definition, environment variable, atau file repo.

### 3. Isi task definition

Bila Anda memakai `deploy.sh`, ini sudah otomatis. Bila Anda menulis task definition sendiri, bagian yang relevan hanya ini:

```json
{
  "containerDefinitions": [
    {
      "name": "web",
      "image": "ghcr.io/owner/workshop-kiro:sha-abc123",
      "repositoryCredentials": {
        "credentialsParameter": "arn:aws:secretsmanager:ap-southeast-1:111122223333:secret:ghcr-pull-credentials-AbCdEf"
      },
      "portMappings": [{ "containerPort": 8080, "protocol": "tcp" }],
      "essential": true
    }
  ]
}
```

Hapus blok `repositoryCredentials` bila package-nya public.

### 4. Pakai tag immutable, bukan `latest`

ECS membuat deployment baru ketika **task definition** berubah. Kalau `image` tetap `:latest`, isi tag boleh berubah di GHCR tetapi task definition tidak berubah, sehingga ECS tidak menarik ulang image. Gunakan `sha-<commit>` agar setiap perubahan konten menghasilkan revision baru dan rolling deployment berjalan. `deploy.sh` akan memberi peringatan bila Anda memakai `:latest`.

### Opsional: ECR pull-through cache untuk GHCR

ECR mendukung GHCR sebagai upstream pull-through cache. Dengan ini image tetap dibangun di GitHub, tetapi ECS menariknya dari ECR sehingga ketersediaan tidak bergantung pada GitHub saat task start dan tidak perlu egress ke internet bila memakai VPC endpoint. Ini opsi paling tahan gangguan untuk produksi, dengan tambahan satu komponen untuk dikelola. Lihat [ECR pull through cache](https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache.html).

### Mana yang sebaiknya dipakai

| Kebutuhan | Rekomendasi |
|---|---|
| Workshop, demo, cepat | GHCR public + tag `sha-` |
| Image tidak boleh publik | GHCR private + Secrets Manager |
| Produksi, minim dependensi eksternal | ECR, atau ECR pull-through cache dari GHCR |

## Mengaktifkan HTTPS

Tanpa sertifikat, guide disajikan lewat HTTP polos. Untuk workshop internal biasanya cukup, tetapi trafik tidak terenkripsi.

1. Terbitkan sertifikat ACM **di region yang sama** dengan stack.
2. Deploy ulang dengan ARN-nya:

```bash
CERTIFICATE_ARN=arn:aws:acm:ap-southeast-1:111122223333:certificate/abcd-1234 \
./deploy/deploy.sh
```

Port 80 otomatis redirect `HTTP 301` ke 443, dan listener 443 memakai policy `ELBSecurityPolicy-TLS13-1-2-2021-06`.

Untuk custom domain, arahkan CNAME atau Route 53 alias ke output `LoadBalancerDnsName`.

## Memperbarui konten guide

Mode A, build lokal ke ECR:

```bash
./deploy/deploy.sh
```

Mode B, image dari GHCR: push perubahan ke `main`, tunggu workflow selesai, lalu deploy dengan tag commit yang baru:

```bash
IMAGE_URI=ghcr.io/owner/workshop-kiro:sha-<commit-sha-baru> ./deploy/deploy.sh
```

Karena tag image selalu baru, ECS membuat task definition revision baru dan melakukan rolling deployment. Dengan `MinimumHealthyPercent: 100`, task lama tetap melayani trafik sampai task baru lulus health check. Bila deployment gagal, circuit breaker otomatis rollback.

## Logs dan troubleshooting

```bash
aws logs tail /ecs/kiro-builder-lab --follow --region ap-southeast-1
```

| Gejala | Penyebab umum |
|---|---|
| Target group `unhealthy` | Container gagal start. Cek log; pastikan nginx listen di 8080 dan `/healthz` menjawab 200 |
| Task berulang restart | Image tidak cocok arsitektur. Pastikan build memakai `--platform linux/amd64` |
| `CannotPullContainerError` | Task tidak bisa menjangkau registry. Pastikan `AssignPublicIp` masih `ENABLED` |
| `unauthorized` saat pull dari `ghcr.io` | Package masih private tanpa kredensial, PAT tidak punya scope `read:packages`, atau PAT sudah kedaluwarsa |
| Konten lama tetap tampil setelah push ke GitHub | Image memakai tag `latest`, jadi task definition tidak berubah. Deploy ulang dengan tag `sha-<commit>` |
| ALB balas `503` | Belum ada target sehat. Tunggu health check atau periksa `DesiredCount` |
| Halaman terbuka tapi navigasi modul mati | Aset `app.js` gagal dimuat, atau CSP diubah dan memblokir script |

Cek status service:

```bash
aws ecs describe-services \
  --cluster kiro-builder-lab-cluster \
  --services kiro-builder-lab-service \
  --region ap-southeast-1 \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount,deployments:deployments[0].rolloutState}'
```

## Perbandingan biaya

Angka kasar untuk gambaran, bukan kutipan resmi. Biaya aktual bergantung region, trafik, dan diskon.

| Opsi | Komponen berbayar | Karakter biaya |
|---|---|---|
| **Fargate + ALB** (setup ini) | ALB per jam + LCU, 2 task Fargate 24/7, ECR storage, CloudWatch Logs, Container Insights | Biaya tetap berjalan walau nol pengunjung. ALB sendiri biasanya komponen terbesar |
| **S3 + CloudFront** | Storage sangat kecil, request, data transfer | Mendekati nol saat idle; umumnya jauh lebih murah untuk situs statis |

Cara menekan biaya bila tetap memakai Fargate:

- `DESIRED_COUNT=1` untuk lingkungan non-produksi. Konsekuensinya tidak ada redundansi antar-AZ.
- Turunkan `LOG_RETENTION_DAYS`.
- Nonaktifkan Container Insights bila metrik tambahan tidak dipakai.
- Jalankan `teardown.sh` segera setelah workshop selesai.

Selalu verifikasi estimasi di [AWS Pricing Calculator](https://calculator.aws/).

## Hapus semua resource

```bash
./deploy/teardown.sh
```

Script meminta Anda mengetik nama stack sebagai konfirmasi, lalu menghapus stack beserta VPC, ALB, ECS cluster, dan log group. ECR repository sengaja dipertahankan. Untuk menghapusnya juga:

```bash
DELETE_ECR=true ./deploy/teardown.sh
```

> `DELETE_ECR=true` memakai `--force` dan menghapus seluruh image dalam repository. Tindakan ini tidak dapat dibatalkan.

## Catatan keamanan

Hal berikut disengaja, tetapi perlu Anda sadari sebelum dipakai di luar konteks workshop:

- **Tanpa autentikasi.** Guide adalah dokumen publik, jadi ALB melayani siapa pun yang cocok dengan `AllowedCidr`. Batasi CIDR atau tambahkan authentication di ALB bila materi tidak boleh publik.
- **HTTP polos secara default.** Aktifkan `CERTIFICATE_ARN` untuk enkripsi.
- **Task di public subnet.** Dipilih agar tidak perlu NAT gateway. Inbound tetap hanya dari ALB, tetapi task memiliki IP publik dan akses egress ke internet.
- **Access log ALB tidak diaktifkan.** Tambahkan bila Anda butuh audit trail permintaan.
- **CSP memakai `script-src 'unsafe-inline'`.** Diperlukan oleh script inline kecil di `index.html` yang menyetel class `js` sebelum render pertama.
- Container berjalan sebagai user non-root `uid 101` dan hanya mengekspos port 8080.
- ECR memakai `IMMUTABLE` tag dan `scanOnPush`, sehingga tag tidak bisa ditimpa diam-diam.
- **Kredensial GHCR privat hanya berada di Secrets Manager.** Execution role diberi `secretsmanager:GetSecretValue` terbatas pada satu ARN secret tersebut, bukan wildcard. PAT sebaiknya memakai scope minimum `read:packages` dan dirotasi berkala.
- **Image publik di GHCR dapat diunduh siapa pun.** Isi image ini hanya materi workshop statis, tetapi jangan memasukkan file rahasia ke build context. `.dockerignore` sudah mengecualikan `.git`, `.github`, `.kiro`, berkas markdown, dan seluruh isi `deploy/` kecuali dua file konfigurasi nginx yang memang disalin ke image.

## Isi folder

```text
deploy/
├── Dockerfile              # image nginx untuk situs statis
├── nginx.conf              # port 8080, /healthz, /favicon.ico 204, gzip, SPA fallback
├── security-headers.conf   # header keamanan, di-include tiap location
├── infrastructure.yaml     # CloudFormation: VPC, ALB, ECS, IAM, Logs
├── deploy.sh               # build, push ke ECR, deploy stack
├── teardown.sh             # hapus stack, opsional hapus ECR
└── README.md               # dokumen ini
```

Header keamanan sengaja dipisah ke `security-headers.conf` karena nginx tidak mewariskan `add_header` ke location yang mendeklarasikan `add_header` sendiri. Tanpa `include` di setiap location, CSP tidak akan terkirim pada dokumen HTML dan aset CSS/JS.
