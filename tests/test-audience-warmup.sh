#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/skills/audience-warmup"
SKILL="$DIR/SKILL.md"
TECH="$DIR/references/technologies.md"
PLATFORMS="$DIR/references/platforms.md"
LAW="$DIR/references/honesty-and-law.md"
TEMPLATE="$DIR/assets/warmup-plan-template.html"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

need() {
  rg -qi -- "$1" "$2" || fail "$3"
}

[[ -f "$SKILL" ]] || fail "missing audience-warmup/SKILL.md"
for path in "$TECH" "$PLATFORMS" "$LAW" "$TEMPLATE"; do
  [[ -f "$path" ]] || fail "missing ${path#$DIR/}"
done
[[ "$(find "$DIR" -type f | wc -l | tr -d ' ')" == "5" ]] || fail "skill must contain exactly five files"
[[ "$(wc -l < "$SKILL" | tr -d ' ')" -le 300 ]] || fail "SKILL.md exceeds 300 lines"

keys="$(awk 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit} inside && /^[a-z_-]+:/ {sub(/:.*/, ""); print}' "$SKILL" | sort | tr '\n' ' ')"
[[ "$keys" == "description name " ]] || fail "frontmatter must contain only name and description, got: $keys"

need '^name: audience-warmup$' "$SKILL" "wrong skill name"
need '^description:.*прогрев' "$SKILL" "description lacks warmup trigger"
need '^description:.*контент-план' "$SKILL" "description lacks content-plan trigger"
need '^description:.*(бан|блокиров)' "$SKILL" "description lacks account-ban negative trigger"

need 'вебинар' "$SKILL" "missing webinar event"
need 'мероприяти' "$SKILL" "missing live event"
need 'акци' "$SKILL" "missing promo event"
need 'спецпредложени' "$SKILL" "missing special offer"
need 'набор' "$SKILL" "missing enrollment event"
need 'Прогрев к событию' "$SKILL" "missing event mode"
need 'Постоянный контент-план' "$SKILL" "missing ongoing mode"

need 'К чему прогреваем и когда' "$SKILL" "missing question 1"
need 'Что предлагаете и кому' "$SKILL" "missing question 2"
need 'Где будете публиковать' "$SKILL" "missing question 3"
need 'не больше трёх вопросов|максимум три вопроса' "$SKILL" "missing three-question limit"
need 'бриф' "$SKILL" "missing brief"
need '5-9 дней' "$SKILL" "missing 5-day range"
need '10-13 дней' "$SKILL" "missing compressed 14-day range"
need '14-21 д' "$SKILL" "missing 14-day range"
need 'Как вам план' "$SKILL" "missing plan review gate"
need 'напиши день' "$SKILL" "missing next-day continuation"

need 'knowledge/my-product\.md' "$SKILL" "missing product input"
need 'knowledge/product-choice\.md' "$SKILL" "missing selection input"
need 'knowledge/my-expertise\.md' "$SKILL" "missing expertise input"
need 'по смыслу' "$SKILL" "missing meaning-based lookup"
need 'product-selection' "$SKILL" "missing stop route to product-selection"
need 'short-video-scriptwriter' "$SKILL" "missing handoff to scriptwriter"
need 'бесплатн.*вебинар|бесплатн.*событи' "$SKILL" "missing free-event route"
need '30-100' "$SKILL" "missing warm-circle threshold"
need 'Распаковка профессиональной экспертности' "$SKILL" "missing unpacking route when expertise is absent"
need 'после события' "$SKILL" "missing post-event touch"
need 'базовая линия' "$SKILL" "missing baseline metrics"
need 'просьб.*разрешени' "$SKILL" "missing consent request"
need 'Можно я опубликую ваш отзыв' "$LAW" "missing consent request template"

# Работа вне курса: без установщика «Системного бизнеса» и без памяти агента
need 'skills/installer' "$SKILL" "missing course-installer detection"
need 'npx skills add mcdenil-skills/system-business-agent --skill expertise-unpacking' "$SKILL" "missing outside-course command for unpacking"
need 'npx skills add mcdenil-skills/system-business-agent --skill product-selection' "$SKILL" "missing outside-course command for product selection"
need 'npx skills add mcdenil-skills/system-business-agent --skill short-video-scriptwriter' "$SKILL" "missing outside-course command for scriptwriter"
need 'нет файлов памяти.*не значит|не значит.*нечего предложить' "$SKILL" "empty memory must not trigger the no-offer stop"
need 'MEMORY\.md.*только если.*(есть|существ)|только если.*MEMORY\.md' "$SKILL" "MEMORY.md must be touched only when it already exists"
need 'memory/.*только если.*(есть|существ)|только если.*memory/' "$SKILL" "diary must be written only when memory/ already exists"
need 'не больше четырёх вариант' "$SKILL" "missing popup option limit"
need 'свободн.*текст|своими словами' "$SKILL" "questions with dates must allow free text"
need 'сколько.*(читател|подписчик)' "$SKILL" "missing audience size in platform question"
need 'в сообщении участника' "$SKILL" "must not re-ask facts from the participant's message"
need 'если (участник )?(его )?не назвал' "$SKILL" "must not re-ask the plan period"
need 'события нет' "$SKILL" "question 1 must offer an ongoing-plan answer"

need 'нумерованн.*сообщен' "$SKILL" "missing numbered fallback"
need 'Claude.*Codex|Codex.*Claude' "$SKILL" "missing cross-client note"
need '\[НЕТ ДАННЫХ\]' "$SKILL" "missing no-data marker"
need 'честн.*ограничени' "$SKILL" "missing honest limit"
need 'не обещ' "$SKILL" "missing no-promise rule"
need 'голос участника|своим голосом' "$SKILL" "missing participant voice rule"

need 'knowledge/warmup-plan\.md' "$SKILL" "missing canonical Markdown"
need 'knowledge/warmup-plan\.html' "$SKILL" "missing HTML output"
need 'assets/warmup-plan-template\.html' "$SKILL" "missing template reference"
need 'warmup-data' "$SKILL" "missing data block id"
need 'references/technologies\.md' "$SKILL" "missing technologies reference"
need 'references/platforms\.md' "$SKILL" "missing platforms reference"
need 'references/honesty-and-law\.md' "$SKILL" "missing law reference"
need 'MEMORY\.md.*подтвержд|подтвержд.*MEMORY\.md' "$SKILL" "missing memory confirmation rule"

need 'Возможность' "$TECH" "missing PLC opportunity"
need 'Трансформаци' "$TECH" "missing PLC transformation"
need 'Опыт владения|каково жить с результатом' "$TECH" "missing PLC ownership"
need '\| 14 \|' "$TECH" "missing 14-day table"
need '\| 5 \|' "$TECH" "missing 5-day table"
need 'Путь героя' "$TECH" "missing hero journey tool"
need 'Лестниц' "$TECH" "missing awareness ladder"
need '70' "$TECH" "missing 70/30 rule"
need 'личност' "$TECH" "missing personality type"
need 'экспертност' "$TECH" "missing expertise type"

need 'Telegram' "$PLATFORMS" "missing Telegram"
need 'VK' "$PLATFORMS" "missing VK"
need 'MAX' "$PLATFORMS" "missing MAX"
need 'Instagram' "$PLATFORMS" "missing Instagram"
need 'YouTube' "$PLATFORMS" "missing YouTube"
need 'буст' "$PLATFORMS" "missing Telegram boosts"
need '25\.09\.2026' "$PLATFORMS" "missing verification date"

need '38-ФЗ' "$LAW" "missing advertising law"
need 'ч\. 3 п\. 3' "$LAW" "missing false deadline clause"
need 'п\. 10' "$LAW" "missing fake review clause"
need 'п\. 13' "$LAW" "missing false demand clause"
need '152-ФЗ' "$LAW" "missing personal data law"
need 'не юридическая консультация' "$LAW" "missing legal disclaimer"
need 'пять вопросов' "$LAW" "missing five-question scarcity check"
need '01\.09\.2025' "$LAW" "missing Instagram ad ban date"
need 'авторитет.*взаимность|взаимность.*авторитет' "$LAW" "missing Walker triggers"

need 'id="warmup-data">null</script>' "$TEMPLATE" "template must ship with a null data placeholder"
need 'application/json' "$TEMPLATE" "template data block is not JSON"
need 'textContent' "$TEMPLATE" "template must render text via textContent"
need 'window\.print' "$TEMPLATE" "template lacks print"
need 'clipboard' "$TEMPLATE" "template lacks copy"
need 'Почему так' "$TEMPLATE" "template lacks rationale tab"
need 'Технология' "$TEMPLATE" "template lacks technology tab"
need 'Тексты' "$TEMPLATE" "template lacks texts tab"
need 'Кратко' "$TEMPLATE" "template lacks detail switch"
if rg -q 'innerHTML|outerHTML|insertAdjacentHTML|document\.write' "$TEMPLATE"; then
  fail "template must not inject HTML strings"
fi
if rg -qi '(src|href)="https?://|@import|fonts\.googleapis|<script[^>]+src=' "$TEMPLATE"; then
  fail "template must not load external resources"
fi

if rg -qi 'Афонин|Розанов|продуктовые крошки' "$DIR"; then
  fail "author attribution or copied sequence leaked into skill"
fi
if rg -qi 'вредное допущение' "$DIR"; then
  fail "use honest limitation instead of harmful admission"
fi
if rg -q '—' "$SKILL" "$TECH" "$PLATFORMS" "$LAW"; then
  fail "use short dash instead of em dash"
fi
if rg -qi 'кайфанул|прикиньте|вот в чём фишка|пацан' "$SKILL" "$TECH"; then
  fail "owner slang leaked into participant skill"
fi

rg -q 'audience-warmup.*не установлен' "$ROOT/AGENTS.md" || fail "missing registry entry"
rg -q 'Прогрев аудитории.*audience-warmup.*доступен' "$ROOT/skills/installer/SKILL.md" || fail "missing installer alias"
rg -q 'Помоги сделать прогрев и контент-план' "$ROOT/skills/installer/SKILL.md" || fail "missing installer verification phrase"
rg -q 'Установи скилл «Прогрев аудитории»' "$ROOT/README.md" || fail "missing README install phrase"
rg -q 'Помоги сделать прогрев и контент-план' "$ROOT/README.md" || fail "missing README run phrase"
rg -qF 'npx skills add mcdenil-skills/system-business-agent --skill audience-warmup' "$ROOT/README.md" || fail "missing README outside-course install command"
[[ -f "$ROOT/LICENSE" ]] || fail "missing LICENSE"
rg -q '^MIT License' "$ROOT/LICENSE" || fail "LICENSE must be MIT"

printf 'PASS: audience-warmup structure, methodology, template and wiring\n'
