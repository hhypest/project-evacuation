# Модели устройств

Дата: 2026-11-09. Первые модели человеческого слоя, принятые владельцем в игру: балластный куб, напольная кнопка, настенная кнопка, ручной переключатель, эмиттер и приёмник луча, логическая коробка. Все модели сгенерированы в Meshy по API, а затем приведены к игровым размерам скриптом [`tools/art/normalize_meshy.py`](../../tools/art/normalize_meshy.py).

Модели — только внешний вид. Коллизии остаются проверенными примитивами: куб — `BoxShape3D`, плита — бокс 1,4 × 0,1 × 1,4 м, настенное устройство — бокс 0,36 × 0,5 × 0,16 м в обоих режимах, эмиттер и приёмник — их прежние боксы; у логической коробки коллизии нет, как и раньше. Поэтому замена арта не меняет физику и проходимость (ADR-0006, ART-04).

## Состав

| Папка | Что внутри | Размер в игре | Где используется |
| --- | --- | --- | --- |
| `devices/ballast_cube` | Один узел `Cube`, ≈24,6 тыс. треугольников, текстуры 2K | Ровно 1 × 1 × 1 м, центр в начале координат; для других рёбер масштабируется | [`PropVisuals.ballast_cube`](../../src/infrastructure/content/prop_visuals.gd): кубы всех уровней, `TestCube` полигона |
| `devices/floor_button` | Узел `Frame` (рамка, ≈18,9 тыс. треугольников) и узел `Plate` (верх плиты, ≈2,6 тыс.), текстуры 2K | Низ на y = 0, верх плиты на 0,1 м, край плиты ±0,7 м, рамка ≈1,66 м | [`FloorButtonDevice`](../../src/infrastructure/devices/floor_button_device.gd): `Plate` при нажатии опускается на 3 см |
| `devices/wall_button` | `wall_button_body` (корпус с оранжевым козырьком, ≈16,5 тыс.) и `wall_button_key` (клавиша, ≈5 тыс.) | Корпус 0,34 × 0,56 × 0,18 м, задняя грань на z = −0,08; клавиша шириной 0,1 м | [`WallButtonDevice`](../../src/infrastructure/devices/wall_button_device.gd) в режиме TIMED: клавиша при нажатии уходит на 1,5 см, лампа на круглом окне |
| `devices/wall_switch` | `wall_switch_body` (щиток с прорезью, ≈16,2 тыс.) и `wall_switch_lever` (рычаг с Т-рукоятью, ≈5,9 тыс.) | Щиток 0,32 × 0,5 × 0,12 м, задняя грань на z = −0,08; рычаг 0,22 м от оси | `WallButtonDevice` в режиме TOGGLE: рычаг стоит на ±31° — влево выключен, вправо включён, лампа в окне сверху |
| `devices/emitter` | `emitter_body` (корпус на ножках, ≈21,6 тыс.) | Корпус 0,5 × 0,5 × 0,7 м по центру узла, линза на оси −Z | [`EmitterDevice`](../../src/infrastructure/devices/emitter_device.gd): циановый диск линзы, луч и лампа сзади — код |
| `devices/receiver` | `receiver_body` (рама с тарелкой, ≈20,2 тыс.) | Плита 0,6 × 0,6 × 0,25 м по центру узла, тарелка на оси +Z | [`ReceiverDevice`](../../src/infrastructure/devices/receiver_device.gd): циановая рамка, диск попадания в тарелке и лампа — код |
| `devices/logic_box` | `logic_box` (распределительная коробка, ≈16 тыс.) | 0,44 × 0,44 × 0,16 м по центру узла, крышка к +Z | [`LogicDevice`](../../src/infrastructure/devices/logic_device.gd): один корпус на все шесть типов; тип — надпись на светлой табличке в нише крышки, лампа в углу — код |

Модели хранятся как `.gltf` + `.bin`, а текстуры лежат рядом в исходном JPEG. Godot импортирует их как обычные текстуры: VRAM-сжатие, mip-уровни, карта нормалей — с `compress/normal_map`. Эмиссия Meshy (пустая) отброшена. Свечение задаёт код по семантике ADR-0006: янтарная полоса по краю плиты — это отдельная геометрия устройства. Эта полоса заодно закрывает углубление, которое остаётся, когда плита утоплена.

## Происхождение и права (реестр ART-07)

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

- **Куб:** после перекраски — светло-серые грани, оранжевые канты по всем рёбрам и уголки, тёмный крепёж. Серые грани чуть холоднее образца `#E8E4DC`.
- **Кнопка:** после перекраски — чёрно-оранжевые полосы по рамке; оранжевый в полосах чуть теплее и желтее `#E06B2D`. Рифлёная плита под холодным светом отдаёт голубым — это отражение стали, а не краска. Шляпки рифления и болты плиты выступают над коллизией до 3 см.
- **Настенная кнопка:** клавиша меньше исходного эскиза (0,1 м вместо 0,18 м) — под нишу корпуса; лампа — отдельный квадрат на круглом окне корпуса.
- **Переключатель:** рукоять рычага вышла тёмной, а не оранжевой; щиток уже коллизии на 2 см с каждой стороны.
- **Эмиттер:** линза в исходной модели стоит не по центру торца, поэтому модель сдвинута на 4 и 8 см, чтобы линза легла на ось луча; ножки выходят за коллизию на 8 см вниз и в настенной и потолочной установке («Петля») висят в воздухе. Оранжевой полосы почти нет — только пятна.
- **Приёмник:** глубину исходного блока пришлось сжать примерно втрое (до 0,25 м), боковые детали стали плоскими; концентрическая разметка тарелки светло-серая.
- **Логическая коробка:** в центре утопленной панели модели есть тёмный квадрат — его закрывает светлая табличка с типом.
- Подписи режима («4 с», «⟳», «A», «B») — временные `Label3D`, как и раньше; диегетическая маркировка — задача ART-02.
- Все модели проверены на Vulkan через программный llvmpipe. Проверка на опорном GPU и у новых игроков впереди (SLICE-02/03).

## Пересборка

```powershell
python tools/art/normalize_meshy.py cube   <ballast_cube_raw.glb> content/models/devices/ballast_cube
python tools/art/normalize_meshy.py button <floor_button_raw.glb> content/models/devices/floor_button
python tools/art/normalize_meshy.py wall_button_body  <raw.glb> content/models/devices/wall_button
python tools/art/normalize_meshy.py wall_button_key   <raw.glb> content/models/devices/wall_button
python tools/art/normalize_meshy.py wall_switch_body  <raw.glb> content/models/devices/wall_switch
python tools/art/normalize_meshy.py wall_switch_lever <raw.glb> content/models/devices/wall_switch
python tools/art/normalize_meshy.py emitter_body      <raw.glb> content/models/devices/emitter
python tools/art/normalize_meshy.py receiver_body     <raw.glb> content/models/devices/receiver
python tools/art/normalize_meshy.py logic_box         <raw.glb> content/models/devices/logic_box
& $env:GODOT_BIN --headless --path . --import
```

Скрипту нужны Python 3.10+ и numpy. Параметры импорта текстур в `*.jpg.import` выставлены вручную: VRAM Compressed, mipmaps, Normal Map для `*_normal.jpg`. Пересборка без удаления `.import` их сохраняет.
