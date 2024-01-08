Rob Corovans
============

- [Описание](#описание)
- [UserStory](#userstory)
- [Фичи](#фичи)
- [Установка на windows](#установка-на-windows)

## Описание

Диалоговая 2D игра с видом сверху. [Диздок](https://wikireality.ru/wiki/%D0%93%D1%80%D0%B0%D0%B1%D0%B8%D1%82%D1%8C_%D0%BA%D0%BE%D1%80%D0%BE%D0%B2%D0%B0%D0%BD%D1%8B).

![corovans](https://raw.githubusercontent.com/EvgeniyLupanov1024/EvgeniyLupanov1024/main/projects_media/RobCorovans/corovans.gif)

## UserStory

*[спройлеры]*

Игра проходится за 15 минут. Игрок попадает в пустыню, где разговаривает с эльфом и продвигает сюжет грабя корованы, которые проходят по дороге во время диалога.

## Фичи

*[спройлеры]*
- Генерируемая поверхность: карта и дорога генерируются при запуске игры
- Конус видимости: объекты за спиной игрока не отображаются. Объекты на переферии отображаются частично
- Погода: сила и направление ветра меняются со временем и влияют на перемещение объектов по сцене (в том числе игрока) *// TODO: спрайты во время шторма*
- Диалоги: побуквенный вывод текста с разбиением на строки и анимацией исчезновения
- Введение: экраны обучения и музыкального интро
- Край карты: можно выйти за край карты. Край карты и объекты растворяются в воздухе при приближении к границе  
- Следы на песке: игрок и корованеры оставляют при передвижении следы, исчезающие со временем
- Можно грабить корованы: да
- Две концовки

## Установка на windows

Скрипт можно запустить среде dasbox. Сам дашбокс можно найти в [репозитории](https://github.com/imp5imp5/dasbox): архив `dasbox_portable.zip` в одном из [релизов](https://github.com/imp5imp5/dasbox/releases/tag/dasbox_portable_0_1_84). В архиве лежит dasbox.exe и папки с проектами.

Чтобы запустить игру, нужно: 
- скачать и распаковать архив с dasbox
- создать папку `projects` в одной директории с dasbox.exe
- скачать файлы репозитория с игрой (этого репозитория: кнопка `<>code` - `download zip`)
- создать папку для игры внутри директории `projects`
- распаковать файлы архива в папку игры (`projects/RobCorovans/файлы игры` по аналогии с другими проектами)
- запустить dasbox.exe  