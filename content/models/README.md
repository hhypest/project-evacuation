# Модели устройств

Дата: 2026-11-09. Первые модели человеческого слоя, принятые владельцем в игру: балластный куб и напольная кнопка. Обе модели сгенерированы в Meshy по API, а затем приведены к игровым размерам скриптом [`tools/art/normalize_meshy.py`](../../tools/art/normalize_meshy.py).

Модели — только внешний вид. Коллизии остаются проверенными примитивами: куб — `BoxShape3D`, плита — бокс 1,4 × 0,1 × 1,4 м. Поэтому замена арта не меняет физику и проходимость (ADR-0006, ART-04).

## Состав

| Папка | Что внутри | Размер в игре | Где используется |
| --- | --- | --- | --- |
| `devices/ballast_cube` | Один узел `Cube`, ≈24,6 тыс. треугольников, текстуры 2K | Ровно 1 × 1 × 1 м, центр в начале координат; для других рёбер масштабируется | [`PropVisuals.ballast_cube`](../../src/infrastructure/content/prop_visuals.gd): кубы всех уровней, `TestCube` полигона |
| `devices/floor_button` | Узел `Frame` (рамка, ≈18,9 тыс. треугольников) и узел `Plate` (верх плиты, ≈2,6 тыс.), текстуры 2K | Низ на y = 0, верх плиты на 0,1 м, край плиты ±0,7 м, рамка ≈1,66 м | [`FloorButtonDevice`](../../src/infrastructure/devices/floor_button_device.gd): `Plate` при нажатии опускается на 3 см |

Модели хранятся как `.gltf` + `.bin`, а текстуры лежат рядом в исходном JPEG. Godot импортирует их как обычные текстуры: VRAM-сжатие, mip-уровни, карта нормалей — с `compress/normal_map`. Эмиссия Meshy (пустая) отброшена. Свечение задаёт код по семантике ADR-0006: янтарная полоса по краю плиты — это отдельная геометрия устройства. Эта полоса заодно закрывает углубление, которое остаётся, когда плита утоплена.

## Происхождение и права (реестр ART-07)

| Поле | Значение |
| --- | --- |
| Генератор | Meshy API, `text-to-3d`: preview `ai_model=latest` (Meshy 7.1) для куба, `meshy-6` для кнопки; refine с PBR, текстуры 2K |
| Задачи Meshy | Куб: preview `01a1bfe7-dd10-7029-aaaf-d9f2a1c2f25a`, refine `01a1bfe9-f03f-70c3-b010-c00adf9f7d32`. Кнопка: preview `01a1bfea-05ac-70f1-861a-37fb7d876b4c`, refine `01a1bfec-5bd0-74ba-b3f4-d2f0e84ad882` |
| Дата | 2026-11-09 |
| Аккаунт и тариф | Аккаунт владельца проекта; доступ к API есть только с платного тарифа Pro, поэтому по условиям Meshy результат принадлежит пользователю и указывать Meshy не обязательно |
| Обработка человеком/кодом | Масштаб и точка опоры, разрез кнопки на рамку и плиту по краю плиты, без изменения текстур |
| Промты | Ниже |
| ИИ-контент для анкеты Steam | Да: модели и текстуры созданы генеративной моделью |
| Лицензия распространения в репозитории | **Не определена — нужно решение владельца.** Код скрипта нормализации — MIT |

Исходные GLB из Meshy в репозиторий не входят. Их можно повторно скачать по ID задач из аккаунта владельца.

### Промты

Куб, preview:

> Heavy industrial ballast cube for a sci-fi expedition, a perfect cube with chamfered protective steel edges and bolted corner guards, a recessed grab handle in the middle of every face, painted steel panels, a small recessed round indicator lamp in one face, a blank rectangular serial plate. Rugged, heavy but carriable by one person. Grounded hard sci-fi industrial realism. Single object, no text, no logos.

Куб, refine (texture_prompt):

> Off-white painted steel panels (#E8E4DC) with safety-orange (#E06B2D) diagonal stripes on the corner guards, dark grey bare steel on edges, bolts and inside the handle wells, chipped and scuffed paint along edges and handles, dust in recesses, a small neutral white lamp lens, a blank light grey serial plate. Realistic industrial PBR. No text, no letters, no logos, no cyan, no green.

Кнопка, preview (`meshy-6`, третья попытка; две предыдущие отклонены — лоток с дырами и круглый люк):

> A very flat square industrial floor plate, like a large manhole cover lying on the floor: square, 1.8 m wide and only 10 cm tall, solid closed top, a square diamond-pattern steel pressure plate in the middle surrounded by a slightly lower beveled steel border frame, thin gap between plate and border, a short armored cable gland on one side. Solid watertight mesh, no openings, no box, no tray. Hard sci-fi industrial. No text, no logos.

Кнопка, refine (texture_prompt):

> Central square pressure plate of worn galvanized diamond-pattern steel, scuffed shiny where it is stepped on. Surrounding border frame painted dark grey steel with black and safety-orange (#E06B2D) diagonal hazard stripes on its bevel. A thin dark recessed groove around the plate edge (unlit lamp channel). Dust and grime in gaps, chipped paint on corners, dark armored cable gland. Realistic industrial PBR. No text, no letters, no logos, no cyan, no green, no yellow.

## Известные отступления

- **Куб:** в оранжевых полосах есть жёлтые ромбы, болты бледно-голубоватые. Ни то, ни другое не игровой сигнал, но строго по палитре это не совпадает. Крышка сверху почти белая и при прямом свете выглядит плоской.
- **Кнопка:** чёрно-оранжевых полос на рамке нет, рамка стальная с голубоватым оттенком. Шляпки рифления и болты плиты выступают над коллизией до 3 см.
- Обе модели проверены на Vulkan через программный llvmpipe. Проверка на опорном GPU и у новых игроков впереди (SLICE-02/03).

## Пересборка

```powershell
python tools/art/normalize_meshy.py cube   <ballast_cube_raw.glb> content/models/devices/ballast_cube
python tools/art/normalize_meshy.py button <floor_button_raw.glb> content/models/devices/floor_button
& $env:GODOT_BIN --headless --path . --import
```

Скрипту нужны Python 3.10+ и numpy. Параметры импорта текстур в `*.jpg.import` выставлены вручную: VRAM Compressed, mipmaps, Normal Map для `*_normal.jpg`. Пересборка без удаления `.import` их сохраняет.
