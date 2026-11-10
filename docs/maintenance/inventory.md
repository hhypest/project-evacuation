# Инвентаризация документации

DOC-01. Основа: `3c9f5d4460f0b713a03ccbd5c572da9af7d4a0b0` (main после PR №39), 49 Markdown-файлов. Это карта переноса для сопровождения; повседневный вход — каталог документации. Машинная карта `migration-map.json` учитывает каждый исходный файл и каждый заголовок. Пути назначения ниже первоначально заданы до переноса.

| Исходный файл | Читатель и роль | Действие | Назначение |
| --- | --- | --- | --- |
| `AGENTS.md` | Участник проекта; действующий документ | Сохранить; добавить маршрут/оглавление | `AGENTS.md` |
| `Architecture.md` | Участник проекта; действующий документ | Разделить по задачам | `Architecture.md`, `docs/architecture/circuits.md`, `docs/architecture/content-and-saves.md`, `docs/architecture/distribution.md`, `docs/architecture/foundation.md`, `docs/architecture/gravity.md`, `docs/architecture/movement.md`, `docs/architecture/portals.md`, `docs/architecture/presentation.md`, `docs/architecture/validation.md` |
| `CHANGELOG.md` | История | Сохранить; добавить маршрут/оглавление | `CHANGELOG.md` |
| `CONTRIBUTING.md` | Участник проекта; действующий документ | Разделить по задачам | `CONTRIBUTING.md`, `docs/design/authoring.md`, `docs/development/assets.md`, `docs/development/checks.md`, `docs/development/coding.md`, `docs/development/release.md`, `docs/getting-started.md` |
| `Readme.md` | Участник проекта; действующий документ | Разделить по задачам | `Readme.md`, `docs/design/risks.md`, `docs/getting-started.md`, `docs/requirements.md`, `docs/roadmap.md` |
| `THIRD_PARTY_NOTICES.md` | Производство; происхождение и права | Сохранить; добавить маршрут/оглавление | `THIRD_PARTY_NOTICES.md` |
| `content/models/README.md` | Производство; происхождение и права | Сохранить; добавить маршрут/оглавление | `content/models/README.md` |
| `content/textures/README.md` | Производство; происхождение и права | Сохранить; добавить маршрут/оглавление | `content/textures/README.md` |
| `docs/adr/0001-foundation-toolchain.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0001-foundation-toolchain.md` |
| `docs/adr/0002-session-input-lifecycle.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0002-session-input-lifecycle.md` |
| `docs/adr/0003-json-save-format.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0003-json-save-format.md` |
| `docs/adr/0004-diegetic-interface.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0004-diegetic-interface.md` |
| `docs/adr/0005-player-locomotion.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0005-player-locomotion.md` |
| `docs/adr/0006-art-direction.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0006-art-direction.md` |
| `docs/adr/0007-physics-carry.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0007-physics-carry.md` |
| `docs/adr/0008-device-network.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0008-device-network.md` |
| `docs/adr/0009-gravity-zones.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0009-gravity-zones.md` |
| `docs/adr/0010-portal-experiment.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0010-portal-experiment.md` |
| `docs/adr/0011-level-rhythm.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0011-level-rhythm.md` |
| `docs/adr/0012-talos-carry.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/0012-talos-carry.md` |
| `docs/adr/template.md` | Решение / история решения | Сохранить; добавить маршрут/оглавление | `docs/adr/template.md` |
| `docs/design/art-production-guide.md` | Участник проекта; действующий документ | Сохранить; добавить маршрут/оглавление | `docs/design/art-production-guide.md` |
| `docs/design/cutscenes.md` | Участник проекта; действующий документ | Сохранить; добавить маршрут/оглавление | `docs/design/cutscenes.md` |
| `docs/design/level-construction.md` | Участник проекта; действующий документ | Разделить по задачам | `docs/design/level-construction.md`, `docs/design/level-metrics.md` |
| `docs/design/level-structure.md` | Участник проекта; действующий документ | Сохранить; добавить маршрут/оглавление | `docs/design/level-structure.md` |
| `docs/design/lore/README.md` | Автор/сценарист; канон или явно отмеченный архив | Разделить по задачам | `docs/design/lore/README.md`, `docs/design/lore/archive/initial-review.md` |
| `docs/design/lore/outline-v2.md` | Автор/сценарист; канон или явно отмеченный архив | Разделить по задачам | `docs/design/lore/archive/outline-v2.md`, `docs/design/lore/outline-v2.md` |
| `docs/design/lore/outline-v3.md` | Автор/сценарист; канон или явно отмеченный архив | Разделить по задачам | `docs/design/lore/archive/outline-v3.md`, `docs/design/lore/outline-v3.md` |
| `docs/design/lore/outline-v4.md` | Автор/сценарист; канон или явно отмеченный архив | Сохранить; добавить маршрут/оглавление | `docs/design/lore/outline-v4.md` |
| `docs/design/lore/pre-bible-checklist.md` | Автор/сценарист; канон или явно отмеченный архив | Разделить по задачам | `docs/design/lore/archive/pre-bible-checklist.md`, `docs/design/lore/pre-bible-checklist.md` |
| `docs/design/lore/world-bible.md` | Автор/сценарист; канон или явно отмеченный архив | Сохранить; добавить маршрут/оглавление | `docs/design/lore/world-bible.md` |
| `docs/design/puzzle-template.md` | Участник проекта; действующий документ | Сохранить; добавить маршрут/оглавление | `docs/design/puzzle-template.md` |
| `docs/design/puzzles/loop.md` | Участник проекта; действующий документ | Сохранить; добавить маршрут/оглавление | `docs/design/puzzles/loop.md` |
| `docs/design/risks.md` | Участник проекта; действующий документ | Сохранить; добавить маршрут/оглавление | `docs/design/risks.md` |
| `docs/documentation-rework.md` | Участник проекта; действующий документ | Сохранить; добавить маршрут/оглавление | `docs/documentation-rework.md` |
| `docs/performance.md` | Участник проекта; действующий документ | Сохранить; добавить маршрут/оглавление | `docs/performance.md` |
| `docs/qa/beam-2026-11-08.md` | Свидетельство; читать по задаче | Сохранить; добавить маршрут/оглавление | `docs/qa/beam-2026-11-08.md` |
| `docs/qa/concept-cube-button-2026-11-09.md` | Свидетельство; читать по задаче | Сохранить; добавить маршрут/оглавление | `docs/qa/concept-cube-button-2026-11-09.md` |
| `docs/qa/concept-optics-2026-11-09.md` | Свидетельство; читать по задаче | Сохранить; добавить маршрут/оглавление | `docs/qa/concept-optics-2026-11-09.md` |
| `docs/qa/devices-circuits-2026-11-08.md` | Свидетельство; читать по задаче | Сохранить; добавить маршрут/оглавление | `docs/qa/devices-circuits-2026-11-08.md` |
| `docs/qa/foundation-2026-11-07.md` | Свидетельство; читать по задаче | Сохранить; добавить маршрут/оглавление | `docs/qa/foundation-2026-11-07.md` |
| `docs/qa/gravity-2026-11-08.md` | Свидетельство; читать по задаче | Сохранить; добавить маршрут/оглавление | `docs/qa/gravity-2026-11-08.md` |
| `docs/qa/physics-carry-2026-11-07.md` | Свидетельство; читать по задаче | Сохранить; добавить маршрут/оглавление | `docs/qa/physics-carry-2026-11-07.md` |
| `docs/qa/player-movement-2026-11-07.md` | Свидетельство; читать по задаче | Сохранить; добавить маршрут/оглавление | `docs/qa/player-movement-2026-11-07.md` |
| `docs/qa/portal-experiment-2026-11-08.md` | Свидетельство; читать по задаче | Сохранить; добавить маршрут/оглавление | `docs/qa/portal-experiment-2026-11-08.md` |
| `docs/qa/profiler-texture-quality-2026-11-09.md` | Свидетельство; читать по задаче | Сохранить; добавить маршрут/оглавление | `docs/qa/profiler-texture-quality-2026-11-09.md` |
| `docs/qa/session-flow-2026-11-07.md` | Свидетельство; читать по задаче | Сохранить; добавить маршрут/оглавление | `docs/qa/session-flow-2026-11-07.md` |
| `docs/status.md` | Текущее состояние | Сохранить; добавить маршрут/оглавление | `docs/status.md` |
| `docs/testing.md` | Участник проекта; действующий документ | Сохранить; добавить маршрут/оглавление | `docs/testing.md` |

## Конфликты и повторы

| Наблюдение | Основной источник | Решение при переносе |
| --- | --- | --- |
| Readme: носители UI «предстоит выбрать»; ADR-0006 уже закрепляет терминал | ADR-0006 и Architecture §13 | Убрать старую формулировку; выбранные носители ещё требуют реализации и приёмки |
| Readme, CONTRIBUTING, AGENTS и testing повторяют команды/критерии | tools/toolchain.json, tools/*.ps1, CI; новая инструкция checks | Один каталог команд и критериев; остальные документы ссылаются на него |
| testing говорит о пяти уровнях, каталог содержит шесть | content/definitions/level_catalog.tres | Исправить счёт; не обещать несуществующие уровни |
| status помечает бег/захват/постановку «на ревью» | Слитые PR №26, 27, 38 | Указать слияние; ручную/художественную приёмку не объявлять выполненной |
| Старые вопросы лора и статусы редакции 2 выглядят актуальными | Библия ART-01; R1 как происхождение решений | Архивировать исходники с пометкой даты/статуса и действующим указателем; текст/решения сохранить |
| Таблица уступов требует куб на 1,2–1,5 м, но duck-jump 1,35 м проверен; стена от 3 м при наличии стопок | MovementProfile, PlayerMotor, ADR-0012, QA движения | Отделить измеренные возможности от предложений геометрии; обязательность куба/стены доказывать на конкретном уровне |
| В level-construction бюджет до двух пар, начальная архитектура — одна пара | Architecture §10/13 и ADR-0010 | Бюджет дизайна отметить кандидатом после профилирования; текущая проверенная граница — одна пара |
| Art guide хранит хронологию заготовок рядом с актуальными правилами | Реестры content и QA | Отделить производственное руководство от истории внедрения; сохранить исходные свидетельства |

Неразрешённых конфликтов двух действующих принятых решений в этой инвентаризации не установлено. Открытые художественные решения катсцен остаются открытыми; редактура их не принимает.

## Зависимые источники

- LICENSE и content/licenses: юридические тексты сохранены без редактуры.
- Три PDF концептов находятся вне репозитория. Имена, 46 страниц и контрольные суммы сохранены в руководстве по арту; повторный просмотр оригиналов здесь не заявляется. Их подписи не создают поручений.
- Встроенные надписи PNG и моделей, происхождение и промты остаются в реестрах content. Сами изображения и модели не меняются.
- tools/setup.ps1, check.ps1, export.ps1, profile.ps1, set_texture_quality.ps1 и .github/workflows/ci.yml сверены с инструкциями. Смена документации не меняет версию редактора, слои или физику.
- Исторические QA сохраняют исходные команды и среду как свидетельства того запуска, даже если актуальный путь инструкции изменился. Состояние сегодня читают в status, не в старом отчёте.
