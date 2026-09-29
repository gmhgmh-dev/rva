# Changelog

Visas ievērojamākās izmaiņas projektā **RVA (Roads Voice Assistant)** tiek reģistrētas šajā failā.

Formāts balstīts uz [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) un seko [Semantiskajai Versijveidei (SemVer)](https://semver.org/).

---

## [0.2.1] - 2026-09-29

### Pievienots / Uzlabots (Added / Improved)
- **Audio Ducking (Mūzikas pieklusināšana):**
  - Integrēts `AudioDuckingService` ar Android `AudioManager` un `AudioFocusRequest` (`AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`).
  - Automātiski pieklusina automašīnas radio, Spotify, YouTube Music vai citas multivides lietotnes balss paziņojuma laikā un atjauno pilnu skaļumu pēc tā beigām.
  - Pievienots pārslēgšanas slēdzis lietotnes iestatījumos (`Mūzikas pieklusināšana (Audio ducking)`).
- **Apsteidzošā ātruma zonu noteikšana (Lookahead projekcija 50–100 m):**
  - Dinamisks lookahead koordinātu aprēķins (`calculateLookaheadCoordinate`, `calculateDynamicLookaheadDistance`) atkarībā no braukšanas ātruma (~4.5 sekundes uz priekšu, 35–120 m).
  - Savlaicīgi paziņo par gaidāmo 30 km/h vai dzīvojamo (20 km/h) zonu pirms iebraukšanas tajā (*"Uzmanību, priekšā 30 kilometru stundā zona"*).
  - Iestatījumos pieejams slēdzis un pielāgojams bāzes distances slīdnis (30–150 m, noklusējums: **70 m**).
- **Ātrumvaļņu (traffic_calming) un fotoradaru bezsaistes brīdinājumi:**
  - Bezsaistes PMTiles MVT datu slāņa paplašinājums ar `traffic_calming` (guļošie policisti, paaugstinātās pārejas) un stacionāro fotoradaru detekciju.
  - Balss brīdinājumi: *"Uzmanību, priekšā ātrumvalnis"*, *"Uzmanību, priekšā fotoradars [X] km/h"*.
  - Pārslēdzami iestatījumos ar slēdžiem.
- **Krustojumu virziena leņķa sods ($12\times$) un afinitāte ($0.15\times$):**
  - $12\times$ virziena leņķa sods perpendikulārām šķērsielām ($> 55^\circ$) un $0.15\times$ afinitāte pašreizējai braukšanas ielai.
  - Pilnībā novērš viltus pārslēgšanos uz šķērsielām, šķērsojot krustojumus (piem., Katoļu/Jūras iela, Ganību/Kārļa iela).
- **Krustojumu pret-spama aizture (Ielas maiņas histerēze):**
  - Ieviests daudzpakāpju apstiprināšanas slieksnis (noklusējums: **4 punkti / ~4s**).
  - Asistents ziņo par jaunu ielu tikai tad, kad transportlīdzeklis reāli pārvietojas pa to vairākus secīgus GPS ciklus.
- **Ātruma atcelšanas histerēze uz vienas ielas:**
  - Ieviests slieksnis (noklusējums: **4 punkti / ~4s**) pārejai no zemāka ātruma (30/20 km/h) atpakaļ uz 50 km/h tajā pašā ielā.
  - Novērš 30 km/h un 50 km/h zonu mirgošanu ielās ar mainīgu ātrumu (piem., Sarkanmuižas dambis).
- **Vienvirziena ielas beigu aizture:**
  - Ieviests slieksnis (noklusējums: **3 punkti**) pirms paziņojuma *"Vienvirziena iela ir beigusies"*.
- **Starta GPS kešatmiņas filtrs:**
  - Noraida vēsturiskos GPS punktus no sistēmas keša (`getLastKnownPosition`), kuru vecums pārsniedz **5 sekundes**, un noraida punktus ar nepareizu hronoloģisko secību.
- **Veloceļu un ietvju prioritātes režīms:**
  - Pievienota opcija velosipēdu un skrejriteņu braucējiem prioritizēt paralēlos veloceļus un ietves $\le 20\text{ m}$ attālumā pār auto brauktuvēm.
- **Procentuālā ātruma tolerance:**
  - Papildus fiksētajai km/h tolerancei ieviests procentuālais režīms (3% līdz 15% no ceļa atļautā ātruma).
- **Konfigurācijas pārvaldība (JSON Eksports / Imports) un 1-klikšķa diagnostika:**
  - Iespēja eksportēt un importēt visus lietotnes parametrus `.json` failā.
  - Poga diagnostikas pakotnes nosūtīšanai (apvieno pēdējo GPX, trauksmju `.log` un konfigurāciju `.json`).
- **Sadaļa "Par lietotni" (About Screen):**
  - Jauns ekrāns ar pilnu versijas numuru (`v0.2.1+3 (Build 3)`), būvējuma datiem, funkciju pārskatu, OpenStreetMap / PMTiles licencēm un 100% bezsaistes privātuma garantiju.
  - Piekļuve no galvenā ekrāna AppBar `(i)` ikonas un no Iestatījumu saraksta apakšas.
- **Gemini Pro 3.1 koda audita un stabilitātes labojumi:**
  - **Wakelock akumulatora aizsardzība:** Ekrāna nomods tiek aktivizēts tikai aktīva brauciena laikā (`_mode != DriveMode.idle`).
  - **TTS rindas strupceļa (deadlock) novēršana:** Automātiska atkopšanās no dzinēja aiztures.
  - **Peldošā komata drošība:** `lenSq < 1e-10` slieksnis novērš skaitlisku pārplūdi mikro-distanču dalīšanā.
  - **Iestatījumu vērtību robežkontrole (`clamping`).**
  - **Stāvēšanas filtrs pie luksofora (< 3.5 km/h).**
- **Testēšana:** Visi **69 automatizētie testi** izpildās ar 100% panākumiem.

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
- **Gājēju un velosipēdu ceļu detekcija un balss paziņojumi:**
  - Atpazīst velosipēdu un gājēju ceļus kartes datos.
  - Ekrānā pievienota dinamiska vizuāla statusa birka (`Veloceļš` / `Gājēju ceļš`).
- **GPX failu nolasīšanas un simulācijas atbalsts:**
  - Pilns atbalsts standarta GPX maršrutu failiem ar ātruma nolasīšanu un piesaisti bezsaistes kartei.
- **Dinamiskie ielu nosaukumi un ātruma zonas:**
  - Dinamiska ielas nosaukuma paziņošana pirms ierobežojuma izrunāšanas ("Atrodaties uz [Ielas nosaukums]").
  - Dzīvojamo zonu (20 km/h) prioritāra atpazīšana un balss brīdinājums pagalmā esošam auto.
  - Sākuma ielas un ātruma paziņošana balsī uzreiz pēc GPS signāla uztveršanas.

---

## [0.1.0-stable] - 2026-09-26

### Pievienots (Added)
- **Reālā laika GPS izsekošana (`RealLocationService`):**
  - Android fona pakalpojums stabilai darbībai ar izslēgtu ekrānu.
  - Viedā telpiskā kešatmiņa ar tūlītēju atiestatīšanu, iebraucot vai izbraucot no ātruma zonām.
- **Bezsaistes vektorkartes dzinējs (`PMTilesService`):**
  - Tieša kartes nolasīšana ierīcē bez interneta pieslēguma (`latvia.pmtiles`).
- **Kartes lejupielādētājs un iestatījumu ekrāns:**
  - Latvijas kartes lejupielāde tieši lietotnē, progresa indikācija, faila izmērs un datums.
- **Balss asistents:**
  - Balss brīdinājumi latviešu valodā par ātruma pārsniegšanu, zonu maiņu un vienvirziena ielām.
