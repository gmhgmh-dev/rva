# RVA (Roads Voice Assistant)

**Roads Voice Assistant (RVA)** ir Flutter lietotne viedajiem braukšanas un navigācijas balss brīdinājumiem (ātruma ierobežojumi, vienvirziena ielas, bīstamas zonas, dzīvojamās zonas, velo un gājēju ceļi).

## Galvenās iespējas

- **Latvijas PMTiles bezsaistes vektorkarte**: Tūlītēji un pilnībā bezsaistē nolasāmi ātruma ierobežojumu un vienvirziena ielu atribūti no OpenStreetMap `transportation` slāņa visai Latvijai.
- **Pielāgojami meklēšanas rādiusi ap lietotāju**: Lietotājs var iestatījumos ar slīdni vai tiešu skaitlisku ievadi pielāgot ielu piesaistes rādiusu (10–150 m, noklusējums: 40 m) un pagalmu/dzīvojamo zonu rādiusu (5–40 m, noklusējums: 15 m).
- **Gājēju un velosipēdu ceļu detekcija**: Balss paziņojumi, iebraucot uz velosipēdu vai gājēju ceļa ("Atrodaties uz velosipēdu ceļa."), ar automātisku atkārtošanās novēršanu (debounce) un vizuālu statusa indikatoru.
- **Krustojumu pret-spama aizsardzība**: 2 soļu histēreses filtrs un līpošā ceļa afinitāte, kas novērš viltus brīdinājumus par perpendikulāro šķērsielu pie īslaicīgām GPS nobīdēm krustojumos.
- **GPX testa braucienu simulācija**: Pilns atbalsts dažādiem GPX failiem (`trkpt`, `rtept`, `wpt`) ar lokālo PMTiles piesaisti, automātisku kodējumu atpazīšanu (UTF-8 / Latin-1) un failu metadatu indikāciju.
- **Dinamiskie ielu nosaukumi**: Balss paziņojumi nosauc konkrēto ielu pirms ātruma ierobežojuma, kā arī skaidri nošķir 30 km/h zonas kvartālu no parasta ielas posma.
- **Automātiska Overpass API tiešsaistes kļūmjpārlēce (Online Fallback)**: Ja bezsaistes kartes fails nav lejupielādēts, lietotne reāllaikā bez aiztures un ar viedo telpisko kešatmiņu iegūst datus caur Overpass API spoguļserveriem.
- **Balss brīdinājumi latviešu valodā**: Dabiska balss sintēze (`flutter_tts`) ar brīdinājumiem par atļautā ātruma pārsniegšanu, iebraukšanu vienvirziena ielās un ātruma zonu maiņu.
- **Fona GPS pakalpojums**: Spēja sekot līdzi braukšanai un sniegt brīdinājumus, kad lietotne darbojas fonā ar izslēgtu ekrānu.

## Darba sākšana

1. Pārliecinies, ka ir uzstādīts Flutter SDK (`^3.13.4` vai jaunāks).
2. Iegūsti atkarības:
   ```bash
   flutter pub get
   ```
3. Palaid testus (visi 50 vienībtesti):
   ```bash
   flutter test
   ```
4. Palaid lietotni:
   ```bash
   flutter run
   ```

## Versiju vēsture

Pilns izmaiņu un versiju saraksts atrodams failā [CHANGELOG.md](CHANGELOG.md).
- **Jaunākā relīze:** `v0.2.0` (2026-09-28)
- **Iepriekšējā versija:** `v0.1.0-stable`
