<!-- @format -->

# Автоматическое добавление Aztec хостов в Zabbix

Этот Ansible плейбук автоматизирует процесс добавления Aztec хостов в систему мониторинга Zabbix.

## Требования

- Ansible (установленный на управляющей машине)
- Python3 с модулем `json`
- curl
- Доступ к Zabbix серверу с правами на создание хостов
- Импортированный шаблон "Template Aztec Node Monitoring" в Zabbix

## Структура файлов

```
aztec_ansible/
├── add_zabbix_hosts_playbook/
│   ├── add_hosts_to_zabbix.yml       # Ansible плейбук
│   ├── add_aztec_hosts_to_zabbix.sh  # Основной скрипт для работы с Zabbix API
│   ├── run_06_add_host_to_zabbix.sh  # Обертка-скрипт для запуска через Ansible
│   └── README.md                     # Эта инструкция
├── common/
│   └── inventory/
│       └── hosts                     # Файл инвентаря с хостами
└── ...

# В корне проекта
└── aztec_zabbix_template.xml         # Шаблон Zabbix для импорта
```

## Быстрый старт

### 1. Импорт шаблона в Zabbix

Сначала импортируйте шаблон в ваш Zabbix сервер:

```bash
# Откройте Zabbix веб-интерфейс
# Перейдите в Configuration → Templates
# Нажмите Import
# Загрузите файл aztec_zabbix_template.xml
```

### 2. Подготовка инвентаря

Убедитесь, что файл `aztec_ansible/common/inventory/hosts` содержит ваши Aztec хосты в правильном формате:

```ini
[aztec_nodes]
aztec-node-1 ansible_host=10.0.1.100
aztec-node-2 ansible_host=10.0.1.101
aztec-node-3 ansible_host=10.0.1.102
```

### 3. Запуск через обертку-скрипт (рекомендуется)

```bash
# Переходим в директорию с плейбуком
cd aztec_ansible/add_zabbix_hosts_playbook/

# Базовое использование
ZABBIX_SERVER=http://your-zabbix-server/zabbix \
ZABBIX_USER=Admin \
ZABBIX_PASSWORD=your-password \
./run_06_add_host_to_zabbix.sh

# С кастомным файлом инвентаря
ZABBIX_SERVER=http://your-zabbix-server/zabbix \
ZABBIX_USER=Admin \
ZABBIX_PASSWORD=your-password \
./run_06_add_host_to_zabbix.sh /path/to/custom/inventory

# Verbose режим
ZABBIX_SERVER=http://your-zabbix-server/zabbix \
ZABBIX_USER=Admin \
ZABBIX_PASSWORD=your-password \
./run_06_add_host_to_zabbix.sh --verbose

# Dry run (проверка без внесения изменений)
ZABBIX_SERVER=http://your-zabbix-server/zabbix \
ZABBIX_USER=Admin \
ZABBIX_PASSWORD=your-password \
./run_06_add_host_to_zabbix.sh --check
```

### 4. Прямой запуск Ansible плейбука

```bash
# Переходим в директорию с плейбуком
cd aztec_ansible/add_zabbix_hosts_playbook/

# Экспорт переменных окружения
export ZABBIX_SERVER=http://your-zabbix-server/zabbix
export ZABBIX_USER=Admin
export ZABBIX_PASSWORD=your-password

# Запуск плейбука
ansible-playbook add_hosts_to_zabbix.yml
```

## Параметры конфигурации

### Переменные окружения (обязательные)

| Переменная        | Описание                   | Пример                             |
| ----------------- | -------------------------- | ---------------------------------- |
| `ZABBIX_SERVER`   | URL Zabbix сервера         | `http://zabbix.example.com/zabbix` |
| `ZABBIX_USER`     | Имя пользователя Zabbix    | `Admin`                            |
| `ZABBIX_PASSWORD` | Пароль пользователя Zabbix | `secretpassword`                   |

### Параметры плейбука

| Параметр              | Описание                         | По умолчанию                     |
| --------------------- | -------------------------------- | -------------------------------- |
| `inventory_file_path` | Путь к файлу инвентаря           | `../common/inventory/hosts`      |
| `script_file_path`    | Путь к скрипту добавления хостов | `./add_aztec_hosts_to_zabbix.sh` |

### Опции обертки-скрипта

| Опция               | Описание                                    |
| ------------------- | ------------------------------------------- |
| `-h, --help`        | Показать справку                            |
| `-v, --verbose`     | Включить подробный вывод                    |
| `-s, --script-path` | Указать путь к скрипту                      |
| `--check`           | Запуск в режиме проверки (dry run)          |
| `--tags`            | Запустить только задачи с указанными тегами |
| `--skip-tags`       | Пропустить задачи с указанными тегами       |

## Что делает плейбук

1. **Проверка переменных окружения** - убеждается, что все необходимые переменные установлены
2. **Проверка файлов** - проверяет существование файла инвентаря и скрипта
3. **Подготовка скрипта** - делает скрипт исполняемым
4. **Запуск скрипта добавления хостов** - выполняет основной скрипт с переданными параметрами
5. **Отображение результатов** - показывает вывод выполнения и ошибки

## Устранение неполадок

### Частые ошибки

**Ошибка: "ansible-playbook is not installed"**

```bash
# Установите Ansible
pip install ansible
# или
brew install ansible  # на macOS
```

**Ошибка: "Template 'Template Aztec Node Monitoring' not found"**

- Убедитесь, что шаблон импортирован в Zabbix
- Проверьте точность названия шаблона

**Ошибка: "Authentication failed"**

- Проверьте правильность URL Zabbix сервера
- Убедитесь в корректности логина и пароля
- Проверьте, что пользователь имеет права на создание хостов

**Ошибка: "Inventory file not found"**

- Проверьте путь к файлу инвентаря
- Убедитесь, что файл существует и доступен для чтения

### Отладка

Для получения подробной информации используйте:

```bash
# Максимальный уровень детализации
ZABBIX_SERVER=... ./run_06_add_host_to_zabbix.sh -vvv

# Проверка без внесения изменений
ZABBIX_SERVER=... ./run_06_add_host_to_zabbix.sh --check --verbose
```

### Логи

Плейбук выводит подробную информацию о:

- Конфигурации подключения
- Процессе добавления каждого хоста
- Ошибках и их причинах
- Результате выполнения

## Расширение функциональности

### Добавление новых переменных

Чтобы добавить новые переменные конфигурации, отредактируйте:

1. `aztec_ansible/add_zabbix_hosts_playbook/add_hosts_to_zabbix.yml` - добавьте переменную в секцию `vars`
2. `run_06_add_host_to_zabbix.sh` - добавьте поддержку новой переменной
3. `add_aztec_hosts_to_zabbix.sh` - обновите скрипт для использования новой переменной

### Кастомизация шаблона

Вы можете изменить название шаблона и группы хостов, отредактировав переменные в `add_aztec_hosts_to_zabbix.sh`:

```bash
TEMPLATE_NAME="Your Custom Template Name"
HOSTGROUP_NAME="Your Custom Group Name"
```

## Примеры использования

### Производственная среда

```bash
cd aztec_ansible/add_zabbix_hosts_playbook/
ZABBIX_SERVER=https://monitoring.company.com/zabbix \
ZABBIX_USER=zabbix-admin \
ZABBIX_PASSWORD=$(cat /secure/zabbix-password) \
./run_06_add_host_to_zabbix.sh production-inventory.ini --verbose
```

### Тестовая среда

```bash
cd aztec_ansible/add_zabbix_hosts_playbook/
ZABBIX_SERVER=http://test-zabbix:8080/zabbix \
ZABBIX_USER=testuser \
ZABBIX_PASSWORD=testpass \
./run_06_add_host_to_zabbix.sh test-hosts.ini --check
```

### CI/CD интеграция

```bash
#!/bin/bash
# В CI/CD пайплайне
cd aztec_ansible/add_zabbix_hosts_playbook/
export ZABBIX_SERVER="$ZABBIX_URL"
export ZABBIX_USER="$ZABBIX_USERNAME"
export ZABBIX_PASSWORD="$ZABBIX_SECRET"

./run_06_add_host_to_zabbix.sh "$INVENTORY_FILE" --verbose || exit 1
```

## Поддержка

При возникновении проблем:

1. Проверьте статус Zabbix сервера
2. Убедитесь в правильности конфигурации
3. Запустите в режиме отладки с `--verbose`
4. Проверьте логи Ansible
5. Проверьте формат файла инвентаря
