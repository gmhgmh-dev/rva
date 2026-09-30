# Roads Voice Assistant (RVA) — Projekta pamatmērķis un vadlīnijas

## 🎯 Lietotnes misija un mērķauditorija
Lietotne ir radīta kā personīgais audio-asistents un atbalsts autovadītājiem un mikromobilitātes braucējiem (skrejriteņi, velosipēdi) ar **īstermiņa atmiņas grūtībām ("zelta zivtiņas atmiņu")**, uzmanības deficītu vai satraukumu pie stūres.

Šādiem cilvēkiem ir grūti paturēt prātā:
- Kāda ātruma ierobežojuma ceļa zīme tika šķērsota pirms brīža.
- Vai ātruma ierobežojums joprojām ir spēkā.
- Vai ceļa krustojums to ir atcēlis (Latvijas CSN krustojums atceļ ātruma ierobežojuma zīmi, taču vizuālas zīmes "ierobežojums atcelts" krustojumā nav).

---

## 🧭 Pamatprincipi, ko MI OBLIGĀTI ievēro visos algoritmos un izstrādē:

### 1. Skaidrība par ātruma statusu (kliedēt šaubas):
- Lietotājam **VIENMĒR** ir jābūt absolūtai skaidrībai par aktuālo statusu.
- Krustojumos un situācijās, kur beidzas ātruma ierobežojums, asistents **OBLIGĀTI paziņo, ka ierobežojums ir beidzies**, lai noņemtu lietotāja šaubas un trauksmi.

### 2. Inteliģentā apvienošana (Smart Fusion) bez liekvārdības:
- **Ielas nosaukuma dublēšanās aizliegums:** Vienā situācijā vai manevrā ielas nosaukumu **NENOSAUKT divreiz**.
- Saistītus notikumus apvienot **vienā sakarīgā, dabiskā teikumā**:
  - *Ierobežojuma beigas + pagrieziens uz jaunas ielas:*
    - **Paplašinātais stils:** `"Ātruma ierobežojums ir beidzies. Nogriezāties uz [Iela]."`
    - **Lakoniskais stils:** `"Ierobežojums beidzies. [Iela]."`
  - *30 Zonas beigas + pagrieziens uz jaunas ielas:*
    - **Paplašinātais stils:** `"Ātruma ierobežojuma zona ir beigusies. Nogriezāties uz [Iela]."`
    - **Lakoniskais stils:** `"Ātruma ierobežojuma zona ir beigusies. [Iela]."`
  - *Uz tās pašas ielas (beidzas posms bez pagrieziena):*
    - `"Ātruma ierobežojums ir beidzies. [Iela]."`
  - *Vienvirziena iela + ātruma ierobežojums:*
    - Apvienot vienā paziņojumā, piemēram: `"[Iela]. Vienvirziena, [ātrums] kilometri stundā."`

### 3. Mikromobilitātes dinamika (Speed-Adaptive):
- Lietotni aktīvi izmanto ne tikai auto, bet arī **skrejriteņi un velosipēdi** ($\le 25\text{ km/h}$).
- Pagrieziena un ielas maiņas apstiprinājumam jābūt adaptīvam:
  - Pie mazākiem ātrumiem ($\le 25\text{ km/h}$) reakcijai jābūt zibenīgai (15 metri un 2 punkti), lai paziņojums izskanētu tūlīt pēc krustojuma, nevis pēc 8 sekunžu aiztures.
  - Pie auto ātrumiem saglabāt drošu distanci pret šķērsielu spamu krustojumos.

### 4. Globālā pret-dublēšanās atmiņa:
- Ja kāds notikums (ātruma maiņa, zonas maiņa, dzīvojamā zona, vienvirziena iela) nupat ir nosaucis ielas nosaukumu, nākamie notikumi šajā pārejas posmā to pašu ielas vārdu nedrīkst atkārtot.

### 5. Bezsaistes darbība un stabilitāte:
- Visiem datiem un balss paziņojumiem jādarbojas 100% bezsaistē (PMTiles vektorkartes un lokālais TTS).
- Saglabāt augstu koda uzticamību — katrai izmaiņai jābūt pārklātai ar automatizētiem testiem.
