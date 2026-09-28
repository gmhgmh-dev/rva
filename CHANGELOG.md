# Changelog

Visas ievērojamākās izmaiņas projektā **RVA (Roads Voice Assistant)** tiek reģistrētas šajā failā.

Formāts balstīts uz [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) un seko [Semantiskajai Versijveidei (SemVer)](https://semver.org/).

---

## [0.2.0] - 2026-09-28

### Pievienots / Uzlabots (Added / Improved)
- **Ātruma pārsniegšanas brīdinājumu limiti un tolerances:**
  - Iestatījumos ieviesta lietotāja pielāgojama ātruma pārsniegšanas tolerance: **+0 km/h (stingrs)**, **+3 km/h**, **+5 km/h** vai **+10 km/h**.
  - Pielāgojams brīdinājuma atkārtošanas intervāls: **5s**, **10s**, **15s**, **30s** vai **tikai vienreiz**.
  - Iespēja ieslēgt opciju "Īss pīkstiens balss vietā", lai ātruma pārsniegšanas gadījumā atskaņotu tikai maigu skaņas signālu.
- **Lietotāja pielāgojami meklēšanas rādiusi (metri):**
  - Iestatījumos pievienota sadaļa ar slīdņiem un tiešu skaitlisku ievadi.
  - **Ielu meklēšanas rādiuss:** 10–150 m (ieteiktais noklusējums: **40 m**).
  - **Pagalmu un dzīvojamo zonu rādiuss:** 5–40 m (ieteiktais noklusējums: **15 m**).
  - Pievienota ātrā atiestatīšanas poga uz ieteiktajām noklusējuma vērtībām.
  - Novērš kļūdainu "pieķeršanos" paralēliem pagalmiem, braucot pa ielu 50 km/h.
- **Gājēju un velosipēdu ceļu detekcija un balss paziņojumi:**
  - Atpazīst velosipēdu un gājēju ceļus kartes datos.
  - Skaidri balss paziņojumi:
    - *"Atrodaties uz velosipēdu ceļa."*
    - *"Atrodaties uz gājēju ceļa."*
    - *"Atrodaties uz gājēju un velosipēdu ceļa."*
  - Ieviests slieksnis (debounce) pret nevajadzīgiem paziņojuma atkārtojumiem.
  - Ekrānā pievienota dinamiska vizuāla statusa birka (`Veloceļš` / `Gājēju ceļš`).
- **Krustojumu aizsardzība pret liekiem paziņojumiem:**
  - Daudzpakāpju apstiprināšanas filtrs novērš viltus brīdinājumus par perpendikulāro šķērsielu pie īslaicīgām GPS nobīdēm krustojumos.
  - Pašreizējā ceļa saglabāšanas afinitāte krustojuma šķērsošanas laikā.
- **GPX failu nolasīšanas un simulācijas atbalsts:**
  - Pilns atbalsts visiem standarta GPX maršrutu failiem.
  - Ātruma nolasīšana un automātiska m/s pārrēķināšana uz km/h.
  - Simulācijas punkti tiek piesaistīti lokālajai kartei pēc lietotāja iestatītajiem rādiusiem.
  - Testa maršrutu izvēlnē attēlots failu modifikācijas datums, laiks un faila izmērs.
- **Dinamiskie ielu nosaukumi un ātruma zonas:**
  - Dinamiska ielas nosaukuma paziņošana pirms ierobežojuma izrunāšanas ("Atrodaties uz [Ielas nosaukums]").
  - Dzīvojamo zonu (20 km/h) prioritāra atpazīšana un balss brīdinājums pagalmā esošam auto.
  - 30 km/h zonas kvartālu skaidra nošķiršana no parasta ielas posma.
  - Sākuma ielas un ātruma paziņošana balsī uzreiz pēc GPS signāla uztveršanas.
- **Droša arhitektūra un testēšana:**
  - Visi 50 vienībtesti un logrīku testi izpildās ar 100% panākumiem.

### Plānotie uzlabojumi
- [ ] Vairāku valodu atbalsts balss asistentam un saskarnei (EN/LV).
- [ ] Paplašināta bīstamo satiksmes punktu brīdināšana (dzelzceļa pārbrauktuves, fotoradari, bīstami krustojumi).
- [ ] Energoefektivitātes optimizācija ilgstošos starppilsētu braucienos.

---

## [0.1.0-stable] - 2026-09-26

### Pievienots (Added)
- **Reālā laika GPS izsekošana (`RealLocationService`):**
  - Android fona pakalpojums stabilai darbībai ar izslēgtu ekrānu.
  - Viedā telpiskā kešatmiņa ar tūlītēju atiestatīšanu, iebraucot vai izbraucot no ātruma zonām.
- **Bezsaistes vektorkartes dzinējs (`PMTilesService`):**
  - Tieša kartes nolasīšana ierīcē bez interneta pieslēguma.
  - Atbalsts atļautajam ātrumam, zonām, vienvirziena ielām un ielu nosaukumiem.
- **Tiešsaistes kļūmjpārlēce (Fallback):**
  - Automātiska datu iegūšana no tiešsaistes avotiem, ja bezsaistes karte nav lejupielādēta.
- **Kartes lejupielādētājs un iestatījumu ekrāns:**
  - Latvijas kartes lejupielāde tieši lietotnē, progresa indikācija, faila izmērs un datums.
- **Balss asistents:**
  - Balss brīdinājumi latviešu valodā par ātruma pārsniegšanu, zonu maiņu un vienvirziena ielām.
