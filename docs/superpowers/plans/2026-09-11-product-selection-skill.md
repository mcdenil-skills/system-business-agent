# Product Selection Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Создать устанавливаемый скилл `product-selection`, который помогает участнику выбрать продукт версии 1 на основе распаковки, интернет-фактов, проблемных интервью и первого денежного теста.

**Architecture:** Один канонический `SKILL.md` хранит весь пользовательский сценарий без лишних шаблонов и зависимостей. Общий установщик копирует одинаковую папку навыка в Claude и Codex, а оболочечные проверки контролируют методологические гейты и сохранность памяти.

**Tech Stack:** Markdown/YAML, автономный HTML/CSS/JavaScript как результат работы скилла, Bash + ripgrep для проверок, GitHub Actions.

**Spec:** `docs/specs/2026-09-11-product-selection-skill-design.md`

## Global Constraints

- Скилл работает одинаково в Claude Code и Codex.
- Интернет-проверка с прямыми ссылками обязательна до окончательной рекомендации.
- Wordstat не требует API: сначала браузер, затем ручная передача скриншота или данных.
- Один цикл проверяет один сегмент и одну главную гипотезу.
- Три независимых повтора значимой проблемы позволяют выбрать продукт версии 1; только предоплата или оплата даёт статус «подтверждён деньгами».
- Markdown является источником истины; HTML автономен, интерактивен и не добавляет новых выводов.
- Не создавать дополнительные шаблоны, сервисы и скрипты внутри скилла без подтверждённой повторяемой необходимости.

---

### Task 1: Зафиксировать проверяемый контракт скилла

**Files:**
- Create: `tests/test-product-selection.sh`
- Create: `tests/test-product-selection-installation.sh`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: критерии готовности из спецификации.
- Produces: команды `bash tests/test-product-selection.sh` и `bash tests/test-product-selection-installation.sh`.

- [x] **Step 1: Написать структурную проверку**

Проверить через `rg`, что будущий `SKILL.md` содержит имя, вход `knowledge/my-expertise.md`, три вида интернет-сигналов, прямые ссылки и даты, Wordstat-fallback, лёгкий JTBD, семь вопросов, порог из трёх интервью, предоплату, три итоговых файла, HTML без внешних библиотек и подтверждение перед памятью.

- [x] **Step 2: Запустить проверку и увидеть ожидаемую ошибку**

Run: `bash tests/test-product-selection.sh`

Expected: `FAIL: missing product-selection/SKILL.md`.

- [x] **Step 3: Написать проверку двойной установки**

Скопировать скилл в тестовые `.claude/skills/product-selection/` и `.codex/skills/product-selection/`, сравнить версии и хэши `USER.md`, `MEMORY.md` и контрольного файла в `knowledge/`.

- [x] **Step 4: Подключить обе проверки к CI**

Добавить два шага с точными командами:

```yaml
      - name: Проверить скилл выбора продукта
        run: bash tests/test-product-selection.sh

      - name: Проверить установку скилла выбора продукта
        run: bash tests/test-product-selection-installation.sh
```

### Task 2: Создать канонический скилл

**Files:**
- Create: `skills/product-selection/SKILL.md`

**Interfaces:**
- Consumes: `USER.md`, `MEMORY.md`, последние дневники, `knowledge/my-expertise.md`, при продолжении `knowledge/product-choice.md`.
- Produces: `knowledge/product-choice.md`, после трёх повторов проблемы — `knowledge/my-product.md` и `knowledge/my-product.html`.

- [x] **Step 1: Создать метаданные и границы**

Использовать `name: product-selection` и описание, которое включается при выборе продукта, проверке спроса, кастдеве и денежном тесте, но не при распаковке экспертности или маркетинге готового продукта.

- [x] **Step 2: Описать сценарий с состояниями**

Зафиксировать состояния «гипотезы → интернет → интервью → деньги → решение», чтение существующего прогресса и продолжение без повторного опроса.

- [x] **Step 3: Встроить обязательный интернет-фактчекинг**

Для каждого доказательства хранить тезис, прямой URL, дату, тип сигнала, границу доказательства и уверенность. При отсутствии интернета останавливать окончательный выбор, но выдавать ручной маршрут без терминала.

- [x] **Step 4: Встроить лёгкий JTBD и проблемное интервью**

Использовать формулу «ситуация → желаемый прогресс → препятствие → альтернатива», семь нейтральных вопросов и два необязательных B2B-вопроса.

- [x] **Step 5: Встроить денежный гейт и результаты**

После трёх независимых повторов выбрать продукт версии 1 со статусом «проверяем деньгами», запросить предоплату и только после реального платежа ставить статус «подтверждён деньгами».

- [x] **Step 6: Описать Markdown и автономный HTML**

Markdown хранит факты и решение. HTML пересобирается из него, показывает краткий/подробный режим, доказательства, статус интервью и оплаты, раскрываемые блоки и печать/PDF без внешних библиотек.

- [x] **Step 7: Запустить структурную проверку**

Run: `bash tests/test-product-selection.sh`

Expected: `PASS: product-selection structure`.

### Task 3: Подключить скилл к агенту и установщику

**Files:**
- Modify: `skills/installer/SKILL.md`
- Modify: `AGENTS.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: папку `skills/product-selection/`.
- Produces: короткую пользовательскую команду установки и одинаковую установку для Claude/Codex.

- [x] **Step 1: Добавить навык в карту установщика**

Добавить техническое имя `product-selection` и проверочную фразу «Помоги выбрать и проверить мой первый продукт».

- [x] **Step 2: Добавить навык в реестр агента**

Добавить статус «не установлен», потому что в стартовую поставку входит только `installer`.

- [x] **Step 3: Добавить простой пример в README**

Показать две команды: установка распаковки и установка выбора продукта после неё.

- [x] **Step 4: Запустить проверку установки**

Run: `bash tests/test-product-selection-installation.sh`

Expected: `PASS: product-selection installs in both environments without changing memory`.

### Task 4: Подготовить тестовые пользовательские сценарии

**Files:**
- Create: `tests/evals/product-selection/evals.json`

**Interfaces:**
- Consumes: готовый `skills/product-selection/SKILL.md`.
- Produces: три реалистичных сценария для отдельного сравнения работы со скиллом и без него.

- [x] **Step 1: Записать три сценария без формальных ожиданий**

Сценарии: специалист после распаковки; предприниматель с новым AI-направлением; возврат с пятью интервью и неоднозначным денежным тестом.

- [x] **Step 2: Проверить JSON**

Run: `python3 -m json.tool tests/evals/product-selection/evals.json >/dev/null`

Expected: exit code `0`.

- [ ] **Step 3: Показать сценарии владельцу продукта**

До запуска сравнительных прогонов получить подтверждение, что ситуации похожи на реальных учеников.

### Task 5: Финальная проверка проекта

**Files:**
- Modify: `_progress.md`

**Interfaces:**
- Consumes: все созданные и изменённые файлы.
- Produces: воспроизводимый зелёный набор проверок и честный статус незавершённого пользовательского тестирования.

- [x] **Step 1: Запустить все проверки**

Run:

```bash
bash tests/test-system-business-template.sh
bash tests/test-expertise-unpacking.sh
bash tests/test-expertise-installation.sh
bash tests/test-product-selection.sh
bash tests/test-product-selection-installation.sh
python3 -m json.tool tests/evals/product-selection/evals.json >/dev/null
```

Expected: все Bash-проверки печатают `PASS`, JSON валиден.

- [x] **Step 2: Проверить diff и отсутствие секретов**

Run: `git diff --check && git status --short`

Expected: нет ошибок пробелов; меняются только спецификация, план, скилл, тесты, установщик, реестр, README и прогресс.

- [x] **Step 3: Обновить прогресс**

Отметить создание скилла, интеграцию и технические проверки. Сравнительные пользовательские прогоны оставить отдельным следующим этапом до подтверждения тестовых сценариев.
