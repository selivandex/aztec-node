<!-- @format -->

# Улучшения плейбуков Aztec

## Основные улучшения:

### 1. Плейбук установки:

- ✅ Идемпотентность (не переустанавливает если уже установлено)
- ✅ Обработка ошибок с блоками rescue
- ✅ Детальное логирование на каждом сервере
- ✅ Timeout защита (30 минут)
- ✅ Retry механизм для скачивания

### 2. Плейбук сбора proof:

- ✅ Безопасная запись CSV через temp файлы
- ✅ Расширенная информация (статус, timestamp)
- ✅ Timeout защита (5 минут)
- ✅ Connectivity test перед сбором
- ✅ Детальная статистика результатов

### 3. Bash скрипты:

- ✅ Строгая обработка ошибок (set -euo pipefail)
- ✅ Цветной вывод для удобства
- ✅ Проверка зависимостей и SSH ключей
- ✅ Централизованное логирование в общую папку
- ✅ Анализ результатов с статистикой

### 4. Python скрипт:

- ✅ Поддержка разных названий колонок
- ✅ Детальные сообщения об ошибках
- ✅ Цветной вывод
- ✅ Гибкая обработка CSV файлов

### 5. Ansible конфигурация:

- ✅ SSH connection pooling для ускорения
- ✅ Retry механизмы
- ✅ Логирование операций
- ✅ Кэширование фактов
- ✅ Оптимизация производительности

### 6. Поэтапная установка:

- ✅ Разделение на 3 независимых этапа
- ✅ Возможность запуска отдельных этапов
- ✅ Лучший контроль процесса установки
- ✅ Упрощенная отладка проблем

### 7. Переменные окружения:

- ✅ Автоматическая передача IP адреса сервера
- ✅ Передача Ethereum адреса и приватного ключа
- ✅ Настройка L1 RPC URLs для всех серверов
- ✅ Полная изоляция конфигурации каждого сервера

## Новые возможности:

```bash
# Полная установка за один раз
./run_all_stages.sh servers.csv

# Поэтапная установка
./run_01_prepare.sh servers.csv      # Подготовка серверов
./run_02_install_docker.sh           # Установка Docker
./run_03_install_aztec.sh            # Установка Aztec

# Принудительная переустановка
FORCE=1 ./run_02_install_docker.sh

# Подробные логи
VERBOSE=1 ./run_01_prepare.sh servers.csv

# Custom timeout для proof
TIMEOUT=600 ./run_get_proof.sh servers.csv
```

## Централизованное логирование:

Все логи теперь сохраняются в общую папку `logs/`:

### Файлы логов:

- `prepare_YYYYMMDD_HHMMSS.log` - логи подготовки серверов
- `docker_YYYYMMDD_HHMMSS.log` - логи установки Docker
- `aztec_YYYYMMDD_HHMMSS.log` - логи установки Aztec
- `complete_install_YYYYMMDD_HHMMSS.log` - общий лог полной установки
- `proof_collection_YYYYMMDD_HHMMSS.log` - логи сбора proof
- `proof_summary_YYYYMMDD_HHMMSS.txt` - статистика результатов
- `ansible.log` - общий лог Ansible (в common/)

### Преимущества централизации:

- 🔍 Все логи в одном месте
- 📁 Удобная организация по времени
- 🔒 Автоматическое исключение из git
- 📊 Простой анализ результатов
- 🛠️ Упрощенная отладка проблем
