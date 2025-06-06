<!-- @format -->

# Плейбуки установки Aztec

Данная папка содержит поэтапную систему установки узлов Aztec, разделенную на 4 независимых этапа, а также скрипт для обновления.

## 📋 Файлы в папке

### Плейбуки Ansible:

- `00_fix_docker_sources.yml` - Исправление конфликтов источников Docker (если есть проблемы)
- `01_prepare.yml` - Подготовка серверов (обновление, базовые пакеты, пользователи)
- `02_install_docker.yml` - Установка и настройка Docker
- `03_install_aztec.yml` - Установка узлов Aztec
- `04_update_aztec.yml` - Обновление Aztec до последней версии

### Bash скрипты:

- `run_00_fix_docker_sources.sh` - Исправление проблем с источниками Docker
- `run_01_prepare.sh` - Запуск этапа подготовки серверов
- `run_02_install_docker.sh` - Запуск установки Docker
- `run_03_install_aztec.sh` - Запуск установки Aztec
- `run_04_update_aztec.sh` - Запуск обновления Aztec до последней версии
- `run_all_stages.sh` - Запуск всех этапов подряд
- `fix_docker_sources.sh` - Альтернативный скрипт для исправления Docker sources

## 🚀 Быстрый старт

### Запуск из корня проекта

```bash
# Полная установка за один раз из корня проекта
cd aztec_ansible/install_playbook
./run_all_stages.sh ../common/your_servers.csv

# Или из корня проекта напрямую
bash aztec_ansible/install_playbook/run_all_stages.sh aztec_ansible/common/your_servers.csv
```

### Быстрый запуск

```bash
# 1. Сначала сгенерировать inventory
cd ../../
./generate_hosts.sh your_servers.csv

# 2. Полная установка
cd aztec_ansible/install_playbook
./run_all_stages.sh hosts_your_servers
```

### Поэтапная установка

```bash
# 1. Подготовка серверов и Docker
./run_01_prepare.sh hosts_your_servers

# 2. Установка Aztec
./run_03_install_aztec.sh hosts_your_servers
```

## 🔄 Обновление Aztec

### Обновление до последней версии:

```bash
# Обновить все серверы до последней версии Aztec
./run_04_update_aztec.sh

# С подробными логами
VERBOSE=1 ./run_04_update_aztec.sh

# Использование конкретного inventory
./run_04_update_aztec.sh hosts_1
./run_04_update_aztec.sh hosts_2
```

**Что делает обновление:**

- Проверяет наличие команды `aztec-up` на всех серверах
- Останавливает службу `aztec-node.service`
- Запускает `aztec-up latest` для обновления
- Перезапускает службу после обновления
- Проверяет статус службы

**Время выполнения:** 20-30 минут на сервер

**⚠️ Важно:** Служба будет временно остановлена во время обновления!

## 📝 Работа с множественными inventory

Все скрипты поддерживают работу с разными inventory файлами. По умолчанию используется `hosts`, но можно указать любой другой файл:

### Структура inventory:

```
aztec_ansible/common/inventory/
├── hosts           # Основной inventory (по умолчанию)
├── hosts_1         # Первая группа серверов
├── hosts_2         # Вторая группа серверов
└── hosts_test      # Тестовые серверы
```

### Примеры использования:

```bash
# Использование по умолчанию (hosts)
./run_02_install_docker.sh
./run_03_install_aztec.sh
./run_04_update_aztec.sh

# Использование конкретного inventory
./run_02_install_docker.sh hosts_1
./run_03_install_aztec.sh hosts_1
./run_04_update_aztec.sh hosts_1

# Параллельная работа с разными группами
./run_04_update_aztec.sh hosts_1 &
./run_04_update_aztec.sh hosts_2 &
wait

# Справка по использованию
./run_04_update_aztec.sh --help
```

### Создание нескольких inventory:

```bash
# Подготовка разных групп серверов
./run_01_prepare.sh ../common/servers_group1.csv  # Создаст hosts
mv ../common/inventory/hosts ../common/inventory/hosts_1

./run_01_prepare.sh ../common/servers_group2.csv  # Создаст hosts
mv ../common/inventory/hosts ../common/inventory/hosts_2

# Теперь можно работать с каждой группой отдельно
./run_02_install_docker.sh hosts_1
./run_02_install_docker.sh hosts_2
```

### Множественные группы серверов

```bash
# Генерация inventory для групп
cd ../../
./generate_hosts.sh servers_group1.csv  # Создаст hosts_servers_group1
./generate_hosts.sh servers_group2.csv  # Создаст hosts_servers_group2

# Установка для групп
cd aztec_ansible/install_playbook
./run_01_prepare.sh hosts_servers_group1
./run_03_install_aztec.sh hosts_servers_group1

./run_01_prepare.sh hosts_servers_group2
./run_03_install_aztec.sh hosts_servers_group2
```

## 📝 Детали этапов

### Этап 0: Исправление проблем с Docker sources (опционально)

**Когда нужен:**

- При ошибках типа "Conflicting values set for option Signed-By"
- При конфликтах репозиториев Docker в apt sources
- После неудачных предыдущих установок Docker

**Что делает:**

- Создает резервные копии текущих источников apt
- Удаляет все записи Docker из `/etc/apt/sources.list`
- Очищает папку `/etc/apt/sources.list.d/` от файлов Docker
- Удаляет старые GPG ключи Docker
- Очищает кэш apt и обновляет список пакетов

**Время выполнения:** 1-2 минуты на сервер

### Этап 1: Подготовка серверов

**Что делает:**

- Обновляет список пакетов системы
- Устанавливает базовые утилиты (curl, wget, htop и др.)
- Проверяет ресурсы сервера
- Создает лог файл подготовки

**Время выполнения:** 3-5 минут на сервер

### Этап 2: Установка Docker

**Что делает:**

- Удаляет старые версии Docker
- Добавляет официальный репозиторий Docker
- Устанавливает Docker CE и утилиты
- Добавляет пользователя ubuntu в группу docker
- Запускает и включает службу Docker
- Тестирует работу Docker

**Время выполнения:** 5-10 минут на сервер

### Этап 3: Установка Aztec

**Что делает:**

- Скачивает скрипт Install.sh из репозитория
- Устанавливает переменные окружения (IP адрес, Ethereum адрес, приватный ключ)
- Запускает установку Aztec
- Создает маркер успешной установки
- Проверяет статус службы

**Время выполнения:** 20-30 минут на сервер

### Этап 4: Обновление Aztec

**Что делает:**

- Проверяет наличие команды `aztec-up` на серверах
- Останавливает службу `aztec-node.service`
- Выполняет команду `aztec-up latest`
- Перезапускает службу после обновления
- Создает маркер успешного обновления
- Логирует процесс обновления

**Время выполнения:** 20-30 минут на сервер

## 🔧 Дополнительные возможности

### Переменные окружения:

```bash
# Принудительная переустановка
FORCE=1 ./run_02_install_docker.sh

# Подробные логи Ansible
VERBOSE=1 ./run_01_prepare.sh hosts_servers

# Принудительная очистка Docker sources
FORCE=1 ./run_00_fix_docker_sources.sh

# Подробные логи при обновлении
VERBOSE=1 ./run_04_update_aztec.sh
```

### Идемпотентность:

Все этапы можно запускать повторно - они автоматически пропустят уже выполненные действия.

## 🚨 Исправление проблем с Docker

### Проблема: "Conflicting values set for option Signed-By"

Если при установке Docker вы получаете ошибки типа:

```
E: Conflicting values set for option Signed-By regarding source https://download.docker.com/linux/ubuntu/ focal: /usr/share/keyrings/docker-archive-keyring.gpg !=
```

**Решение:**

```bash
# Запустите скрипт исправления Docker sources
./run_00_fix_docker_sources.sh

# Затем повторите установку Docker
./run_02_install_docker.sh
```

### Альтернативное решение:

```bash
# Используйте альтернативный скрипт
./fix_docker_sources.sh
```

## 📊 Централизованные логи

Все скрипты записывают логи в общую папку `../logs/`:

### Файлы логов:

- `fix_docker_sources_[inventory]_YYYYMMDD_HHMMSS.log` - логи исправления Docker sources
- `prepare_YYYYMMDD_HHMMSS.log` - логи подготовки серверов
- `docker_[inventory]_YYYYMMDD_HHMMSS.log` - логи установки Docker
- `aztec_[inventory]_YYYYMMDD_HHMMSS.log` - логи установки Aztec
- `aztec_update_[inventory]_YYYYMMDD_HHMMSS.log` - логи обновления Aztec
- `complete_install_YYYYMMDD_HHMMSS.log` - общий лог полной установки

### Просмотр логов:

```bash
# Все логи
ls ../logs/

# Последние логи полной установки
tail -f ../logs/complete_install_*.log

# Логи конкретного inventory
tail -f ../logs/*_hosts_1_*.log
tail -f ../logs/*_hosts_2_*.log

# Последние логи определенного этапа
tail -f ../logs/fix_docker_sources_*.log
tail -f ../logs/prepare_*.log
tail -f ../logs/docker_*.log
tail -f ../logs/aztec_*.log
tail -f ../logs/aztec_update_*.log
```

## 🎯 Преимущества поэтапной установки

1. **Гибкость** - можно остановиться на любом этапе
2. **Отладка** - легче найти проблему
3. **Переиспользование** - Docker установленный один раз можно использовать для разных проектов
4. **Экономия времени** - при повторной установке можно пропустить подготовку
5. **Контроль** - полный контроль над процессом установки
6. **Исправление проблем** - специальный этап для решения проблем с Docker sources
7. **Обновления** - простое обновление до новых версий Aztec

## 🚨 Требования

Перед запуском убедитесь что:

1. SSH ключ размещен в `../common/ssh/id_rsa` с правами 600
2. CSV файл содержит колонки: IP, ADDRESS, PRIVATE_KEY
3. У пользователя ubuntu есть права sudo без пароля на всех серверах
4. Ansible установлен и настроен
5. Для обновления: Aztec уже установлен на серверах и команда `aztec-up` доступна

## 📚 Дополнительная информация

Полную документацию смотрите в [../README.md](../README.md)
