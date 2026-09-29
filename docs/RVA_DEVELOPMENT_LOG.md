# RVA (Roads Voice Assistant) – Hronoloģiskais Attīstības Žurnāls

> **Dokumenta statuss:** Lokāls projekta vēstures un arhitektūras lēmumu reģistrs  
> **Pēdējais atjauninājums:** 2026-09-28  
> **Konfidencialitāte:** Šis fails atrodas tikai Jūsu lokālajā datorā un nav publisks, kamēr netiek manuāli nosūtīts uz ārēju repozitoriju.

---

## 📌 Saturs un Sarunu Apvienotais Kopsavilkums

Šis dokuments konsolidē visu informāciju, tehniskos lēmumus un paveiktos soļus no 4 paralēlajām izstrādes sarunām Antigravity vidē:
1. **Saruna 1: `RVA beginnings`** (2026-09-25) – Lietotnes dzimšana un MVP
2. **Saruna 2: `RVA definition`** (2026-09-27) – Koncepcijas noformulēšana
3. **Saruna 3: `RVA main`** (2026-09-27 .. 2026-09-28) – Latvijas karšu bāze, reālie GPS testi, zonu loģika un Telegram tilts
4. **Saruna 4: `📱 Telegram Tilts`** (2026-09-27 .. 2026-09-28) – CI/CD labojumi, skrejriteņa GPX analīze, APK būvēšana un multi-sarunu vadība

---

## 🏛️ 1. Posms: Projekta Sākums un MVP (`RVA beginnings`)
**Laiks:** 2026. gada 25. septembris  
**Sarunas ID:** `0fd7a3ec-1412-43a1-b6bd-3ccc9f70a9c5`

### Galvenie lēmumi un paveiktais:
* **Ideja:** Izveidot Flutter Android balss asistentu, kas brīdina par satiksmes organizācijas elementiem Ventspilī bez nepieciešamības pastāvīgi skatīties ekrānā.
* **Arhitektūras izvēle:** Pāreja no statiskiem koordinātu masīviem uz **bezsaistes vektorkaršu risinājumu (PMTiles / OpenStreetMap)**.
* **Tehnoloģiju steks:**
  * Flutter / Dart (mobilā vide)
  * `flutter_tts` (balss sintēze latviešu valodā)
  * `geolocator` (precīza GPS koordinātu uztveršana)
  * PMTiles datu struktūra ātrai lokālai ceļu segmentu vaicāšanai bez interneta pieslēguma brauciena laikā.

---

## 📖 2. Posms: Projekta Definīcija un Mērķi (`RVA definition`)
**Laiks:** 2026. gada 27. septembris  
**Sarunas ID:** `24cc787e-451f-4801-8a72-7b4232eec340`

### Definētā identitāte:
* **Nosaukums:** **RVA** (*Roads Voice Assistant*).
* **Mērķis:** Vieds, pilnībā autonoms ceļu balss asistents autovadītājiem, velobraucējiem un mikromobilitātes (skrejriteņu) lietotājiem.
* **Principi:**
  * *Privātums vispirms:* Visi GPS dati un apstrāde notiek lokāli ierīcē.
  * *Bezsaistes darbība:* Lietotne funkcionē mežos, lauku ceļos un vietās ar vāju mobilo pārklājumu.
  * *Minimāla uzmanības novēršana:* Informācija tiek nodota ar lakoniskiem balss paziņojumiem.

---

## 🚀 3. Posms: Latvijas Karšu Bāze un Reālie Braucienu Testi (`RVA main`)
**Laiks:** 2026. gada 27. – 28. septembris  
**Sarunas ID:** `c7cf01b3-8460-406c-be30-6108c1e08d89`

### Galvenie tehniskie lēmumi un risinājumi:
1. **Mērogošana no Ventspils uz visu Latviju:**
   * Ieviesta `latvia.pmtiles` karte, kas nodrošina asistentu visā valsts teritorijā.
   * Izveidots fona lejupielādes un kešošanas mehānisms ar integritātes pārbaudi.
2. **Pirmais reālais GPS lauka tests (Sarkanmuižas dambis -> Katoļu/Rīgas iela):**
   * Lietotājs veica reālu braucienu Ventspilī.
   * *Problēma:* GPS sākumā rādīja vispārīgu nosaukumu "Iela", un daži paziņojumi pārtrūka.
   * *Labojums:* Uzlabota ielu nosaukumu atpazīšana no OSM atribūtiem (`name`, `name:lv`).
3. **Zonu atpazīšanas loģika:**
   * **Dzīvojamās zonas (20 km/h):** Paziņojums iebraucot un izbraucot (`highway=living_street`).
   * **30 km/h zonas:** Atpazīšana un balss paziņojumi gan ielu posmiem, gan zonu zīmēm.
   * **Ātruma pārsniegšanas brīdinājumi:** Sliekšņa brīdinājumi, ja ātrums pārsniedz atļauto.
4. **Build un Versiju Automatizācija:**
   * Ieviesta v0.2.0 versiju numerācija.
   * APK failu nosaukumu automātiska marķēšana ar datumu, laiku un Git hešu (`rva-v0.2.0-YYYYMMDD-HHMM-HASH.apk`).
5. **Telegram Tilts v1 (`scripts/telegram_bridge.py`):**
   * Izveidots divvirzienu tilts, lai lietotājs no viedtālruņa caur Telegram varētu vadīt Antigravity aģentu, pieprasīt būvējumus un saņemt APK failus.

---

## 🔧 4. Posms: CI/CD Stabilitāte, Skrejriteņa Analīze un Pārslēdzējs (`📱 Telegram Tilts`)
**Laiks:** 2026. gada 27. – 28. septembris  
**Sarunas ID:** `ba37eab0-900a-4e87-b99b-aaf6179bd2f5`

### Paveiktais:
1. **Skrejriteņa testa brauciena datu analīze:**
   * Lietotājs atsūtīja reālu testa braucienu ar skrejriteni pa Ventspili (GPX fails un brīdinājumu žurnāls).
   * *Konstatēts:* Braucot pa ietvēm un gājēju celiņiem krustojumu tuvumā, asistents brīžiem pārāk strauji mainīja piesaistītās ielas (Sinagogas -> Platā -> Saules).
   * *Secinājums:* Nepieciešama kustības virziena (azimuta/heading) svēršana un histerēze (15–20m distance) pirms ielas maiņas paziņošanas.
2. **Lietotnes iekšējā funkcija "Testa brauciens":**
   * Pievienota poga un GPX atskaņotājs lietotnes saskarnē, kas ļauj simulēt un atkārtot reālus braucienus kabinetā bez fiziskas braukšanas.
3. **Žurnālu rakstīšanas sinhronizācija:**
   * Novērsta asinhrono paziņojumu rindu pārklāšanās failā `alerts_*.log`.
4. **GitHub Actions CI/CD pilnīga stabilizācija:**
   * Atrisināta CMake 3.22.1 atkarības kļūda Ubuntu vidē.
   * Novērsta Keystore base64 atkodēšanas kļūda, aizvietojot `tr` ar Python bāzētu atkodēšanu.
   * Ieviesta *pre-flight* Keystore pārbaude: atklāts, ka GitHub noslēpumā bija iekopēts nepilnīgs atslēgas fails (2064 baiti 2760 vietā), izveidota droša pāreja uz rezerves parakstīšanu.
   * **Rezultāts:** Būvējums #36347670512 veiksmīgi saražoja gatavu 54.7 MB `app-release.apk`.
5. **Telegram Tilta Uzlabojumi (Multi-sarunu vadība):**
   * Pievienota komanda `/sarunas` (`/chats`) ar interaktīvām Telegram pogām, kas nolasa Antigravity saskarnes sarunas no `conversation_summaries.db`.
   * Pievienota zibenīga pārslēgšanās ar pogas spiedienu vai `/switch <numurs>`.
   * Pievienota iespēja uzsākt jaunas sarunas ar pasūtītu nosaukumu: `/new <nosaukums>` vai `/jauna <nosaukums>`.

---

## 🛡️ 5. Posms: Krustojumu Histerēze, Stabilitātes Filtri un Gemini Pro 3.1 Audits
**Laiks:** 2026. gada 28. – 29. septembris  
**Sarunas ID:** `c7cf01b3-8460-406c-be30-6108c1e08d89`

### Paveiktais un Tehniskie Risinājumi:
1. **Reālo braucienu (GPX un Alert Log) analīze:**
   * Detalizēti analizēti Ventspils braucieni pa Ganību, Kārļa ielu un Sarkanmuižas dambi.
   * Identificēts un atrisināts krustojumu spams un ātruma robežu 30/50 km/h mirgošana uz vienas ielas.
2. **Histerēzes un apstiprinājumu filtru ieviešana:**
   * **Krustojumu pret-spama aizture:** Jauna iela tiek izziņota tikai pēc 4 secīgiem apstiprinājumiem (~4s).
   * **Ātruma atcelšanas aizture:** 4 apstiprinājumu aizture pārejai atpakaļ uz 50 km/h tajā pašā ielā.
   * **Vienvirziena ielas beigu aizture:** 3 apstiprinājumu aizture pirms paziņojuma atskaņošanas.
   * **Starta GPS keša filtrs:** Noraida punktus ar laika nobīdi > 5s vai apgrieztu hronoloģiju.
   * **Veloceļu un ietvju prioritāte:** Iespēja velosipēdu/skrejriteņu braucieniem pieķerties paralēlām ietvēm/veloceļiem $\le 20\text{ m}$ attālumā.
3. **Lietotnes Iestatījumu ekrāna paplašināšana:**
   * Ieviesta sadaļa *"GPS stabilitātes un krustojumu filtri"* ar slīdņiem, ciparu ievades dialogiem un atiestatīšanas pogām.
4. **Padziļinātais Koda Audits ar Gemini Pro 3.1 High:**
   * **Wakelock akumulatora noplūde:** Ekrāna nomods tiek turēts TIKAI aktīva brauciena laikā, novēršot baterijas tērēšanu dīkstāvē.
   * **TTS rindas strupceļš (deadlock):** Pievienota statusa koda pārbaude `_flutterTts.speak()`, novēršot asistenta apklusšanu pie kļūmes.
   * **Peldošā komata drošība:** Novērsta dalīšana ar nulli mikro-distancēs (`lenSq < 1e-10`).
   * **Iestatījumu drošā apcirpšana (clamping):** Robežu pārbaude visiem no datu bāzes lasītajiem skaitļiem.
5. **Kvalitātes kontrole:**
   * Visi **59 automatizētie testi** (vienībtesti, integrācijas un UI) sekmīgi izturēti ar 100% caurlaidību.
   * Veiksmīgi sakompilēti un caur Telegram piegādāti atjauninātie Release APK būvējumi.

---

## 🎯 Pašreizējā Arhitektūra un Vienošanās (Single Source of Truth)

| Modulis | Tehnoloģija / Risinājums | Pašreizējais Statuss |
| :--- | :--- | :--- |
| **Ietvars** | Flutter 3.x / Dart | Stabils |
| **Kartes Dati** | PMTiles (`latvia.pmtiles`) | Lokāla kešošana un vaicāšana ar azimuta filtriem |
| **Balss Sintēze** | `flutter_tts` (LV valoda) | Droša rinda ar kļūdu atkopšanu |
| **Histerēze & Filtri** | `VoiceAssistantStateMachine` | Krustojumu, ātruma un vienvirziena aizture |
| **Iestatījumi** | `SettingsService` & UI | Pilna parametru kontrole un atiestatīšana |
| **Braucienu Ieraksts** | GPX un alert žurnāli | Sinhronizēts ar rindu |
| **CI/CD** | GitHub Actions (`build-apk.yml`) | 100% strādājošs, ģenerē artefaktus |
| **Attālinātā Vadība** | Telegram Tilts (`telegram_bridge.py`) | Aktīvs ar `/sarunas`, ConnectRPC tiešo saziņu |
