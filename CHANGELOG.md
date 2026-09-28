# Changelog

Visas ievērojamākās izmaiņas projektā **RVA (Roads Voice Assistant)** tiek reģistrētas šajā failā.

Formāts balstīts uz [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) un seko [Semantiskajai Versijveidei (SemVer)](https://semver.org/).

---

## [0.2.0] - 2026-09-28

### Pievienots / Uzlabots (Added / Improved)
- **Lietotāja pielāgojami meklēšanas rādiusi (metri):**
  - Iestatījumos pievienota jauna sadaļa ar plūstošiem slīdņiem un tiešu skaitlisku ievadi (`_buildRadiusTile`).
  - **Ielu meklēšanas rādiuss:** 10–150 m (ieteiktais noklusējums: **40 m**).
  - **Pagalmu un dzīvojamo zonu rādiuss:** 5–40 m (ieteiktais noklusējums: **15 m**).
  - Pievienota tūlītēja atiestatīšanas poga uz ieteiktajām vērtībām.
  - Novērš kļūdainu "pieķeršanos" paralēliem pagalmiem, braucot pa ielu 50 km/h.
- **Gājēju un velosipēdu ceļu detekcija un balss paziņojumi:**
  - OpenStreetMap atribūtu nolasīšana (`cycleway`, `footway`, `pedestrian`, `path`, `bicycle=designated`, `foot=designated`).
  - Skaidri balss paziņojumi:
    - *"Atrodaties uz velosipēdu ceļa."*
    - *"Atrodaties uz gājēju ceļa."*
    - *"Atrodaties uz gājēju un velosipēdu ceļa."*
  - Ieviests debounce/sliekšņa mehānisms pret nevajadzīgiem atkārtojumiem.
  - Informācijas panelī pievienota dinamiska statusa birka (`Veloceļš` / `Gājēju ceļš`).
- **Krustojumu pret-spama aizsardzība:**
  - 2 soļu histēreses filtrs `VoiceAssistantStateMachine`: viena punkta GPS trokšņi uz perpendikulārām ielām tiek nofiltrēti.
  - Līpošā ielas afinitāte (0.35x attāluma reizinātājs) `PMTilesService`, lai krustojumos saglabātu esošo ielu.
- **GPX failu nolasīšanas un simulācijas dzinējs:**
  - Pilns atbalsts visiem GPX formātiem: `<trkpt>`, `<rtept>`, `<wpt>`.
  - Ātruma nolasīšana no `<desc>` (`Iela: ...`, `Atļauts: ... km/h`, `Reāls: ... km/h`) un standarta `<speed>` tagiem (ar m/s konversiju uz km/h).
  - Universāls kodējumu atbalsts (`UTF-8` un `Latin-1` atkāpšanās).
  - Simulācijas punktu dinamiska piesaiste lokālajai PMTiles vektorkartei pēc lietotāja norādītajiem rādiusiem.
  - Testa maršrutu izvēlnē redzams failu modifikācijas datums, laiks un faila izmērs (KB).
- **Dinamiskie ielu nosaukumi un ātruma zonas:**
  - Dinamiska ielas nosaukuma paziņošana pirms brīdinājumiem ("Atrodaties uz [Ielas nosaukums]").
  - Dzīvojamo zonu (`highway=living_street` / 20 km/h) prioritāra atpazīšana un balss brīdinājums pagalmā esošam auto.
  - 30 km/h zonas (ielu kvartāls / ceļa zīme 521/522) skaidra nošķiršana no parasta ielas posma ar 30 km/h ierobežojumu (ceļa zīme 323).
  - Sākuma ielas un ātruma paziņošana balsī uzreiz pēc GPS signāla uztveršanas.
- **Droša arhitektūra un testēšana:**
  - Visi 50 unit un widget testi izpildās ar 100% panākumiem.
  - Keystore pārbaudes skripts un debug kļūmjpārlēce CI/CD procesā.

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
