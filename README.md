# RVA (Roads Voice Assistant)

**Roads Voice Assistant (RVA)** ir Flutter lietotne viedajiem braukšanas un navigācijas balss brīdinājumiem (ātruma ierobežojumi, vienvirziena ielas, bīstamas zonas).

## Galvenās iespējas

- **Latvijas PMTiles bezsaistes vektorkarte**: Tūlītēji un pilnībā bezsaistē nolasāmi ātruma ierobežojumu un vienvirziena ielu atribūti no OpenStreetMap `transportation` slāņa visai Latvijai.
- **Automātiska Overpass API tiešsaistes kļūmjpārlēce (Online Fallback)**: Ja bezsaistes kartes fails nav lejupielādēts, lietotne reāllaikā bez aiztures un ar viedo telpisko kešatmiņu iegūst datus caur Overpass API spoguļserveriem.
- **Balss brīdinājumi latviešu valodā**: Dabiska balss sintēze (`flutter_tts`) ar brīdinājumiem par atļautā ātruma pārsniegšanu, iebraukšanu vienvirziena ielās un ātruma zonu maiņu.
- **Fona GPS pakalpojums**: Spēja sekot līdzi braukšanai un sniegt brīdinājumus, kad lietotne darbojas fonā.
- **Kartes automatizācija ar GitHub Actions**: Ikmēneša automātisks darba process sagatavo un publicē jaunāko `latvia.pmtiles` failu GitHub Releases.

## Darba sākšana

1. Pārliecinies, ka ir uzstādīts Flutter SDK (`^3.13.4` vai jaunāks).
2. Iegūsti atkarības:
   ```bash
   flutter pub get
   ```
3. Palaid testus:
   ```bash
   flutter test
   ```
4. Palaid lietotni:
   ```bash
   flutter run
   ```
