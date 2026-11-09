# DeviceDeck для macOS

DeviceDeck — открытое приложение управления совместимыми Bluetooth-наушниками из меню macOS. Это fork HeyBuds; лицензия GPL и необходимые уведомления сохранены. Проект развивается в публичном [репозитории DeviceDeck-macOS](https://github.com/Basil-AS/DeviceDeck-macOS).

Статус модели и конкретной функции смотрите в [матрице совместимости](docs/SUPPORTED_DEVICES.md). DeviceDeck объединяет профили Edifier, Baseus, realme и других брендов в одном приложении; наличие модели в каталоге или успешный симулированный тест не подтверждают работу с физическим устройством. Новые функции W820NB Plus и Baseus требуют проверки на соответствующих моделях и прошивках.

## Сборка

Нужны Apple Silicon, Swift 6.4 и macOS 27 SDK. Приложение рассчитано на macOS 15+.

```sh
git clone https://github.com/Basil-AS/DeviceDeck-macOS.git
cd DeviceDeck-macOS
swift test --no-parallel
bash scripts/build.sh
open dist/DeviceDeck.app
```

Сборка создаёт `dist/DeviceDeck.app` и `dist/DeviceDeck-macos-arm64.dmg`. Кнопка проверки обновлений открывает [страницу Releases](https://github.com/Basil-AS/DeviceDeck-macOS/releases); приложение не устанавливает обновления автоматически.

CI публикует релизы по тегам `macos-v<version>`. До получения Developer ID сертификата сборка ad-hoc подписана и не нотариально заверена Apple; macOS может потребовать вручную разрешить запуск в настройках безопасности.

## Разработка и лицензия

Ветки: `main` — релизы, `develop` — интеграция, изменения идут через feature PR в `develop`. Подробности сборки и публикации — в [RELEASING.md](docs/RELEASING.md); архитектура — в [ARCHITECTURE.md](docs/ARCHITECTURE.md).

Код распространяется по [GPL-3.0-or-later](LICENSE). Источники протоколов, лицензии и атрибуция перечислены в [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). DeviceDeck не связан с производителями перечисленных устройств.
