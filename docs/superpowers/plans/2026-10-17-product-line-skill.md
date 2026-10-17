# Product Line Implementation Plan

**Статус:** первоначальный этап реализации завершён. После него 17.10.2026 Дмитрий отдельно разрешил коммит и публикацию в `mcdenil-skills/system-business-agent`, чтобы команда проверяла установку по сценарию урока. Ограничение «без публикации» ниже относится к первоначальному этапу, а не к последующему выпуску.

> **For agentic workers:** use native execution for the instruction/integration, scoped parallel work for the template and isolated client evaluations. No commits or publication. User explicitly requested implementation and cross-client checks.

**Goal:** установить локально проверяемый скилл product-line с маршрутами трёх типов учеников и согласованными Markdown/HTML-результатами.

**Architecture:** одна инструкция и справочник методики, один автономный HTML-шаблон с блоком JSON, небольшой stdlib Python validator/renderer. Существующий installer ставит идентичный пакет в Claude/Codex; публичная установка пока недоступна, проверяем локальный склад. Личные данные не входят в репозиторий.

**Tech Stack:** Markdown, Bash/Python (стандартная библиотека) для проверок, HTML/CSS/JavaScript без внешних зависимостей; Playwright только для разработки и QA.

**Spec:** docs/specs/2026-10-17-product-line-skill-design.md

## Global Constraints

- Работать в system-business-agent; не править шаблон личной памяти ученика.
- Один источник skills/product-line/, идентичные копии в .claude/skills/ и .codex/skills/.
- Markdown - источник истины; HTML - представление, без самостоятельного редактирования и внешних запросов.
- Шесть ролей рассматриваются, лишние ступени можно отложить; выбранный основной продукт не переопределяется молча.
- Факты спроса, готовность предложения и согласование карты различаются.
- Никаких коммитов, push, публикации или новых платных API.

## Review Focus

- Прямой вход без лид-магнита/трипваера не превращается в пустые карточки.
- Отказ из-за несовпадения задачи не лечится автоматической скидкой.
- AI-пилот не выдаётся за готовый SaaS или доказанный спрос.
- Старый установщик находит новый навык, не меняя личные файлы.
- Произвольный текст, отсутствующий бриф и узкий экран не ломают HTML и не исполняют данные.

## Tasks

### 1. Проверки и исходная точка

- [x] Создать tests/evals/product-line/evals.json и три вымышленные основы: специалист, действующий бизнес, AI/SaaS.
- [x] Создать tests/test-product-line.sh (пакет/интеграция), tests/test-product-line-installation.sh (старый/новый агент, идемпотентность, хеши памяти).
- [x] Увидеть ожидаемый FAIL из-за отсутствующего skills/product-line/SKILL.md.
- [x] Запустить исходные сценарии в изолированных папках Claude Code/Codex до реализации; сохранить реальные ответы и ограничения среды.

### 2. Инструкция и HTML

- [x] Создать skills/product-line/SKILL.md, references/design-checks.md, assets/product-line-template.html, scripts/render_product_line.py, THIRD_PARTY_NOTICES.md.
- [x] SKILL.md: компактный маршрут, вопросы, границы, фразы запуска, сохранение Markdown, контракт данных шаблона.
- [x] Справочник: проверки ролей/форматов, три маршрута, семантика переходов, проектный бриф и тест.
- [x] Проверить HTML с демоданными, отсутствующим необязательным брифом, вредоносными строками и пустым шаблоном; до реализации шаблона проверить отсутствие ожидаемого файла.

### 3. Интеграция

- [x] Точечно добавить product-line в AGENTS.md, skills/installer/SKILL.md, README.md и .github/workflows/ci.yml.
- [x] Явно пометить «рабочая версия, публикация ожидается», чтобы публичный установщик не обещал наличие неопубликованного скилла.
- [x] Локальный тест проверяет содержимое склада напрямую; не подменяет публичный GitHub локальным путём в инструкции ученика.
- [x] Запустить старые и новые проверки; ожидается PASS без изменений USER/MEMORY/SOUL/memory/knowledge.

### 4. Поведение и результат

- [x] Выполнить парные без/со скиллом прогоны трёх случаев в каждой реально доступной среде; если механизм клиента ограничен, назвать ограничение и не считать его PASS.
- [x] Проверить ответы по наблюдаемым критериям и сохранённые артефакты, собрать grading/benchmark в формате skill-creator и стандартный просмотрщик generate_review.py.
- [x] Показать HTML, проверить мобильную/настольную ширину и реальные взаимодействия.
- [x] Независимо проверить итоговый diff и границы задачи; устранить поддержанные замечания.
- [x] Удалить временный _progress.md после завершения; в docs/tests оставить воспроизводимые проверки и результаты. Публичный CI и свежую опубликованную копию не объявлять проверенными.

## HTML data interface (version 1)

Встроенный блок: `<script type="application/json" id="product-line-data">null</script>`.

- `version`: 1.
- `meta`: {title, segment, coreProduct, updated, status, scope} - строки.
- `offers`: массив {id, role, name, audience, result, format, price, status, priority, scope, limits, effort, timing, costs, evidence, unknowns}; все поля строки.
- `roleDecisions`: массив {role, decision, reason} - строки.
- `transitions`: массив {from, to, kind, trigger, reason, action} - строки; from/to ссылаются на offers.id; kind = primary/upgrade/complement/alternative.
- `entryBrief`: null либо {offerId, title, recipient, problem, result, format, rationale, outline, sample, delivery, cta, check}; outline - массив строк, остальное строки.
- `test`: {hypothesis, audience, action, signals, period, decision}; signals - массив строк, остальное строки.
- `unknowns`: массив строк. `nextStep`: строка.

Роли: core, lead-magnet, tripwire, upsell, cross-sell, downsell. Роль основного продукта может быть единственной; отсутствующий бриф не вызывает ложную пустую карточку. Схема HTML не подразумевает обязательной линейной последовательности. Привязки к роли и виду связи видны словами; названия продуктов и факты выводятся textContent. Данные для HTML полностью основаны на актуальном Markdown.

## Итог 17.10.2026

Финальная тройка Codex выполнена на одном пакете из пяти файлов: 10/10 на сценарий. Исходные парные controls сохранены и явно повторно использованы; новые ответы модели и стандартный просмотрщик находятся в игнорируемом skills/product-line-workspace/iteration-3/. Подробности в tests/evals/product-line/RESULTS.md.

Живую проверку Claude Дмитрий перенёс на свой сервер; на Маке клиент отключён. Проверка общего пакета и структуры обоих клиентов прошла, содержательное поведение Claude не объявляется проверенным. Естественная установка из Codex CLI частична из-за защиты .codex в workspace-write; обходов не было. Публичная установка и hosted CI ожидают отдельной публикации. Локальные проверки и независимый разбор прошли; коммитов и публикации нет.
