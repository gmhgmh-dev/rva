# 🚗 RVA (Roads Voice Assistant)

[![Release](https://img.shields.io/github/v/release/gmhgmh-dev/rva?color=blue&label=Versija)](https://github.com/gmhgmh-dev/rva/releases)
[![Tests](https://img.shields.io/badge/Testi-69%20iziet%20(100%25)-brightgreen)](test/)
[![Platform](https://img.shields.io/badge/Platforma-Android-green)](https://developer.android.com)
[![Offline Maps](https://img.shields.io/badge/Kartes-PMTiles%20(Bezsaiste)-orange)](https://protomaps.com)
[![License](https://img.shields.io/badge/Licence-MIT-blue.svg)](LICENSE)

**Roads Voice Assistant (RVA)** ir vieds, autonoms braukšanas un mikromobilitātes balss asistents autovadītājiem, velobraucējiem un skrejriteņu lietotājiem. 

Lietotne sniedz savlaicīgus, lakoniskus balss paziņojumus par atļauto braukšanas ātrumu, ātruma zonām, fotoradariem, ātrumvaļņiem un veloceliņiem, **darbojoties pilnībā bezsaistē** un nenovēršot vadītāja uzmanību no ceļa.

---

## 🌟 Galvenās funkcijas lietotājam

### 🔊 1. Balss brīdinājumi un Audio Ducking (Mūzikas pieklusināšana)
- Skaidri, dabiski un lakoniski paziņojumi latviešu valodā par atļautā braukšanas ātruma pārsniegšanu, ielu maiņu, zonām un radariem.
- **Audio Ducking:** Automātiski pieklusina fona mūziku, radio vai navigācijas audio balss paziņojuma laikā un atjauno skaļumu uzreiz pēc tā pabeigšanas.
- **Ielas un ātruma nosaukšana:** Uzsākot braucienu vai iegriežoties jaunā ielā, asistents nosauc ielu un tās ātruma limitu (*"Atrodaties uz Jūras ielas. Atļautais ātrums 50 kilometri stundā"*).

### 🔭 2. Apsteidzošie brīdinājumi (Lookahead projekcija 50–100 m)
- Dinamiski projicē transportlīdzekļa trajektoriju braukšanas virzienā (~4.5 sekundes uz priekšu, 35–120 m).
- Savlaicīgi paziņo par gaidāmo 30 km/h vai dzīvojamo (20 km/h) zonu pirms iebraukšanas tajā (*"Uzmanību, priekšā 30 kilometru stundā zona"*).
- Brīdina par stacionārajiem **fotoradariem** un **ātrumvaļņiem** (*traffic_calming*) no bezsaistes kartes datiem.

### ⚙️ 3. Pielāgojami ātruma brīdinājuma sliekšņi un tolerances
- **Fiksētā tolerance:** Izvēlies brīdinājuma slieksni: **+0 km/h** (stingrs), **+3 km/h**, **+5 km/h** vai **+10 km/h**.
- **Procentuālā tolerance:** Iespēja pielāgot brīdinājuma slieksni procentos no atļautā ātruma (piem., 3% līdz 15%).
- **Brīdinājuma biežums:** Pielāgo atkārtošanās intervālu (5s, 10s, 15s, 30s vai tikai vienreiz).
- **Diskrētais režīms:** Iespēja ieslēgt maigu skaņas signālu (pīkstienu) balss brīdinājuma vietā.

### 🛡️ 4. Krustojumu histerēze un stabilitātes filtri
- **Virziena leņķa sods (12×) un esošās ielas afinitāte (0.15×):** Braucot taisni pāri krustojumam, perpendikulārās šķērsielas tiek stingri noraidītas par labu pašreizējai braukšanas ielai.
- **Krustojumu pret-spama aizture:** Daudzpakāpju apstiprinājums (noklusējumā **4 secīgi punkti / ~4s**). Paziņojums par jaunu ielu atskan tikai tad, kad transportlīdzeklis reāli turpina kustību pa to.
- **Ātruma atcelšanas aizture:** Novērš nevajadzīgu 30 km/h un 50 km/h mirgošanu ielās ar mainīgu ātrumu (piem., Sarkanmuižas dambī).
- **Vienvirziena ielas histerēze:** 3 punktu aizture pirms paziņojuma *"Vienvirziena iela ir beigusies"*.
- **Stāvēšanas filtrs (< 3.5 km/h):** Automašīnai apstājoties pie sarkanās gaismas vai sastrēgumā, asistents bloķē GPS dreifa radītās viltus ielu maiņas.
- **Starta GPS keša filtrs:** Automātiski atmet sistēmas saglabātās vēsturiskās koordinātas (> 5s vecas), nodrošinot pareizu starta ielas noteikšanu.

### 🚲 5. Gājēju un velosipēdu ceļu atbalsts
- Atpazīst veloceļus, gājēju ceļus un kopīgos gājēju/velo ceļus kartes datos ar balsi un vizuālu statusa indikatoru.
- **Velo prioritātes režīms:** Pārslēdzams režīms velobraucējiem un skrejriteņiem, kas prioritizē veloceļus un ietves pat tad, ja blakus atrodas automašīnu brauktuve.

### 🏡 6. Dzīvojamo zonu un pagalmu atpazīšana
- Automātiski atpazīst dzīvojamās zonas (20 km/h) un 30 km/h ātruma ierobežojuma kvartālus.
- Novērš kļūdainu "iekrišanu" pagalma brauktuvēs, braucot ar auto pa galveno ielu.

### 📏 7. Pielāgojami meklēšanas un pieķeršanās rādiusi
- Iestatījumos ar slīdņiem un ciparu ievadi iespējams brīvi regulēt:
  - **Ielu meklēšanas rādiuss:** 10–150 m (ieteicamais noklusējums: **40 m**).
  - **Pagalmu meklēšanas rādiuss:** 5–40 m (ieteicamais noklusējums: **15 m**).
  - **Lookahead skenēšanas bāzes distance:** 30–150 m (ieteicamais noklusējums: **70 m**).
- Visiem parametriem pieejamas ātrās atiestatīšanas pogas uz ieteiktajām vērtībām.

### 📦 8. Iestatījumu JSON pārvaldība un 1-klikšķa diagnostika
- Pilna lietotnes iestatījumu eksportēšana un importēšana JSON failos.
- Diagnostikas pakotnes eksports ar 1 pieskārienu (apvieno pēdējo GPX, trauksmju žurnālu `.log` un konfigurāciju `.json`).

### ℹ️ 9. Sadaļa "Par lietotni" (About)
- Pilna versijas informācija (`v0.2.1+3`), atvērtā koda pateicības (OpenStreetMap, PMTiles, Flutter), privātuma politika (100% lokāla un privāta bez ārējas izsekošanas) un tieša licenču apskate.

### 🗺️ 10. 100% Bezsaistes darbība (Offline-first)
- Lietotne izmanto modernu **PMTiles** vektorkaršu formātu (`latvia.pmtiles`).
- Ar vienu pieskārienu lejupielādē karti iestatījumos un izmanto asistentu bez interneta pieslēguma un bez mobilajiem datiem.

---

## 📲 Uzstādīšana un lietošana

1. Lejupielādē jaunāko instalācijas failu (`.apk`) no sadaļas [Releases](https://github.com/gmhgmh-dev/rva/releases).
2. Uzstādi to savā Android ierīcē (atļaujot nezināmu avotu instalāciju, ja nepieciešams).
3. Atver lietotni, dodies uz **Iestatījumiem** un lejupielādē Latvijas bezsaistes karti.
4. Ieslēdz GPS, nospied **"Sākt braucienu"** un dodies ceļā!

---

## 📊 Versiju vēsture

Pilns izmaiņu reģistrs pieejams [CHANGELOG.md](CHANGELOG.md).

- **v0.2.1** (2026-09-29): Audio Ducking, Lookahead apsteidzošie brīdinājumi, ātrumvaļņu un radaru detekcija, krustojumu leņķa filtri (12× sods), About ekrāns, JSON iestatījumu eksports/imports, 69 automatizētie testi (100% pass).
- **v0.2.0** (2026-09-28): Ātruma tolerances sliekšņi, velo/gājēju ceļi, GPX maršrutu simulācija un reāllaika žurnāli.
- **v0.1.0** (2026-09-25): Sākotnējais MVP ar bezsaistes PMTiles karti un pamata brīdinājumiem.
