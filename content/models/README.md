# Модели устройств

Дата: 2026-11-09. Встроенные модели человеческого слоя: балластный куб, напольная кнопка, настенная кнопка, ручной переключатель, эмиттер и приёмник луча, логическая коробка, створки двери. Все модели сгенерированы в Meshy по API, а затем приведены к игровым размерам скриптом [`tools/art/normalize_meshy.py`](../../tools/art/normalize_meshy.py). Текущие ревизии куба/кнопки и эмиттера/приёмника сделаны по концептам DEV-01/02 и DEV-05/06 по поручению владельца; художественная приёмка замен ещё впереди.

Модели — только внешний вид. Коллизии остаются проверенными примитивами: куб — `BoxShape3D`, плита — бокс 1,4 × 0,1 × 1,4 м, настенное устройство — бокс 0,36 × 0,5 × 0,16 м в обоих режимах, эмиттер и приёмник — их прежние боксы; у логической коробки коллизии нет, как и раньше; рама и створки двери — прежние боксы. Поэтому замена арта не меняет физику и проходимость (ADR-0006, ART-04).

## Состав

| Папка | Что внутри | Размер в игре | Где используется |
| --- | --- | --- | --- |
| `devices/ballast_cube` | DEV-01: один узел `Cube`, 23 752 треугольника, PBR 4K | Ровно 1 × 1 × 1 м, центр в начале координат; для других рёбер масштабируется | [`PropVisuals.ballast_cube`](../../src/infrastructure/content/prop_visuals.gd): кубы всех уровней, `TestCube` полигона |
| `devices/floor_button` | DEV-02: `Frame` (20 326 треугольников), `Plate` (3 203), PBR 4K | Низ на y = 0, верх плиты на 0,1 м, плита ≈1,39 м внутри коллизии 1,4 м, рамка ≈2,02 м | [`FloorButtonDevice`](../../src/infrastructure/devices/floor_button_device.gd): вся видимая плита с боковинами опускается на 3 см |
| `devices/wall_button` | `wall_button_body` (корпус с оранжевым козырьком, ≈16,5 тыс.) и `wall_button_key` (клавиша, ≈5 тыс.) | Корпус 0,34 × 0,56 × 0,18 м, задняя грань на z = −0,08; клавиша шириной 0,1 м | [`WallButtonDevice`](../../src/infrastructure/devices/wall_button_device.gd) в режиме TIMED: клавиша при нажатии уходит на 1,5 см, лампа на круглом окне |
| `devices/wall_switch` | `wall_switch_body` (щиток с прорезью, ≈16,2 тыс.) и `wall_switch_lever` (рычаг с Т-рукоятью, ≈5,9 тыс.) | Щиток 0,32 × 0,5 × 0,12 м, задняя грань на z = −0,08; рычаг 0,22 м от оси | `WallButtonDevice` в режиме TOGGLE: рычаг стоит на ±31° — влево выключен, вправо включён, лампа в окне сверху |
| `devices/emitter` | DEV-05: `emitter_body`, 23 935 треугольников, PBR 4K/2K | Видимая модель 0,5 × 0,433 × 0,7 м, линза на оси −Z; прежняя коллизия 0,5 × 0,5 × 0,7 м | [`EmitterDevice`](../../src/infrastructure/devices/emitter_device.gd): линза радиусом 0,116 м, луч и лампа сзади — код |
| `devices/receiver` | DEV-06: `receiver_body`, 24 256 треугольников, PBR 4K/2K | Модель 0,6 × 0,808 × 0,25 м с подставкой ниже оси; прежняя коллизия 0,6 × 0,6 × 0,25 м | [`ReceiverDevice`](../../src/infrastructure/devices/receiver_device.gd): круглые оптическая кромка и диск попадания радиусом 0,148 м, лампа на основании — код |
| `devices/logic_box` | `logic_box` (распределительная коробка, ≈16 тыс.) | 0,44 × 0,44 × 0,16 м по центру узла, крышка к +Z | [`LogicDevice`](../../src/infrastructure/devices/logic_device.gd): один корпус на все шесть типов; тип — надпись на светлой табличке в нише крышки, лампа в углу — код |
| `devices/door` | `door_leaf` (створка с бортом и ручкой, ≈11,4 тыс.) | 1,0 × 2,6 × 0,15 м по центру, ручка на краю +X | [`DoorDevice`](../../src/infrastructure/devices/door_device.gd): левая створка как есть, правая повёрнута на 180°, обе масштабируются под размер створки. Рама — не модель: её коллизионные боксы одеты в материалы проекта (`panel_light`, `metal_dark`, `hazard_stripes`, трипланарно) |

Модели хранятся как `.gltf` + `.bin`, а текстуры лежат рядом в исходном JPEG или PNG согласно MIME-типу генератора. Godot импортирует их как обычные текстуры: VRAM-сжатие, mip-уровни, карта нормалей — с `compress/normal_map`. Свечение задаёт код по семантике ADR-0006: четыре янтарные полосы находятся в тёмном канале вокруг плиты, остаются на рамке и выключаются вместе с сигналом.

## Замена куба и кнопки по концептам DEV-01/DEV-02

Источник — `Abandoned_Meshy_Concepts.zip`, изображения `images/DEV-01.png` и `images/DEV-02.png`; в `Abandoned_Meshy_Catalog.pdf` это страницы 9 и 10. Это визуальные референсы, а не источник новых механик, массы или лицензии. Идентификаторы, параметры запросов, промты, SHA-256 исходников и результата сохранены в [реестре ревизии](cube-floor-button-2026-11-09.json). Условия распространения новых моделей и текстур — прежний MIT для `content/models/devices` по принятому решению владельца; сами 2D-референсы в репозиторий не добавлены.

- **Геометрия:** Image to 3D `meshy-7.1`, `geometry_resolution=2k`, без улучшения исходного изображения, треугольный remesh с ориентиром 25 000 граней, PBR 4K. Куб — `01a1c0c7-e776-709c-bda1-a76ff839dd5d`; кнопка — `01a1c0c7-fcd7-7364-a1e7-751510d51d4f`.
- **Фактическое разрешение карт:** цвет и normal map — 4096 × 4096 у обеих моделей; metallic/roughness — 2048 × 2048. Параметр Meshy `texture_resolution=4k` не увеличил упакованную карту metallic/roughness до 4K.
- **Текстура куба:** первая генерация перенесла выдуманную надпись `MASS 12.5T` из концепта. Через Meshy Image to Image удалены надписи (`01a1c0cc-355c-71f6-8ace-a53dc8d87403`), затем Retexture `meshy-7` с сохранением UV (`01a1c0cc-9c11-76cc-bc4b-f680a3aedea5`). Игровая масса остаётся параметром существующего физического тела.
- **Кнопка:** режим нормализации `button_concept`, измеренный край белой плиты ±0,66 в исходнике. Отделяются верх и боковины плиты; тёмный канал и наружная рама остаются неподвижны. Новая рама шире старой (≈2,02 вместо 1,66 м), её геометрия декоративная. Коллизия плиты, нагрузка, пороги и сеть устройств прежние.
- **Расход этой ревизии:** 35 + 35 кредитов за две модели, 4 за очистку референса и 10 за текстуру куба — **84 кредита**. Это расход выполненных задач, не текущий баланс аккаунта.
- **Проверка:** [QA ревизии](../../docs/qa/concept-cube-button-2026-11-09.md); отдельная сцена `tools/art/device_models_smoke.gd` проверяет размеры, ход плиты, масштабирование, отсутствие добавленной физики и сохраняет кадры на Vulkan. Ручное прохождение и художественная приёмка владельцем этой ревизии не выполнены.

## Эмиттер и приёмник по концептам DEV-05/DEV-06

Референсы — `images/DEV-05.png` и `images/DEV-06.png` из `Abandoned_Meshy_Concepts.zip`. Сначала через Meshy Image to Image погашены линзы и удалена псевдомаркировка без изменения конструкции: состояния питания не запекаются в текстуру. Затем Image to 3D `meshy-7.1`, геометрия 2K, remesh с ориентиром 25 000 треугольников и `texture_resolution=4k`. Цвет/нормали фактически 4096 × 4096, metallic/roughness — 2048 × 2048.

| Объект | Image to Image | Image to 3D |
| --- | --- | --- |
| DEV-05 | `01a1c0da-c083-7703-96aa-d231b62f059c` | `01a1c0db-7631-7564-86a2-72989f0c0c93` |
| DEV-06 | `01a1c0da-c916-7129-9074-a62ae9eb2e0b` | `01a1c0db-8487-7793-b116-4f5fe72142db` |

Полные параметры, промт подготовки, хеши исходников и игровых файлов — в [реестре оптики](emitter-receiver-2026-11-09.json). Расход этой пары: 4 + 4 + 35 + 35 = **78 кредитов**. Новые модели и текстуры входят в прежнюю область MIT для `content/models/devices`; референсы в репозиторий не копируются.

Режимы нормализации `emitter_concept` и `receiver_concept` совмещают линзы с существующей осью луча. Приёмник сохраняет круглый обод и подставку, поэтому видимая высота больше коллизионного бокса. Его диск находится на z = 0,125 м — на плоскости физического попадания; луч заканчивается на линзе. Светящаяся квадратная рамка прежней модели заменена круглой кромкой. Линза эмиттера загорается от питания, приёмник и его лампа — от принятого попадания после существующего антидребезга. При перекрытии луча приёмник гаснет, эмиттер остаётся включённым. Каналы, угол приёма, длина трассировки и физические тела прежние.

Свидетельства и ограничения — [QA оптики](../../docs/qa/concept-optics-2026-11-09.md). Художественная приёмка владельцем ещё впереди.

## Происхождение и права (реестр ART-07)

Ниже — история первоначальной генерации устройств; текущие ревизии куба/кнопки и эмиттера/приёмника описаны отдельно.

| Поле | Значение |
| --- | --- |
| Генератор | Meshy API, `text-to-3d`: preview `ai_model=latest` (Meshy 7.1) для куба, `meshy-6` для кнопки; refine с PBR, текстуры 2K |
| Задачи Meshy | Куб: preview `01a1bfe7-dd10-7029-aaaf-d9f2a1c2f25a`, refine `01a1bffe-15e5-70a5-a005-f283f8ff68bd`. Кнопка: preview `01a1bfea-05ac-70f1-861a-37fb7d876b4c`, refine `01a1bffb-cd84-7398-8690-d56726b67fa1`. Перекраска 2026-11-09 по решению владельца; отклонённые текстуры — refine `01a1bfe9-…`, `01a1bffb-c38d-…`, `01a1bffe-1f87-…` (куб) и `01a1bfec-…` (кнопка) |
| Дата | 2026-11-09 |
| Аккаунт и тариф | Аккаунт владельца проекта; доступ к API есть только с платного тарифа Pro, поэтому по условиям Meshy результат принадлежит пользователю и указывать Meshy не обязательно |
| Обработка человеком/кодом | Масштаб и точка опоры, разрез кнопки на рамку и плиту по краю плиты, без изменения текстур |
| Промты | Ниже |
| ИИ-контент для анкеты Steam | Да: модели и текстуры созданы генеративной моделью |
| Лицензия | **MIT**, как остальной проект ([LICENSE](../../LICENSE)), — решение владельца 2026-11-09. Область: модели, `.bin`, текстуры и `.import` в `content/models/devices`. Скрипт нормализации — тоже MIT |

Настенные устройства (2026-11-09, тот же аккаунт и та же лицензия MIT; подвижные части сгенерированы отдельными объектами, чтобы их не вырезать из корпуса):

| Деталь | Preview | Refine | Отклонено |
| --- | --- | --- | --- |
| Корпус кнопки | `01a1c00b-9788-722d-a7bb-1f5ce465e41f` | `01a1c00c-f4bc-70b1-8f02-3fc66c219e1d` | preview `01a1c009-d8bf-…` — антенна сверху |
| Клавиша | `01a1c009-e150-7730-9392-230fc2cafedf` | `01a1c00b-a8bf-7779-acd1-a74485b51aa8` | — |
| Щиток переключателя | `01a1c009-ec81-74be-a348-0eb008667eff` | `01a1c00b-b350-771b-bec9-be29a49a5c68` | — |
| Рычаг | `01a1c00b-9fdb-77ff-9800-8fc346ecdcde` | `01a1c00c-fce8-70e2-a856-a3a663b93895` | preview `01a1c009-f6f3-…` — похож на отвёртку |

Оптика (2026-11-09, тот же аккаунт и лицензия MIT; циановое только в коде, на текстурах — «no cyan»):

| Деталь | Preview | Refine | Отклонено |
| --- | --- | --- | --- |
| Эмиттер | `01a1c01e-8855-7068-98a1-ea511bed32a3` | `01a1c020-af24-751a-8a8b-e2242f74be30` | preview `01a1c01c-ffdd-…` — ствол вбок и под углом; `01a1c01e-90ba-…` (meshy-6) — линза на длинной стороне |
| Приёмник | `01a1c01d-0ad0-76d8-953a-4e94ae64280b` | `01a1c01e-94cb-722d-8cea-df82a5d2625d` | — |

Логическая коробка (2026-11-09, тот же аккаунт и лицензия MIT): preview `01a1c038-72c3-722f-a98e-337a6cff7079`, refine `01a1c03a-623e-71a1-b090-8a0bde062146`, с первой попытки. Промт: квадратный настенный щиток 44 × 44 × 16 см с плоской спинкой, болтовая крышка с пустой утопленной панелью под табличку, окно лампы в правом верхнем углу, кабельные вводы сверху и снизу; refine — светло-серый `#C8C5BE`, оранжевые уголки, белая панель `#E8E4DC`, тёмный крепёж, «no text, no symbols».

Створка двери (2026-11-09, тот же аккаунт и лицензия MIT): preview `01a1c044-50e0-7526-b36b-b491ac0af673` (`meshy-6`), refine `01a1c046-8947-7733-98cc-c116a0c3d421`. Отклонено: створка `01a1c041-7c42-…` — сетка рассыпалась на обрывки; рама `01a1c041-72e7-…` — круглое кольцо вместо прямоугольной рамы, `01a1c044-4779-…` — пропорции 4 : 3 и панели внутри проёма. Поэтому рама собрана из коллизионных боксов с материалами проекта. Промт створки: цельная стальная плита 1,0 × 2,6 × 0,15 м, рёбра жёсткости, бортик, утопленная ручка у края, заклёпки, «solid watertight closed mesh»; refine — серая сталь `#5C6266`, тёмный металл `#3A4146`, чёрно-оранжевая полоса.

Исходные GLB из Meshy в репозиторий не входят. Их можно повторно скачать по ID задач из аккаунта владельца.

### Промты

Куб, preview:

> Heavy industrial ballast cube for a sci-fi expedition, a perfect cube with chamfered protective steel edges and bolted corner guards, a recessed grab handle in the middle of every face, painted steel panels, a small recessed round indicator lamp in one face, a blank rectangular serial plate. Rugged, heavy but carriable by one person. Grounded hard sci-fi industrial realism. Single object, no text, no logos.

Куб, refine (texture_prompt, принятый вариант):

> Industrial ballast cube. Face panels painted light grey (#C8C5BE), matte, with grime and scuffs. Wide bright safety-orange (#E06B2D) painted bands run along every edge of the cube, framing each face. Corner guards, bolts and handles are dark gunmetal grey steel (#3A4146), worn to bare metal at the tips. Chipped paint, dust in recesses. Realistic industrial PBR. No yellow, no blue, no brass, no gold, no text, no logos.

Кнопка, preview (`meshy-6`, третья попытка; две предыдущие отклонены — лоток с дырами и круглый люк):

> A very flat square industrial floor plate, like a large manhole cover lying on the floor: square, 1.8 m wide and only 10 cm tall, solid closed top, a square diamond-pattern steel pressure plate in the middle surrounded by a slightly lower beveled steel border frame, thin gap between plate and border, a short armored cable gland on one side. Solid watertight mesh, no openings, no box, no tray. Hard sci-fi industrial. No text, no logos.

Кнопка, refine (texture_prompt, принятый вариант):

> Central square pressure plate of worn galvanized diamond-pattern steel, scuffed brighter where it is stepped on. The outer border frame is painted dark charcoal grey (#2A2E31) with bold diagonal black and safety-orange (#E06B2D) hazard stripes all around its top bevel. Dark steel bolts, a thin dark groove around the plate edge, dark armored cable gland. Dust and grime in gaps, chipped paint on corners. Realistic industrial PBR. No blue, no teal, no cyan, no green, no yellow, no text, no letters, no logos.

Настенные устройства, preview (сокращённо; полный текст — в истории сессии и в задачах Meshy):

- корпус кнопки: компактный стальной ящик 36 × 50 × 16 см с плоской спинкой, козырёк над лицевой гранью, квадратная ниша под клавишу, окно лампы, пустая табличка, фланцы, кабельный ввод снизу; «ничего не торчит сверху: no antenna, no pipes, no rods»;
- клавиша: крупная квадратная промышленная клавиша с резиновой вогнутой поверхностью на коротком толкателе;
- щиток: настенный рубильник 36 × 50 × 16 см с вертикальной прорезью под рычаг (сам рычаг не входит), рёбра по бокам прорези, окно лампы, болты, кабельный ввод;
- рычаг: рукоять большого рубильника — плоский стальной рычаг 4 × 25 см, Т-образная резиновая рукоять, ступица с болтом; «not a tool, not a screwdriver».

Refine: светло-серая окраска `#C8C5BE`, оранжевый `#E06B2D` (козырёк, канты, рукоять), тёмный металл `#3A4146`, клавиша — тёмная резина `#1E2124`; везде «no yellow, no blue, no cyan, no green, no text, no logos».

Оптика, preview (сокращённо): эмиттер — прямоугольный корпус 50 × 50 × 70 см на коротких ножках, круглая линза строго в центре торца с прямым соосным кожухом («coaxial, centred, perfectly straight»), рёбра охлаждения сзади, окно лампы, кабель снизу; приёмник — квадратный блок 60 × 60 × 25 см, на лицевой грани приподнятая квадратная рамка вокруг круглой утопленной тарелки («empty, dark, no light»), окно лампы сверху, кронштейн сзади. Refine: светло-серый `#C8C5BE`, тёмный металл `#3A4146`, линза и тарелка — тёмные `#1E2124`, «no cyan, no glow».

## Известные отступления

- **Куб DEV-01:** изображение задаёт только видимые стороны; скрытые грани достроены Meshy. Ручки и защитные углы слегка несимметричны; куб не имеет состояния питания.
- **Кнопка DEV-02:** прямоугольная область разреза приближает скруглённый край плиты; наружная декоративная рама шире коллизии. Четыре управляемых полосы заменяют нарисованное свечение концепта. PBR-карты 4K увеличивают размер ресурсов; отдельный замер стоимости кадра не выполнен.
- **Настенная кнопка:** клавиша меньше исходного эскиза (0,1 м вместо 0,18 м) — под нишу корпуса; лампа — отдельный квадрат на круглом окне корпуса.
- **Переключатель:** рукоять рычага вышла тёмной, а не оранжевой; щиток уже коллизии на 2 см с каждой стороны.
- **Эмиттер DEV-05:** общий размер подогнан под прежний бокс; скрытая сторона достроена Meshy, линзы и детали торцов получились симметричными. Рабочая линза и луч задаются только на −Z. Опоры модели входят в габарит бокса; при потолочном размещении поворачивается весь прибор.
- **Приёмник DEV-06:** круглая часть сохраняет пропорции, основание ниже коллизии на ≈21 см и впереди неё на ≈7,5 см. Это декоративная геометрия; глубина модели сжата до 0,25 м. Скрытая сторона достроена Meshy и повторяет оптический мотив. Отдельный замер производительности карт 4K не выполнен.
- **Логическая коробка:** в центре утопленной панели модели есть тёмный квадрат — его закрывает светлая табличка с типом.
- **Дверь:** сталь створок с голубоватым оттенком, оранжевый в полосе чуть желтее `#E06B2D`. Правая створка показывает обратную сторону модели — она текстурирована так же, но не повторяет лицевую точно.
- Подписи режима («4 с», «⟳», «A», «B») — временные `Label3D`, как и раньше; диегетическая маркировка — задача ART-02.
- Первоначальные модели проверены на Vulkan через программный llvmpipe. Ревизии DEV-01/02 и DEV-05/06 проверены на RTX 4070 Ti SUPER; оценка владельцем и у новых игроков впереди (SLICE-02/03).

## Пересборка

```powershell
python tools/art/normalize_meshy.py cube   <ballast_cube_raw.glb> content/models/devices/ballast_cube
python tools/art/normalize_meshy.py button <floor_button_raw.glb> content/models/devices/floor_button
python tools/art/normalize_meshy.py button_concept <DEV-02_raw.glb> content/models/devices/floor_button
python tools/art/normalize_meshy.py wall_button_body  <raw.glb> content/models/devices/wall_button
python tools/art/normalize_meshy.py wall_button_key   <raw.glb> content/models/devices/wall_button
python tools/art/normalize_meshy.py wall_switch_body  <raw.glb> content/models/devices/wall_switch
python tools/art/normalize_meshy.py wall_switch_lever <raw.glb> content/models/devices/wall_switch
python tools/art/normalize_meshy.py emitter_body      <raw.glb> content/models/devices/emitter
python tools/art/normalize_meshy.py receiver_body     <raw.glb> content/models/devices/receiver
python tools/art/normalize_meshy.py emitter_concept  <DEV-05_raw.glb> content/models/devices/emitter
python tools/art/normalize_meshy.py receiver_concept <DEV-06_raw.glb> content/models/devices/receiver
python tools/art/normalize_meshy.py logic_box         <raw.glb> content/models/devices/logic_box
python tools/art/normalize_meshy.py door_leaf         <raw.glb> content/models/devices/door
& $env:GODOT_BIN --headless --path . --import
```

Скрипту нужны Python 3.10+ и numpy. Параметры импорта текстур в `*.jpg.import` выставлены вручную: VRAM Compressed, mipmaps, Normal Map для `*_normal.jpg`. Пересборка без удаления `.import` их сохраняет.
