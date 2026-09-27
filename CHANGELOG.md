# Changelog

Visas ievērojamākās izmaiņas projektā **RVA (Roads Voice Assistant)** tiek reģistrētas šajā failā.

Formāts balstīts uz [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) un seko [Semantiskajai Versijveidei (SemVer)](https://semver.org/).

---

## [0.2.0] - Izstrādē (In Progress)

### Plānotie uzlabojumi
- [ ] Vairāku valodu atbalsts balss asistentam un saskarnei (EN/LV).
- [ ] Paplašināta bīstamo satiksmes punktu brīdināšana (dzelzceļa pārbrauktuves, fotoradari, bīstami krustojumi).
- [ ] Energoefektivitātes optimizācija ilgstošos starppilsētu braucienos.
- [ ] Lietotāja pielāgojami brīdinājumu sliekšņi (brīdināt pie +3, +5 vai +10 km/h).

---

## [0.1.0-stable] - 2026-09-26

### Pievienots (Added)
- **Reālā laika GPS izsekošana (`RealLocationService`):**
  - Android fona pakalpojums ar `ForegroundNotificationConfig` un `enableWakeLock: true` stabilai darbībai ar izslēgtu ekrānu.
  - Viedā telpiskā kešatmiņa (30m / 15s) ar tūlītēju atiestatīšanu, iebraucot vai izbraucot no ātruma zonām.
- **Bezsaistes PMTiles vektorkartes dzinējs (`PMTilesService`):**
  - Tieša `latvia.pmtiles` nolasīšana ierīcē caur Web Mercator flīžu projekciju un līniju segmentu distanču aprēķinu.
  - Atbalsts `maxspeed`, `zone:maxspeed`, `source:maxspeed`, `oneway` un nosaukumu tagiem.
- **Tiešsaistes Overpass API kļūmjpārlēce (Fallback):**
  - Paralēli Overpass spoguļserveri ar ģeometrijas centru (`out center`) un drošības prioritizāciju samazināta ātruma posmiem (30 km/h, 20 km/h).
  - Ventspils un citu Latvijas pilsētu ceļu un pagalmu nosaukumu viedā atlase.
- **Kartes lejupielādētājs un iestatījumu ekrāns (`MapDownloaderService`, `SettingsScreen`):**
  - Latvijas kartes lejupielāde, progresa indikācija, faila izmēra un datuma attēlošana, faila dzēšana.
- **GitHub Actions automatizācija (`update_map.yml`):**
  - Ikmēneša automātiskā `latvia.pmtiles` ģenerēšana no Geofabrik ar `osmium` un `tippecanoe` un publicēšana GitHub Releases.
- **Balss asistents un stāvokļu mašīna (`VoiceAssistantStateMachine`, `FlutterTtsService`):**
  - Balss brīdinājumi latviešu valodā par ātruma pārsniegšanu, zonu maiņu un vienvirziena ielām.
