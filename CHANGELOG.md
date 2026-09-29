# Changelog

Visas ievērojamākās izmaiņas projektā **RVA (Roads Voice Assistant)** tiek reģistrētas šajā failā.

Formāts balstīts uz [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) un seko [Semantiskajai Versijveidei (SemVer)](https://semver.org/).

---

## [0.2.1] - 2026-09-29

### Pievienots / Uzlabots (Added / Improved)
- **Krustojumu pret-spama aizture (Ielas maiņas histerēze):**
  - Ieviests daudzpakāpju apstiprināšanas slieksnis (noklusējums: **4 punkti / ~4s**).
  - Asistents ziņo par jaunu ielu tikai tad, kad transportlīdzeklis reāli pārvietojas pa to vairākus secīgus GPS ciklus, pilnībā novēršot īslaicīgu šķērsielu spamu krustojumos (piem., Ganību/Kārļa iela).
- **Ātruma atcelšanas histerēze uz vienas ielas:**
  - Ieviests slieksnis (noklusējums: **4 punkti / ~4s**) pārejai no zemāka ātruma (30/20 km/h) atpakaļ uz 50 km/h tajā pašā ielā.
  - Pilnībā novērš 30 km/h un 50 km/h zonu mirgošanu ielās ar mainīgu ātrumu (piem., Sarkanmuižas dambis).
- **Vienvirziena ielas beigu aizture:**
  - Ieviests slieksnis (noklusējums: **3 punkti**) pirms paziņojuma *"Vienvirziena iela ir beigusies"*, novēršot viltus trauksmes krustojumu sadalījumos, kur uz mirkli nav `oneway` taga.
- **Starta GPS kešatmiņas filtrs:**
  - Noraida vēsturiskos GPS punktus no sistēmas keša (`getLastKnownPosition`), kuru vecums pārsniedz **5 sekundes**, un noraida punktus ar nepareizu hronoloģisko secību.
- **Veloceļu un ietvju prioritātes režīms:**
  - Pievienota opcija velosipēdu un skrejriteņu braucējiem prioritizēt paralēlos veloceļus un ietves $\le 20\text{ m}$ attālumā pār auto brauktuvēm.
- **Procentuālā ātruma tolerance:**
  - Papildus fiksētajai km/h tolerancei ieviests procentuālais režīms (piem., 5% vai 10% no ceļa atļautā ātruma).
- **Lietotnes iestatījumu sadaļa "GPS stabilitātes un krustojumu filtri":**
  - Katram stabilitātes un histerēzes parametram pievienots interaktīvs slīdnis, precīzas ciparu ievades dialogs un ātrā atiestatīšanas poga uz ieteikto noklusējumu.
- **Gemini Pro 3.1 koda audita un stabilitātes labojumi:**
  - **Wakelock akumulatora aizsardzība:** Ekrāna nomods tiek aktivizēts tikai tad, kad braukšanas asistents ir reāli palaists (`_mode != DriveMode.idle`), un automātiski atslēgts dīkstāvē.
  - **TTS rindas strupceļa (deadlock) novēršana:** `TtsService` tagad pārbauda `_flutterTts.speak()` rezultātu un atkopjas kļūdu vai atcelšanas gadījumā, neļaujot balss dzinējam uzkārties.
  - **Peldošā komata drošība ģeometrijas aprēķinos:** `lenSq < 1e-10` slieksnis novērš skaitlisku pārplūdi mikro-distanču dalīšanā.
  - **Iestatījumu vērtību robežkontrole (`clamping`):** Visi parametri no datu bāzes tiek droši ierobežoti atļautajos diapazonos.
- **Stāvēšanas filtrs pie luksofora un sastrēgumos (< 3.5 km/h):**
  - Bloķē ielu maiņu un vienvirziena pārslēgšanos GPS dreifa dēļ stāvošam transportlīdzeklim.
- **Kursa / braukšanas virziena (heading/bearing) filtrs krustojumos.**
- **Pārbaudīts ar 59 automatizētajiem testiem (100% pass rate).**

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
