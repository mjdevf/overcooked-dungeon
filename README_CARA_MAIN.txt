OVERCOOKED DUNGEON - cara main (Windows)
==========================================

1. BUKA PROJECT
   - Extract D:\Godot\Godot_v4.7.2-stable_win64.exe.zip, buka exe (Godot 4.7.2).
   - Import > D:\overcooked-dungeon\project.godot > Import & Edit.
   - Tunggu import (sekali saja), tekan F5. Main scene: scenes/main.tscn.

2. KONSEP (satu bangunan, dua sisi)
   KIRI = dapur (area kamu). KANAN = ruang makan (area NPC).
   Penghubung cuma 2 konter di dinding pembatas: jendela ANTAR dan KASIR otomatis.
   Warna lantai: COKLAT = area bahan, MERAH = area masak, BIRU = ruang makan.

3. KONTROL (keyboard + gamepad Xbox/PS — colok sebelum buka game)
   WASD / Panah / Stick / D-pad : gerak (kamera isometric 2.5D, fixed)
   Shift / B    : dash / lari cepat (tahan)
   E / Spasi / A: interaksi ke station yang DIHADAP (ada ring kuning + label kuning).
                  TAHAN untuk mencincang di talenan & mencuci di wastafel.
   Q / Y        : rekrut bot helper (50 poin, maks 2). Full auto: ambil bahan,
                  cincang, rakit ke piring sesuai order, antar. Sisa bahan di
                  talenan langsung diteruskan (tidak perlu dibereskan dulu);
                  barang yang bukan bagiannya tidak disentuh. Label di atas
                  kepala nunjukin kerjaan bot saat ini. Tiket order yg diklaim
                  bot ada prefix "Bot →".
   Esc / Start  : pause (timer & kompor ikut berhenti)
   Prompt bawah layar nunjukin tombol ([E]/[A]) sesuai device terakhir dipakai.

4. CARA MASAK
   Alur melingkar (searah jarum jam): crate (kiri) > talenan (kiri atas) >
   kompor (atas) > meja plating + rak piring (kanan) > jendela ANTAR (kanan bawah).
   - Salad: tomat+selada cincang (TAHAN E di talenan ~3 dtk).
   - Roti Lapis (L2+): roti langsung + tomat cincang. Roti/keju siap saji.
   - Burger Keju (L3): roti + keju + selada cincang.
   - Tumis: cincang dulu, lalu masak di kompor ~6 dtk. Dibiarkan +8 dtk = GOSONG,
     buang di sampah. Piring gosong tidak bisa disaji.
   - KEBAKARAN: gosong dibiarkan +6 dtk = kompor KEBAKARAN (skor bocor -2/dtk,
     kompor terkunci). Ambil APAR di meja merah sudut dapur barat, tekan E di
     kompor api untuk padamkan. Bot juga bisa masak & memadamkan sendiri.
   L2/L3 ada event RUSH HOUR (NPC datang bergerombol).
   Rakit di meja plating (piring kosong sudah tersedia di atasnya) : tambah
   bahan satu-satu > bawa ke ANTAR, tekan E: cocok = piring terbang ke meja NPC; salah = ditolak.
   NPC makan 5-8 dtk > bayar + tip kalau cepat > pulang. Order hangus = NPC
   ngamuk, skor -20. Sampah: bahan hilang, piring isi dikembalikan bersih.

5. NPC & KASIR
   NPC masuk pintu > antre (maks 3) > pesan di kasir (kursi auto-reserve) >
   duduk > makan > bayar + tip kalau cepat > pulang.
   Order hangus (patience habis) = NPC ngamuk pergi, skor -20.
   NPC baru cuma datang kalau ada kursi bebas.

6. LEVEL
   L1 Dapur Latihan (salad, NPC pelan) | L2 Ruang Rame (+sandwich) | L3 Rush Hour (+burger, cepat).
   Best score + bintang per level tersimpan otomatis.

7. ASET LUAR (CC0 Kenney, sudah dipakai game, lihat assets_external\CARA_PAKAI_ASET.txt)
   Kalau mau project ringan: hapus folder FBX/OBJ/DAE/STL & .zip (sisakan "GLB format").

Troubleshoot:
- F5 error "no main scene": Project Settings > Application > Run > Main Scene = res://scenes/main.tscn
- Label station cuma muncul kalau player dekat (<=2.6m) — normal, biar tidak tumpuk.
- Import pertama 2-5 menit karena ratusan GLB — normal, sekali saja.
