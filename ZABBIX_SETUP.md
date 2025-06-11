<!-- @format -->

# Быстрая настройка мониторинга Zabbix для Aztec

Краткая инструкция по настройке мониторинга Aztec узлов в Zabbix.

## Быстрый старт

### 1. Импорт шаблона в Zabbix

```bash
# Откройте веб-интерфейс Zabbix
# Перейдите в Configuration → Templates → Import
# Загрузите файл: aztec_zabbix_template.xml
```

### 2. Автоматическое добавление хостов

```bash
# Из корня проекта
ZABBIX_SERVER=http://your-zabbix-server/zabbix \
ZABBIX_USER=Admin \
ZABBIX_PASSWORD=your-password \
./run_06_add_host_to_zabbix.sh

# Или из директории плейбука
cd aztec_ansible/add_zabbix_hosts_playbook/
ZABBIX_SERVER=http://your-zabbix-server/zabbix \
ZABBIX_USER=Admin \
ZABBIX_PASSWORD=your-password \
./run_06_add_host_to_zabbix.sh
```

### 3. Проверка без изменений (dry run)

```bash
ZABBIX_SERVER=http://your-zabbix-server/zabbix \
ZABBIX_USER=Admin \
ZABBIX_PASSWORD=your-password \
./run_06_add_host_to_zabbix.sh --check
```

## Что мониторится

- **Сервис Aztec** - статус и время работы
- **RPC подключение** - доступность порта 8080 и ответы API
- **Синхронизация** - статус синхронизации с сетью
- **Блокчейн** - текущий номер блока

## Структура файлов

```
aztec_ansible/add_zabbix_hosts_playbook/
├── add_hosts_to_zabbix.yml       # Ansible плейбук
├── add_aztec_hosts_to_zabbix.sh  # Основной скрипт для работы с Zabbix API
├── run_06_add_host_to_zabbix.sh  # Обертка-скрипт для запуска
└── README.md                     # Подробная документация

aztec_zabbix_template.xml         # Шаблон для импорта в Zabbix
run_06_add_host_to_zabbix.sh      # Символическая ссылка (удобство)
```

## Требования

- Ansible
- Python3 с модулем json
- curl
- Доступ к Zabbix серверу с правами на создание хостов

## Полная документация

Подробная инструкция со всеми опциями и примерами находится в:
**[aztec_ansible/add_zabbix_hosts_playbook/README.md](aztec_ansible/add_zabbix_hosts_playbook/README.md)**

## Устранение неполадок

### Частые ошибки

**"Template not found"** → Импортируйте `aztec_zabbix_template.xml` в Zabbix

**"Authentication failed"** → Проверьте URL, логин и пароль Zabbix

**"ansible-playbook not found"** → Установите Ansible: `pip install ansible`

### Отладка

```bash
# Подробный вывод
./run_06_add_host_to_zabbix.sh --verbose

# Максимальная детализация
./run_06_add_host_to_zabbix.sh -vvv
```

## Поддержка

При проблемах проверьте:

1. Статус Zabbix сервера
2. Правильность конфигурации
3. Формат файла инвентаря
4. Права пользователя в Zabbix
