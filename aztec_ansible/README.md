<!-- @format -->

# Установка узлов Aztec с использованием Ansible

Этот набор плейбуков позволяет автоматизировать установку узлов Aztec на множество серверов одновременно, а также собирать proof данные с установленных узлов.

## 🚀 Ключевые возможности

Плейбуки оптимизированы для надежности и удобства использования:

- ✅ **Поэтапная установка** - разделение на 3 независимых этапа
- ✅ **Идемпотентность** - безопасное повторное выполнение
- ✅ **Обработка ошибок** - graceful failures с детальными логами
- ✅ **Timeout защита** - предотвращение зависания
- ✅ **Retry механизмы** - автоматические повторы при сбоях
- ✅ **Цветной вывод** - удобная визуализация процесса
- ✅ **Централизованное логирование** - все логи в одной папке
- ✅ **Статистика результатов** - анализ успешности выполнения

Подробнее в [IMPROVEMENTS.md](IMPROVEMENTS.md)

## Структура проекта

```
aztec_ansible/
├── common/                  # Общие файлы для плейбуков
│   ├── ansible.cfg          # Конфигурация Ansible
│   ├── csv_to_inventory.py  # Скрипт для конвертации CSV в инвентарь
│   ├── test_ssh.sh          # Скрипт для тестирования SSH подключений
│   ├── ssh/                 # SSH ключи для подключения к серверам
│   │   └── README.md        # Инструкции по размещению SSH ключей
│   └── vars/                # Директория для переменных (создается автоматически)
│       └── server_vars.yml  # Общие переменные (L1_RPC_URL, L1_CONSENSUS_URL)
├── install_playbook/        # Плейбуки для установки узлов (3 этапа)
│   ├── 01_prepare.yml       # Подготовка серверов
│   ├── 02_install_docker.yml # Установка Docker
│   ├── 03_install_aztec.yml # Установка Aztec
│   ├── run_01_prepare.sh    # Скрипт этапа 1
│   ├── run_02_install_docker.sh # Скрипт этапа 2
│   ├── run_03_install_aztec.sh  # Скрипт этапа 3
│   └── run_all_stages.sh    # Запуск всех этапов сразу
├── get_proof_playbook/      # Плейбук для сбора proof данных
│   ├── get_proof.yml        # Плейбук сбора proof
│   ├── run_get_proof.sh     # Скрипт запуска сбора proof
│   └── README.md            # Документация по сбору proof
├── logs/                    # Централизованные логи всех операций
├── IMPROVEMENTS.md          # Детальное описание улучшений
└── README.md                # Данный файл с инструкциями
```

## Требования

- Python 3
- Ansible (версия 2.9+)
- Файл CSV со списком серверов
- SSH ключ для подключения к серверам
- SSH доступ к серверам с правами sudo без пароля

## Подготовка SSH ключей

**ВАЖНО**: Перед использованием плейбуков необходимо настроить SSH ключи:

1. **Поместите ваш приватный SSH ключ** в папку `common/ssh/`:

   ```bash
   cp /path/to/your/private_key aztec_ansible/common/ssh/id_rsa
   chmod 600 aztec_ansible/common/ssh/id_rsa
   ```

2. **Убедитесь, что публичный ключ установлен** на всех серверах в `~ubuntu/.ssh/authorized_keys`

3. **Проверьте подключение**:

   ```bash
   # Тест одного сервера
   ssh -i aztec_ansible/common/ssh/id_rsa ubuntu@IP_ADDRESS

   # Тест всех серверов из CSV
   cd aztec_ansible/common
   ./test_ssh.sh your_servers.csv
   ```

**Если видите ошибки "Permission denied (publickey)":**

1. **Проверьте наличие и права SSH ключа:**

   ```bash
   ls -la aztec_ansible/common/ssh/id_rsa
   # Должно показать: -rw------- (права 600)
   ```

2. **Убедитесь, что публичный ключ установлен на серверах:**

   ```bash
   # Добавьте публичный ключ на сервера
   ssh-copy-id -i aztec_ansible/common/ssh/id_rsa ubuntu@SERVER_IP
   ```

3. **Используйте тест подключения:**
   ```bash
   cd aztec_ansible/common
   ./test_ssh.sh your_servers.csv
   ```

Подробные инструкции: [common/ssh/README.md](common/ssh/README.md)

## Структура CSV файла

CSV файл должен содержать следующие столбцы:

- `IP` - IP-адрес сервера
- `ADDRESS` - Ethereum адрес для каждого сервера
- `PRIVATE_KEY` - Приватный ключ для каждого сервера

Пример:

```
IP,ADDRESS,PRIVATE_KEY
192.168.1.10,0x123...abc,0xdef...789
192.168.1.11,0x456...def,0xghi...012
```

## Переменные окружения

Плейбук автоматически устанавливает следующие переменные окружения:

- `SERVER_IP` - IP адрес текущего сервера (индивидуально для каждого сервера)
- `ETH_ADDRESS` - из CSV файла (индивидуально для каждого сервера)
- `VALIDATOR_PRIVATE_KEY` - из CSV файла (индивидуально для каждого сервера)
- `L1_RPC_URL` - общая для всех серверов (настраивается в vars/server_vars.yml)
- `L1_CONSENSUS_URL` - общая для всех серверов (настраивается в vars/server_vars.yml)

## Использование

### Вариант 1: Запуск всех этапов сразу

```bash
cd aztec_ansible/install_playbook
chmod +x run_all_stages.sh
./run_all_stages.sh path/to/your/servers.csv
```

### Вариант 2: Поэтапная установка

#### Этап 1: Подготовка серверов

2. **Подготовка серверов**:

   ```bash
   # Сначала сгенерировать inventory
   cd ../../
   ./generate_hosts.sh path/to/your/servers.csv

   # Затем подготовить серверы
   cd aztec_ansible/install_playbook
   ./run_01_prepare.sh hosts_your_servers
   ```

Что делает:

- Обновляет пакеты системы
- Устанавливает базовые зависимости (curl, wget, htop и др.)
- Проверяет ресурсы сервера
- Логирует процесс подготовки

#### Этап 2: Установка Docker

```bash
chmod +x run_02_install_docker.sh
./run_02_install_docker.sh
```

Что делает:

- Удаляет старые версии Docker
- Устанавливает Docker CE
- Настраивает пользователя ubuntu в группе docker
- Тестирует работу Docker

#### Этап 3: Установка Aztec

```bash
chmod +x run_03_install_aztec.sh
./run_03_install_aztec.sh
```

Что делает:

- Скачивает Install.sh скрипт
- Устанавливает переменные окружения (IP, адреса, ключи)
- Запускает установку Aztec
- Проверяет статус сервиса

### Дополнительные возможности:

```bash
# Принудительная переустановка
FORCE=1 ./run_02_install_docker.sh

# Подробные логи
VERBOSE=1 ./run_01_prepare.sh hosts_servers
```

### Сбор proof данных

После установки и запуска узлов можно собрать proof данные:

```bash
cd aztec_ansible/get_proof_playbook
./run_get_proof.sh
```

**Дополнительные возможности:**

```bash
# Установка timeout (секунды)
TIMEOUT=600 ./run_get_proof.sh

# Подробные логи
VERBOSE=1 ./run_get_proof.sh

# Справка по использованию
./run_get_proof.sh --help
```

Результат сохраняется в файл `proof_results.csv` с колонками:

- `ip,address,block_number,proof,status,timestamp`

## Преимущества поэтапной установки

1. **Лучший контроль** - можно остановиться на любом этапе
2. **Отладка** - легче найти проблему на конкретном этапе
3. **Переиспользование** - Docker можно установить один раз для разных проектов
4. **Экономия времени** - при повторной установке можно пропустить подготовку и Docker
5. **Гибкость** - можно настроить каждый этап под свои нужды

## Проверка статуса установки

После завершения установки можно проверить статус узлов:

```bash
cd aztec_ansible/common

# Проверка сервисов
ansible all -i inventory/hosts -m shell -a "systemctl is-active aztec-node.service"

# Логи сервисов
ansible all -i inventory/hosts -m shell -a "journalctl -u aztec-node.service -n 20"

# Версия Docker
ansible all -i inventory/hosts -m shell -a "docker --version"
```

## Настройка L1 RPC URLs

По умолчанию используются следующие значения (можно изменить в `vars/server_vars.yml`):

- L1_RPC_URL: `https://lb.drpc.org/ogrpc?network=sepolia&dkey=Au8yDd-i2UInsBCU3RSbVp7lazFCMKAR8LxOfpPAH9l9`
- L1_CONSENSUS_URL: `https://lb.drpc.org/rest/Au8yDd-i2UInsBCU3RSbVp7lazFCMKAR8LxOfpPAH9l9/eth-beacon-chain-sepolia`

## 📊 Централизованное логирование

Все операции автоматически логируются в общую папку `logs/`:

### Файлы логов:

- `prepare_YYYYMMDD_HHMMSS.log` - логи подготовки серверов
- `docker_YYYYMMDD_HHMMSS.log` - логи установки Docker
- `aztec_YYYYMMDD_HHMMSS.log` - логи установки Aztec
- `complete_install_YYYYMMDD_HHMMSS.log` - общий лог полной установки
- `proof_collection_YYYYMMDD_HHMMSS.log` - логи сбора proof
- `proof_summary_YYYYMMDD_HHMMSS.txt` - статистика результатов сбора proof
- `ansible.log` - общий лог Ansible операций (в common/)

### Просмотр логов:

```bash
# Все логи
ls aztec_ansible/logs/

# Последние логи установки
tail -f aztec_ansible/logs/complete_install_*.log

# Последние логи сбора proof
tail -f aztec_ansible/logs/proof_collection_*.log
```

## 🔧 Тестирование и отладка

### Тест SSH подключения:

```bash
cd aztec_ansible/common
./test_ssh.sh your_servers.csv
```

### Проверка состояния серверов:

```bash
# Connectivity test
ansible all -i inventory/hosts -m ping

# Статус сервисов
ansible all -i inventory/hosts -m systemd -a "name=aztec-node.service"

# Логи сервисов
ansible all -i inventory/hosts -m shell -a "journalctl -u aztec-node.service -n 10"
```

## Безопасность

- SSH ключи автоматически исключены из git через `.gitignore`
- Генерируемые файлы инвентаря и результатов также исключены из git
- Папка логов исключена из git для безопасности
- Все подключения выполняются с отключенной проверкой host keys для автоматизации

## Дополнительная информация

- Скрипты автоматически загружают необходимые файлы из репозитория, если они отсутствуют
- Инвентарь Ansible и файлы переменных генерируются автоматически из CSV файла
- Плейбуки можно запускать независимо друг от друга
- Убедитесь, что пользователь `ubuntu` имеет права sudo без пароля на всех серверах
