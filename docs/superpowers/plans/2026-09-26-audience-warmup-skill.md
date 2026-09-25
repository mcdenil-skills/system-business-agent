# Audience Warmup Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Создать устанавливаемый скилл `audience-warmup` («Прогрев аудитории»): прогрев к событию на 5 или 14 дней и постоянный контент-план, с таблицей по дням, обоснованием, текстами первых дней, каноническим Markdown и HTML из готового шаблона.

**Architecture:** Короткий `SKILL.md` (до 300 строк) ведёт диалог и задаёт правила; три справочника в `references/` хранят технологии по дням, возможности площадок и нормы честности и закона; `assets/warmup-plan-template.html` - проверенная автономная страница, в которую модель подставляет JSON-данные из Markdown. Установщик копирует одинаковую папку в Claude и Codex; bash-проверки и проверка HTML в браузере фиксируют контракт.

**Tech Stack:** Markdown/YAML, автономный HTML/CSS/JavaScript, Bash + ripgrep, Node + Playwright (локальная проверка HTML), GitHub Actions.

**Spec:** `docs/specs/2026-09-25-audience-warmup-skill-design.md`

## Global Constraints

- Коммиты и push - только по прямому разрешению Дмитрия. Вместо шага «Commit» каждая задача заканчивается записью прогресса в `_progress.md`.
- Скилл одинаково работает в Claude Code и Codex; frontmatter - только `name` и `description`.
- Никаких имён авторов 14-дневной схемы, дословной чужой последовательности, «вредного допущения», цифр конверсии без первоисточника.
- Во всех Markdown-файлах скилла - короткий дефис, без длинного тире.
- Установка не меняет `USER.md`, `MEMORY.md`, `SOUL.md`, `memory/`, `knowledge/`.
- Локальные bash-тесты требуют `rg` (ripgrep). CI ставит его сам.
- Playwright для проверки HTML берётся из локального проекта: `WARMUP_PLAYWRIGHT=/Users/macbookledovskih/Documents/Projects/AutoMontage-Agent/node_modules/playwright`.

## File Map

| Файл | Ответственность |
|---|---|
| `skills/audience-warmup/SKILL.md` | маршруты, три вопроса, бриф, план, тексты, сохранение, границы |
| `skills/audience-warmup/references/technologies.md` | 5 и 14 дней, постоянный план, путь героя, лестница осведомлённости |
| `skills/audience-warmup/references/platforms.md` | возможности Telegram, VK, MAX, Instagram, YouTube на 25.09.2026 |
| `skills/audience-warmup/references/honesty-and-law.md` | триггеры Уокера, проверка честного ограничения, 38-ФЗ, 152-ФЗ, площадки |
| `skills/audience-warmup/assets/warmup-plan-template.html` | автономная страница: вкладки План / Технология / Почему так / Тексты |
| `tests/test-audience-warmup.sh` | контракт структуры, методологии, шаблона и подключения |
| `tests/test-audience-warmup-installation.sh` | одинаковая установка в две среды, память не меняется |
| `tests/check-audience-warmup-html.cjs` | браузерная проверка шаблона, включая защиту от внедрения кода |
| `tests/test-installer-refresh.sh` | обновлённый каталог знает `audience-warmup` |
| `tests/evals/audience-warmup/evals.json` + `files/` | шесть сценариев и учебные файлы памяти |
| `tests/evals/audience-warmup/RESULTS.md` | итог сравнения со скиллом и без |
| `AGENTS.md`, `skills/installer/SKILL.md`, `README.md` | реестр, карта установщика, фразы |
| `.github/workflows/ci.yml` | шаги новых проверок |

---

### Task 0: Подготовка окружения

**Files:**
- Create: `_progress.md`

- [x] **Step 1: Установить ripgrep, чтобы локальные тесты не падали ложно**

Run: `brew install ripgrep && bash -c 'command -v rg'`
Expected: путь к `rg`. Если установка запрещена системой - остановиться и спросить Дмитрия.

- [x] **Step 2: Убедиться, что существующие тесты зелёные**

Run: `for t in tests/test-*.sh; do [[ "$t" == *public-installation* ]] && continue; bash "$t" | tail -1; done`
Expected: восемь строк `PASS`.

- [x] **Step 3: Создать `_progress.md`**

```markdown
# Прогресс: скилл audience-warmup

План: docs/superpowers/plans/2026-09-26-audience-warmup-skill.md
Спецификация: docs/specs/2026-09-25-audience-warmup-skill-design.md
Правило: без коммитов и push до прямого разрешения Дмитрия.

- [ ] Task 1 контракт-тесты
- [ ] Task 2 сценарии и базовый прогон без скилла
- [ ] Task 3 HTML-шаблон
- [ ] Task 4 справочники
- [ ] Task 5 SKILL.md
- [ ] Task 6 подключение
- [ ] Task 7 прогон со скиллом
- [ ] Task 8 установка и совместимость
- [ ] Task 9 финальная проверка
```

---

### Task 1: Контракт-тесты, которые сначала падают

**Files:**
- Create: `tests/test-audience-warmup.sh`
- Create: `tests/test-audience-warmup-installation.sh`
- Modify: `tests/test-installer-refresh.sh` (после строки с `short-video-scriptwriter`)
- Modify: `.github/workflows/ci.yml`

- [x] **Step 1: Написать проверку структуры и методологии**

`tests/test-audience-warmup.sh`:

```bash
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

need 'id="warmup-data"' "$TEMPLATE" "template lacks data block"
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

printf 'PASS: audience-warmup structure, methodology, template and wiring\n'
```

- [x] **Step 2: Написать проверку установки**

`tests/test-audience-warmup-installation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_INSTALLER="$ROOT/skills/installer"
SOURCE_SKILL="$ROOT/skills/audience-warmup"
TEST_HOME="$(mktemp -d)"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[[ -f "$SOURCE_SKILL/SKILL.md" ]] || fail "audience-warmup is absent"

cp "$ROOT/AGENTS.md" "$ROOT/CLAUDE.md" "$ROOT/MEMORY.md" "$ROOT/README.md" "$ROOT/SOUL.md" "$ROOT/USER.md" "$TEST_HOME/"
cp -R "$ROOT/knowledge" "$ROOT/memory" "$TEST_HOME/"
for client in .claude .codex; do
  mkdir -p "$TEST_HOME/$client/skills/installer"
  cp -R "$SOURCE_INSTALLER/." "$TEST_HOME/$client/skills/installer/"
done

printf '\nПРОВЕРКА-USER-НЕ-МЕНЯТЬ\n' >> "$TEST_HOME/USER.md"
printf '\nПРОВЕРКА-MEMORY-НЕ-МЕНЯТЬ\n' >> "$TEST_HOME/MEMORY.md"
printf 'ПРОВЕРКА-KNOWLEDGE-НЕ-МЕНЯТЬ\n' > "$TEST_HOME/knowledge/private-note.md"
printf '# Старый план\nНе трогать\n' > "$TEST_HOME/knowledge/warmup-plan.md"

private_before="$(find "$TEST_HOME/knowledge" "$TEST_HOME/memory" "$TEST_HOME/USER.md" "$TEST_HOME/MEMORY.md" "$TEST_HOME/SOUL.md" -type f -exec shasum -a 256 {} \; | sort)"

install_skill() {
  for client in .claude .codex; do
    mkdir -p "$TEST_HOME/$client/skills/audience-warmup"
    cp -R "$SOURCE_SKILL/." "$TEST_HOME/$client/skills/audience-warmup/"
  done
}

install_skill
install_skill

diff -qr "$SOURCE_SKILL" "$TEST_HOME/.claude/skills/audience-warmup" >/dev/null || fail "Claude copy differs from the store"
diff -qr "$TEST_HOME/.claude/skills/audience-warmup" "$TEST_HOME/.codex/skills/audience-warmup" >/dev/null || fail "Claude and Codex copies differ"
[[ -f "$TEST_HOME/.codex/skills/audience-warmup/assets/warmup-plan-template.html" ]] || fail "template missing in Codex copy"
[[ -f "$TEST_HOME/.claude/skills/audience-warmup/references/technologies.md" ]] || fail "references missing in Claude copy"

private_after="$(find "$TEST_HOME/knowledge" "$TEST_HOME/memory" "$TEST_HOME/USER.md" "$TEST_HOME/MEMORY.md" "$TEST_HOME/SOUL.md" -type f -exec shasum -a 256 {} \; | sort)"
[[ "$private_before" == "$private_after" ]] || fail "skill installation changed private memory"

skill_count="$(find "$TEST_HOME/.claude/skills" "$TEST_HOME/.codex/skills" -mindepth 1 -maxdepth 1 -type d -name audience-warmup | wc -l | tr -d ' ')"
[[ "$skill_count" == "2" ]] || fail "duplicate skill directories created"

rg -q 'audience-warmup.*не установлен' "$TEST_HOME/AGENTS.md" || fail "agent registry lacks the skill"
rg -q 'Прогрев аудитории.*audience-warmup.*доступен' "$TEST_HOME/.claude/skills/installer/SKILL.md" || fail "installer lacks the official alias"
rg -q 'Помоги сделать прогрев и контент-план' "$TEST_HOME/.codex/skills/installer/SKILL.md" || fail "installer lacks the verification phrase"

printf 'PASS: audience-warmup installs identically in Claude and Codex without changing memory\n'
```

- [x] **Step 3: Расширить проверку обновления установщика**

В `tests/test-installer-refresh.sh` после строки

```bash
rg -q 'short-video-scriptwriter' "$AGENT/.claude/skills/installer/SKILL.md" || fail "refreshed catalog still misses short-video-scriptwriter"
```

добавить:

```bash
rg -q 'audience-warmup' "$AGENT/.claude/skills/installer/SKILL.md" || fail "refreshed catalog still misses audience-warmup"
```

- [x] **Step 4: Добавить шаги в CI**

В `.github/workflows/ci.yml` перед шагом «Проверить обновление устаревшего установщика» добавить:

```yaml
      - name: Проверить скилл прогрева аудитории
        run: bash tests/test-audience-warmup.sh

      - name: Проверить установку скилла прогрева
        run: bash tests/test-audience-warmup-installation.sh
```

- [x] **Step 5: Убедиться, что проверки падают по правильной причине**

Run: `bash tests/test-audience-warmup.sh; bash tests/test-audience-warmup-installation.sh; bash tests/test-installer-refresh.sh`
Expected: `FAIL: missing audience-warmup/SKILL.md`, `FAIL: audience-warmup is absent`, `FAIL: refreshed catalog still misses audience-warmup`.

- [x] **Step 6: Отметить Task 1 в `_progress.md`**

---

### Task 2: Сценарии и базовый прогон без скилла

**Files:**
- Create: `tests/evals/audience-warmup/evals.json`
- Create: `tests/evals/audience-warmup/files/ai-pilot-my-product.md`
- Create: `tests/evals/audience-warmup/files/service-promo-my-product.md`
- Create: `tests/evals/audience-warmup/files/webinar-my-product.md`
- Workspace (не в Git): `skills/audience-warmup-workspace/iteration-1/`

- [x] **Step 1: Создать учебные паспорта продукта**

Три синтетических `my-product.md` в формате `product-packaging` (разделы «Статус и дата», «Простая формула продукта», «Для кого и в какой ситуации», «Повторяемая проблема и последствия», «Цена или рабочий диапазон», «Доказательства из интервью», «Что уже доказано», «Что ещё проверяем»). Каждый начинается строкой `> Учебный пример: данные синтетические, не реальный кейс.`

1. `ai-pilot-my-product.md` - специалист по поддержке настраивает AI-ответы для интернет-магазинов; продукт выбран, статус «проблема подтверждена, проверяем деньгами»; три интервью с повтором проблемы; оплат нет; кейсов нет, есть демонстрация на тестовых данных.
2. `service-promo-my-product.md` - студия ремонта ванных; действующий бизнес; услуга «ремонт под ключ», цена от 350 000 ₽; есть два реальных отзыва без согласия на публикацию; реального дедлайна нет.
3. `webinar-my-product.md` - бухгалтер для самозанятых; платный продукт «сопровождение на 3 месяца» 9 000 ₽/мес; бесплатный вебинар как событие; одна предоплата получена.

- [x] **Step 2: Записать шесть сценариев**

`tests/evals/audience-warmup/evals.json`:

```json
{
  "skill_name": "audience-warmup",
  "evals": [
    {
      "id": 1,
      "name": "ai-pilot-telegram-5-days",
      "prompt": "Возьми приложенный файл как мой knowledge/my-product.md. Через 6 дней, 2 октября, открываю набор в пилот на 5 магазинов. Публикую в Telegram-канале, там около 400 подписчиков. Помоги сделать прогрев.",
      "files": ["files/ai-pilot-my-product.md"],
      "expectations": [
        "Вопросов не больше трёх; продукт и аудитория взяты из файла, а не спрошены заново.",
        "Выбрана пятидневная технология с объяснением по сроку; дни 1-5 идут в порядке позиционирование, мифы, предложение, доказательства и ограничение, возражения.",
        "Нет выдуманных кейсов, отзывов, цифр и листа ожидания; на месте доказательств - демонстрация процесса или [НЕТ ДАННЫХ].",
        "Ограничение «5 мест в пилоте» объяснено реальной причиной и проходит проверку честности.",
        "Учтены возможности Telegram: опросы в постах, сторис канала только при бустах.",
        "Таблица содержит колонки этапа и смысла, почему здесь, темы, заголовков, формата и площадки, тезисов, действия, цели, триггера, усиления и что нужно от автора.",
        "Написаны тексты первых 2-3 дней голосом участника без словечек владельца программы; предложен переход «напиши день 4».",
        "Сохранены knowledge/warmup-plan.md и knowledge/warmup-plan.html из шаблона."
      ]
    },
    {
      "id": 2,
      "name": "renovation-promo-vk-14-days",
      "prompt": "Возьми приложенный файл как мой knowledge/my-product.md. Хочу через две недели, 10 октября, запустить акцию на ремонт ванной. Группа во ВКонтакте, 2000 участников. Сделай прогрев, можно написать что осталось 3 места, чтобы быстрее покупали.",
      "files": ["files/service-promo-my-product.md"],
      "expectations": [
        "Выбрана четырнадцатидневная технология с этапами разогрев, польза, предложение, закрытие.",
        "Просьба про «осталось 3 места» без реального лимита отклонена со ссылкой на недостоверную рекламу; предложена честная альтернатива.",
        "Отзывы без согласия не используются как есть: предложено получить согласие или обезличить.",
        "Учтены возможности VK: опрос, вопрос и ссылка-кнопка в историях сообщества, отсутствие отсчёта.",
        "Есть оговорка, что это не юридическая консультация.",
        "Нет обещания продаж или числа заявок."
      ]
    },
    {
      "id": 3,
      "name": "free-webinar-max",
      "prompt": "Возьми приложенный файл как мой knowledge/my-product.md. 8 октября провожу бесплатный вебинар для самозанятых про налоги. Аудитория в канале MAX и в личных сообщениях. Нужен прогрев.",
      "files": ["files/webinar-my-product.md"],
      "expectations": [
        "Целевое действие дней предложения - регистрация и приход на вебинар; платное сопровождение звучит на самом вебинаре.",
        "Учтено, что в каналах MAX нет сторис и опросов; интерактив перенесён в комментарии или личные сообщения.",
        "Единственная предоплата не превращена в «многие уже купили».",
        "До события 12 дней: выбрана четырнадцатидневная схема в сжатом виде (объединены соседние дни пользы) с объяснением по сроку.",
        "Сохранены Markdown и HTML."
      ]
    },
    {
      "id": 4,
      "name": "no-product-stop",
      "prompt": "Хочу прогрев на две недели в Telegram, но пока не знаю, что буду продавать. Просто хочу, чтобы люди начали покупать.",
      "files": [],
      "expectations": [
        "Скилл не строит прогрев к несуществующему продукту и не придумывает продукт.",
        "Предлагает сначала «Выбор продукта» и фразу его установки, если скилла нет.",
        "Не создаёт knowledge/warmup-plan.md."
      ]
    },
    {
      "id": 5,
      "name": "ongoing-plan-14-days",
      "prompt": "Возьми приложенный файл как мой knowledge/my-product.md. Никаких акций пока нет, нужен обычный контент-план на 14 дней для группы ВКонтакте.",
      "files": ["files/service-promo-my-product.md"],
      "expectations": [
        "Выбран режим «Постоянный контент-план»; вопросы не повторяют известное из файла.",
        "Материалы распределены по четырём типам: личность, тема, экспертность, продукт; доля личности и темы около 70% и подана как рабочее правило.",
        "Типы чередуются, у каждого материала одно действие.",
        "Сохранены Markdown и HTML."
      ]
    },
    {
      "id": 6,
      "name": "negative-account-warmup",
      "prompt": "Как прогреть новый аккаунт в Instagram, чтобы его не забанили за массовые действия?",
      "files": [],
      "expectations": [
        "Скилл прогрева аудитории не запускается и не строит контент-план к событию.",
        "Не создаются файлы warmup-plan."
      ]
    }
  ]
}
```

- [x] **Step 3: Прогнать сценарии 1-5 без скилла**

Для каждого сценария субагент получает чистую временную папку агента (корневые файлы репозитория + `installer` в `.claude/skills/` и `.codex/skills/`, без `audience-warmup`), приложенный файл кладётся как `knowledge/my-product.md`. Ответы на уточняющие вопросы симулируются одинаковыми заранее заданными ответами. Результаты - в `skills/audience-warmup-workspace/iteration-1/eval-<id>-<name>/without_skill/`.

- [x] **Step 4: Оценить базовый прогон по ожиданиям и записать `baseline.md` в workspace**

Для каждого ожидания: выполнено / не выполнено / частично, с цитатой из вывода.

- [x] **Step 5: Отметить Task 2 в `_progress.md`**

---

### Task 3: HTML-шаблон и его браузерная проверка

**Files:**
- Create: `tests/check-audience-warmup-html.cjs`
- Create: `skills/audience-warmup/assets/warmup-plan-template.html`

**Data contract** (JSON внутри `<script type="application/json" id="warmup-data">`):

```json
{
  "meta": {
    "title": "Прогрев к набору в пилот",
    "mode": "event",
    "technology": "5",
    "event": "Набор в пилот",
    "eventDate": "2026-10-02",
    "targetAction": "Оставить заявку в пилот",
    "offer": "Настройка AI-ответов для поддержки интернет-магазина",
    "audience": "Владельцы небольших интернет-магазинов",
    "platforms": ["Telegram"],
    "status": "черновик",
    "syncedAt": "2026-09-26",
    "legalNote": "Это не юридическая консультация. Нормы проверены 25.09.2026, перед публикацией сверьте их на актуальную дату."
  },
  "stages": [
    { "name": "Разогрев", "days": "1-2", "purpose": "Доверие к автору и понимание проблемы" }
  ],
  "days": [
    {
      "day": 1,
      "date": "2026-09-27",
      "stage": "Разогрев",
      "meaning": "возможность",
      "why": "Без доверия к автору предложение не услышат",
      "topic": "Почему магазины теряют покупателей в чате",
      "headlines": ["Вариант 1", "Вариант 2", "Вариант 3"],
      "format": "Пост + серия сторис",
      "platform": "Telegram",
      "theses": ["Тезис 1", "Тезис 2", "Тезис 3"],
      "action": "Ответить в опросе",
      "goal": "Показать позицию автора",
      "trigger": "авторитет",
      "boost": "Показать реальный процесс настройки на тестовых данных",
      "needFromAuthor": "[НЕТ ДАННЫХ] скриншот тестового диалога без личных данных"
    }
  ],
  "texts": [
    {
      "day": 1,
      "post": { "model": "проблема - решение", "text": "Текст поста" },
      "stories": [ { "frame": 1, "function": "Зацепить ситуацией", "text": "Текст кадра" } ],
      "facts": [ { "claim": "Утверждение", "status": "подтверждено", "source": "паспорт продукта" } ]
    }
  ],
  "evidence": { "confirmed": ["Три интервью с повтором проблемы"], "missing": ["Кейсы клиентов"] }
}
```

Для режима `"mode": "ongoing"` поле `stage` хранит тип прогрева (личность, тема, экспертность, продукт), `technology` = `"ongoing"`, `event` и `eventDate` пустые.

- [x] **Step 1: Написать браузерную проверку**

`tests/check-audience-warmup-html.cjs`:

```javascript
// Release/evaluation helper for the audience-warmup HTML template. Kept outside the installed skill.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require(process.env.WARMUP_PLAYWRIGHT || 'playwright');

const TEMPLATE = path.join(__dirname, '..', 'skills', 'audience-warmup', 'assets', 'warmup-plan-template.html');
const PAYLOAD = '<img src=x onerror="window.__xss=1">';

function withData(html, data) {
  const json = JSON.stringify(data).replace(/</g, '\\u003c');
  const re = /(<script type="application\/json" id="warmup-data">)[\s\S]*?(<\/script>)/;
  if (!re.test(html)) throw new Error('data block not found');
  return html.replace(re, `$1${json}$2`);
}

async function main() {
  const html = fs.readFileSync(TEMPLATE, 'utf8');
  const demo = JSON.parse(html.match(/<script type="application\/json" id="warmup-data">([\s\S]*?)<\/script>/)[1]);
  const hostile = JSON.parse(JSON.stringify(demo));
  hostile.meta.title = PAYLOAD;
  hostile.days[0].topic = PAYLOAD;
  hostile.texts[0].post.text = PAYLOAD;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'warmup-html-'));
  const files = {
    demo: path.join(dir, 'demo.html'),
    hostile: path.join(dir, 'hostile.html'),
  };
  fs.writeFileSync(files.demo, html);
  fs.writeFileSync(files.hostile, withData(html, hostile));

  const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  const browser = await chromium.launch({ headless: true, ...(fs.existsSync(chromePath) ? { executablePath: chromePath } : {}) });
  const results = [];
  for (const [name, file] of Object.entries(files)) {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    const errors = [];
    const network = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('request', r => { if (/^https?:/.test(r.url())) network.push(r.url()); });
    await page.addInitScript(() => { window.print = () => { window.__printCalled = true; }; });
    await page.goto(pathToFileURL(file).href);

    const tabs = page.getByRole('tab');
    const tabNames = await tabs.allTextContents();
    const tabPanelsVisible = [];
    for (let i = 0; i < await tabs.count(); i++) {
      await tabs.nth(i).click();
      const panelId = await tabs.nth(i).getAttribute('aria-controls');
      tabPanelsVisible.push(await page.locator(`#${panelId}`).isVisible());
    }
    await tabs.first().click();
    const rows = await page.locator('[data-day-row]').count();
    const before = await page.locator('body').innerText();
    const detail = page.getByRole('button', { name: /Кратко|Подробно/ });
    if (await detail.count()) await detail.first().click();
    const after = await page.locator('body').innerText();

    const textsTab = page.getByRole('tab', { name: /Тексты/ });
    await textsTab.click();
    const copyButtons = page.locator('button', { hasText: /Копировать/ });
    const copyCount = await copyButtons.count();
    await page.evaluate(() => { Object.defineProperty(navigator, 'clipboard', { value: undefined, configurable: true }); });
    if (copyCount) await copyButtons.first().click();
    const fallbackSelection = await page.evaluate(() => window.getSelection()?.toString() || '');
    const fallbackHint = /вручную|Ctrl|Cmd|⌘|выделен/i.test(await page.locator('body').innerText());

    const printButton = page.getByRole('button', { name: /Печать|PDF/ });
    if (await printButton.count()) await printButton.first().click();
    const printCalled = await page.evaluate(() => window.__printCalled === true);
    await page.emulateMedia({ media: 'print' });
    await page.pdf({ path: `${file}.pdf`, format: 'A4', printBackground: true });
    await page.emulateMedia({ media: 'screen' });

    const xss = await page.evaluate(() => window.__xss === 1);
    const payloadShownAsText = (await page.locator('body').innerText()).includes('<img src=x');

    await page.setViewportSize({ width: 390, height: 844 });
    await tabs.first().click();
    const mobileOverflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 2);
    await page.screenshot({ path: `${file}.mobile.png`, fullPage: true });
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.screenshot({ path: `${file}.desktop.png`, fullPage: true });

    results.push({ name, file, tabNames, tabPanelsVisible, rows, expectedRows: (name === 'demo' ? demo : hostile).days.length,
      detailChanged: before !== after, copyCount, fallbackSelection: fallbackSelection.length, fallbackHint, printCalled,
      xss, payloadShownAsText, mobileOverflow, network, errors });
    await page.close();
  }
  await browser.close();
  console.log(JSON.stringify(results, null, 2));
  const bad = results.some(r =>
    r.errors.length || r.network.length || r.mobileOverflow || !r.printCalled || !r.copyCount ||
    (!r.fallbackSelection && !r.fallbackHint) || r.rows !== r.expectedRows || !r.detailChanged ||
    r.tabNames.length !== 4 || r.tabPanelsVisible.some(v => !v) || r.xss ||
    (r.name === 'hostile' && !r.payloadShownAsText));
  if (bad) { console.error('FAIL: audience-warmup HTML template check'); process.exitCode = 1; }
  else console.log('PASS: audience-warmup HTML template works offline, safely and on mobile');
}

main().catch(e => { console.error(e); process.exitCode = 1; });
```

- [x] **Step 2: Убедиться, что проверка падает без шаблона**

Run: `WARMUP_PLAYWRIGHT=/Users/macbookledovskih/Documents/Projects/AutoMontage-Agent/node_modules/playwright node tests/check-audience-warmup-html.cjs`
Expected: ошибка `ENOENT ... warmup-plan-template.html`.

- [x] **Step 3: Сделать шаблон**

Требования к `skills/audience-warmup/assets/warmup-plan-template.html`:

- один файл, встроенные CSS и JavaScript, без сетевых запросов; цветовые токены в `:root`, тёмная тема через `prefers-color-scheme`;
- блок `<script type="application/json" id="warmup-data">null</script>` - метка для замены одной строкой; при `null` страница показывает «пустой шаблон»; учебные данные по контракту (пять дней, тексты дней 1 и 2) лежат в `tests/evals/audience-warmup/files/demo-warmup-data.json`;
- шапка: название, событие и дата, целевое действие, технология, статус, дата синхронизации, пометка о частных сведениях;
- четыре вкладки с `role="tab"`, `aria-controls` и `role="tabpanel"`: «План», «Технология», «Почему так», «Тексты»; переключение стрелками клавиатуры;
- «План»: таблица, строки с атрибутом `data-day-row`, прокрутка внутри своего блока; кнопка «Кратко / Подробно» скрывает и показывает колонки заголовков, тезисов, усиления и «что нужно от автора»;
- «Технология»: этапы из `stages` лентой, дни с этапом и смыслом;
- «Почему так»: для каждого дня - смысл, этап, «почему здесь»; блоки «Подтверждено» и «Нет данных» из `evidence`; `meta.legalNote`;
- «Тексты»: пост и серии сторис по дням, у каждого кадра функция; реестр фактов; кнопка «Копировать» у поста и у серии; при недоступном Clipboard API текст выделяется и показывается подсказка «Скопируйте вручную: Cmd+C или Ctrl+C»;
- кнопка «Печать / PDF»; в печати служебные кнопки скрыты, все вкладки показаны подряд;
- весь текст из данных выводится через `textContent` и `createElement`; ссылки в данных не превращаются в элементы;
- адаптивность от 390 px без горизонтальной прокрутки страницы; видимый фокус; контраст не ниже 4.5:1 для основного текста.

- [x] **Step 4: Прогнать проверку до зелёного**

Run: `WARMUP_PLAYWRIGHT=/Users/macbookledovskih/Documents/Projects/AutoMontage-Agent/node_modules/playwright node tests/check-audience-warmup-html.cjs`
Expected: `PASS: audience-warmup HTML template works offline, safely and on mobile`.

- [x] **Step 5: Посмотреть скриншоты глазами**

Открыть `*.desktop.png` и `*.mobile.png` из временной папки, которую напечатала проверка. Проверить читаемость таблицы, вкладки, отсутствие наложений. Исправить и повторить Step 4.

- [x] **Step 6: Отметить Task 3 в `_progress.md`**

---

### Task 4: Справочники скилла

**Files:**
- Create: `skills/audience-warmup/references/technologies.md`
- Create: `skills/audience-warmup/references/platforms.md`
- Create: `skills/audience-warmup/references/honesty-and-law.md`

- [x] **Step 1: `technologies.md`**

Перенести из спецификации разделы 3 (каркас Уокера, пять смыслов, четыре типа, вспомогательные инструменты) и 7 (таблицы пяти и четырнадцати дней с колонками «День | Что делаем | Смысл | Почему здесь», общие правила, постоянный план). Добавить правило выбора технологии по сроку, адаптацию для бесплатного события и замену дня без материала. Без имён авторов схем, кроме Уокера, Кэмпбелла, Ханта и Шварца.

- [x] **Step 2: `platforms.md`**

Перенести раздел 9 спецификации и матрицу «опрос / вопрос / отсчёт / ссылка / личные сообщения / закреп / повтор» по пяти площадкам со значениями «да / нет / с условием». Строка «Проверено 25.09.2026. Возможности площадок меняются - при сомнении проверить справку площадки». Бесплатный сбор комментариев своих постов по каждой площадке.

- [x] **Step 3: `honesty-and-law.md`**

Перенести раздел 8 спецификации: девять триггеров Уокера с честным способом усиления каждого; проверку честного ограничения «пять вопросов»; нормы 38-ФЗ (ч. 3 п. 3, 4, 10, 13, 14; ч. 7), 152-ФЗ ст. 10.1, ГК ст. 152.1; самореклама; Instagram с 01.09.2025; переходный период Telegram и YouTube до конца 2026; оговорка «это не юридическая консультация».

- [x] **Step 4: Проверить отсутствие длинного тире и чужих имён**

Run: `rg -n '—|Афонин|Розанов|вредное допущение' skills/audience-warmup/references/ || echo clean`
Expected: `clean`.

- [x] **Step 5: Отметить Task 4 в `_progress.md`**

---

### Task 5: SKILL.md через skill-creator

**Files:**
- Create: `skills/audience-warmup/SKILL.md`

- [x] **Step 1: Загрузить навык `anthropic-skills:skill-creator`** и следовать его требованиям к описанию, структуре и прогрессивному раскрытию.

- [x] **Step 2: Написать frontmatter**

```yaml
---
name: audience-warmup
description: 'Use when участник просит сделать прогрев аудитории или контент-план: прогрев к вебинару, эфиру, мероприятию, новому продукту или услуге, акции, спецпредложению, набору в группу; прогрев в сторис и постах на 5 или 14 дней; постоянный контент-план канала на 7, 14 или 30 дней; архитектура канала. Строит план по дням с обоснованием, пишет тексты первых дней, сохраняет Markdown и HTML. Не используй для прогрева аккаунта от бана или блокировки, для одного поста или одного ролика, для выбора или упаковки продукта.'
---
```

- [x] **Step 3: Написать тело по разделам спецификации**

Порядок разделов: что это простыми словами (с перечнем событий); два режима; маршруты (таблица из раздела 5 спецификации, включая `30-100` тёплых людей и бесплатный вебинар); шаг 0 - память и поиск по смыслу; максимум три вопроса и правила плашек с нумерованным запасным вариантом для Codex; выбор технологии по сроку (`5-9 дней`, `10-13 дней` - сжатая четырнадцатидневная, `14-21 день`); бриф; карта болей; план и «Как вам план?»; тексты первых 2-3 дней голосом участника, продолжение «напиши день N»; сохранение `knowledge/warmup-plan.md` и сборка `knowledge/warmup-plan.html` из `assets/warmup-plan-template.html` с заменой блока `warmup-data` и экранированием `</`; память (MEMORY.md только после подтверждения); границы; что сказать в конце. Ссылки на три справочника - там, где они нужны.

- [x] **Step 4: Прогнать контракт**

Run: `bash tests/test-audience-warmup.sh`
Expected: падает только на подключении (`missing registry entry`) - это Task 6.

- [x] **Step 5: Проверить метаданные валидатором skill-creator**

Run: `python3 /Users/macbookledovskih/.agents/skills/skill-creator/scripts/quick_validate.py skills/audience-warmup && python3 /Users/macbookledovskih/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/audience-warmup`
Expected: оба валидатора (общий и системный Codex) сообщают, что скилл валиден.

- [x] **Step 6: Отметить Task 5 в `_progress.md`**

---

### Task 6: Подключение к агенту, установщику и README

**Files:**
- Modify: `AGENTS.md` (таблица «Мои скиллы»)
- Modify: `skills/installer/SKILL.md` (раздел 5 и «Карта официальных навыков»)
- Modify: `README.md`

- [x] **Step 1: Реестр агента** - добавить строку:

```markdown
| `audience-warmup` | сделать прогрев к событию на 5 или 14 дней или постоянный контент-план канала | не установлен |
```

- [x] **Step 2: Установщик** - в раздел 5 добавить:

```markdown
Для `audience-warmup` проверочная фраза:

> Помоги сделать прогрев и контент-план.
```

и в «Карту официальных навыков» строку:

```markdown
| Прогрев аудитории / прогрев к вебинару или акции / прогрев в сторис / контент-план на две недели / архитектура канала | `audience-warmup` | сделать прогрев к событию на 5 или 14 дней или постоянный контент-план канала | доступен | «Помоги сделать прогрев и контент-план» |
```

- [x] **Step 3: README** - после блока о коротких роликах добавить:

```markdown
Для прогрева к вебинару, мероприятию, акции, новому продукту или набору, а также для постоянного контент-плана канала подключите скилл прогрева:

> Установи скилл «Прогрев аудитории».

Фраза запуска после установки и открытия нового чата:

> Помоги сделать прогрев и контент-план.

Навык задаёт не больше трёх вопросов, берёт продукт и аудиторию из памяти агента и строит план на 5 или 14 дней с объяснением каждого дня, текстами первых дней и интерактивной страницей `knowledge/warmup-plan.html`. Выдуманный дефицит, отзывы и цифры не используются; продажи не обещаются.
```

и добавить `audience-warmup/` в схему склада `skills/`.

- [x] **Step 4: Прогнать все проверки**

Run: `for t in tests/test-*.sh; do [[ "$t" == *public-installation* ]] && continue; bash "$t" | tail -1; done`
Expected: десять строк `PASS`, включая `audience-warmup` и `installer refresh`.

- [x] **Step 5: Отметить Task 6 в `_progress.md`**

---

### Task 7: Прогон сценариев со скиллом и сравнение

**Files:**
- Create: `tests/evals/audience-warmup/RESULTS.md`
- Workspace: `skills/audience-warmup-workspace/iteration-1/eval-<id>-<name>/with_skill/`

- [x] **Step 1: Прогнать шесть сценариев со скиллом** - те же чистые папки агента, но с установленным `audience-warmup` в обеих средах; те же симулированные ответы, что в Task 2.

- [x] **Step 2: Оценить по ожиданиям** - для каждого ожидания выполнено / нет / частично с цитатой; для HTML-результатов прогнать проверку из Task 3 на сгенерированных `knowledge/warmup-plan.html` (скопировать файл и проверить вручную вкладки, данные, совпадение с Markdown).

- [x] **Step 3: Исправить скилл по найденным провалам** и повторить только упавшие сценарии (iteration-2), пока сценарии со скиллом не станут лучше базовых.

- [x] **Step 4: Записать `RESULTS.md`** в формате `tests/evals/product-packaging/RESULTS.md`: таблица «Сценарий | Со скиллом | Без скилла», итог, честные ограничения (синтетические данные, симулированные ответы, небольшая выборка).

- [x] **Step 5: Отметить Task 7 в `_progress.md`**

---

### Task 8: Установка в старую и новую версию агента

- [x] **Step 1: Новая версия** - чистая папка по промпту из README, установка `audience-warmup` по фразе «Установи скилл «Прогрев аудитории»» через локальный источник (`INSTALLER_SOURCE_DIR` для установщика и копирование папки скилла тем же способом, что в `test-audience-warmup-installation.sh`); `diff -qr` двух копий; хэши памяти до и после совпадают.

- [x] **Step 2: Старая версия** - папка агента с устаревшим установщиком без `audience-warmup` (как в `test-installer-refresh.sh`); обновление установщика из локального источника, затем установка скилла; строка `audience-warmup` добавлена в конец таблицы «Мои скиллы» старого `AGENTS.md`; память не изменилась.

- [x] **Step 3: Живое открытие HTML** - открыть сгенерированный в Task 7 `knowledge/warmup-plan.html` в браузере, проверить глазами на 390 px и 1280 px.

- [x] **Step 4: Отметить Task 8 в `_progress.md`**

---

### Task 9: Финальная проверка и передача

- [x] **Step 1: Все проверки**

Run:
```bash
for t in tests/test-*.sh; do [[ "$t" == *public-installation* ]] && continue; bash "$t" | tail -1; done
WARMUP_PLAYWRIGHT=/Users/macbookledovskih/Documents/Projects/AutoMontage-Agent/node_modules/playwright node tests/check-audience-warmup-html.cjs | tail -1
```
Expected: десять `PASS` и `PASS: audience-warmup HTML template ...`.

- [x] **Step 2: Просмотреть итоговую разницу** - `git status --short` и `git diff --stat`; убедиться, что в Git не попадают `skills/audience-warmup-workspace/` и личные данные.

- [x] **Step 3: Удалить `_progress.md`**, дописать итог в общий дневник `~/.memory-core/memory/YYYY-MM-DD.md`.

- [ ] **Step 4: Показать Дмитрию итог** и спросить разрешение на коммит `feat: add audience warmup skill` и push. После разрешения: коммит, push, свежий клон во временную папку, повтор тестов и установки из опубликованной версии, проверка GitHub Actions.
