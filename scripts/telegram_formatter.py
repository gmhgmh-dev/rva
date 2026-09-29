import re

def format_for_telegram(text: str) -> str:
    """
    Pārveido Antigravity Markdown atbildi vizuāli pievilcīgā Telegram formātā:
    - Aizstāj garās file:/// saites ar tīriem failu nosaukumiem
    - Pārveido virsrakstus un numerāciju uz izteiksmīgiem emoji (1️⃣, 2️⃣, 📋, 📦, 💡, 📊)
    - Pārveido sarakstu zīmes (- un *) uz glītiem punktiem (•)
    - Pielāgo Markdown treknrakstu Telegram atbalstam (*treknraksts*)
    - Pievieno statusa ikonu (✅, 🎉) paziņojuma sākumā, ja trūkst
    """
    if not text:
        return text

    # 1. Notīrām file:/// saites: [Label](file:///...) -> `Label`
    text = re.sub(
        r'\[(`?[^\]]+`?)\]\(file:///[^\)]+\)',
        lambda m: m.group(1) if m.group(1).startswith('`') else f'`{m.group(1)}`',
        text
    )
    # Notīrām jebkuras atlikušās (file:///...) iekavas
    text = re.sub(r'\(file:///[^\)]+\)', '', text)

    emoji_nums = {
        '1': '1️⃣', '2': '2️⃣', '3': '3️⃣', '4': '4️⃣', '5': '5️⃣',
        '6': '6️⃣', '7': '7️⃣', '8': '8️⃣', '9': '9️⃣', '10': '🔟'
    }

    category_emojis = [
        (r'(veikt[āa]s darb[īi]bas|uzdevumi|pl[āa]ns)', '📋'),
        (r'(kopsavilkums|rezult[āa]t|atskaite)', '📊'),
        (r'(secin[āa]jum|risin[āa]jum|ieteikum)', '💡'),
        (r'(kompil[āa]cija|b[ūu]v[ēe]jum|rel[īi]ze|pakotne|pieg[āa]de)', '📦'),
        (r'(test[ēe]|p[āa]rbaud)', '🧪'),
        (r'(br[īi]din[āa]jum|uzman[īi]bu|k[ļl][ūu]da)', '⚠️'),
        (r'(labojum|izmai[ņn]as)', '🛠️'),
        (r'(github|git)', '🐙'),
        (r'(svar[īi]gi|atcerieties)', '⚡'),
        (r'(info|inform[āa]cija)', 'ℹ️'),
    ]

    lines = text.split('\n')
    formatted_lines = []

    for line in lines:
        stripped = line.strip()

        # Noņemam Markdown horizontālās līnijas (---)
        if stripped in ('---', '***', '___'):
            formatted_lines.append('')
            continue

        # Virsraksti: #, ##, ###, ####
        header_match = re.match(r'^(#{1,4})\s+(.*)', stripped)
        if header_match:
            h_text = header_match.group(2).strip()
            
            # Pārbaudām, vai virsraksts sākas ar ciparu: "### 1. Virsraksts"
            num_match = re.match(r'^(\d{1,2})\.\s*(.*)', h_text)
            if num_match:
                n_str = num_match.group(1)
                t_str = num_match.group(2).strip().strip('*').strip()
                icon = emoji_nums.get(n_str, '🔹')
                formatted_lines.append(f'{icon} *{t_str}*')
                continue

            # Pārbaudām atslēgvārdu kategorijas emoji
            chosen_icon = '🔹'
            for pat, icon in category_emojis:
                if re.search(pat, h_text, re.IGNORECASE):
                    chosen_icon = icon
                    break
            clean_h = h_text.strip('*').strip()
            formatted_lines.append(f'{chosen_icon} *{clean_h}*')
            continue

        # Galvenie numurētie punkti: 1. **Virsraksts:** pārējais
        num_list_match = re.match(r'^(\d{1,2})\.\s+(\*\*(.*?)\*\*:?|(.*))', stripped)
        if num_list_match:
            n_str = num_list_match.group(1)
            icon = emoji_nums.get(n_str, f'{n_str}.')
            if num_list_match.group(3):
                title = num_list_match.group(3).strip()
                rest = stripped[num_list_match.end(1)+1:].strip()
                rest = re.sub(r'^\*\*' + re.escape(title) + r'\*\*:?\s*', '', rest)
                if rest:
                    formatted_lines.append(f'{icon} *{title}:* {rest}')
                else:
                    formatted_lines.append(f'{icon} *{title}*')
            else:
                rest = num_list_match.group(4) or ''
                formatted_lines.append(f'{icon} {rest}')
            continue

        # Saraksta punkti: - vai *
        bullet_match = re.match(r'^(\s*)[-*]\s+(.*)', line)
        if bullet_match:
            indent = bullet_match.group(1)
            content = bullet_match.group(2)
            if len(indent) >= 2:
                formatted_lines.append(f'   • {content}')
            else:
                formatted_lines.append(f'• {content}')
            continue

        formatted_lines.append(line)

    res = '\n'.join(formatted_lines)

    # Telegram Markdown V1 pieprasa vienu zvaigznīti treknrakstam: **teksts** -> *teksts*
    res = re.sub(r'\*\*(.*?)\*\*', r'*\1*', res)

    # Pievienojam ievada emoji, ja ziņa sākas ar apstiprinājumu
    first_non_empty = next((l for l in res.split('\n') if l.strip()), '')
    if first_non_empty and not any(first_non_empty.startswith(e) for e in ['✅', '🎉', '🚀', '📦', '⚠️', '❌', 'ℹ️']):
        for pat, icon in [(r'^(viss ir paveikts|darbs pabeigts|gatavs|sekm[īi]gi|pabeigts)', '✅ '),
                          (r'^(apsveicu|lieliski|izdev[āa]s)', '🎉 ')]:
            if re.search(pat, first_non_empty, re.IGNORECASE):
                res = icon + res
                break

    return res

if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding='utf-8')
    sample = """Viss ir paveikts un publicēts GitHub!

### Veiktās darbības:

1. **Atjaunināts [`CHANGELOG.md`](file:///c:/Users/Owner/.gemini/antigravity/scratch/ventspils_voice_assistant/CHANGELOG.md):**
   - Sadaļa **`[0.2.0] - 2026-09-28`** ir detalizēti noformēta atbilstoši *Keep a Changelog* standartam.
   - Pielāgojami rādiusi.

2. **Apvienošana ar main zaru:**
   - Zars `dev/v0.2.0` ir sekmīgi apvienots.

### Kopsavilkums un testi:
- Visi 50 testi izpildīti ar panākumiem.
"""
    print(format_for_telegram(sample))
