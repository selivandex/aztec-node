<!-- @format -->

# 🔄 Aztec Sync Check - Проверка синхронизации нод

## 📖 Описание

Ansible плейбук для проверки синхронизации всех Aztec нод в сети. Автоматически определяет порты, проверяет статус синхронизации и предоставляет подробную статистику.

## 🚀 Быстрый старт

### Из корня проекта:

```bash
./sync_check.sh
```

### Из папки get_proof_playbook:

```bash
cd aztec_ansible/get_proof_playbook
./run_sync_check.sh
```

## 🔧 Опции запуска

### Обычная проверка:

```bash
./sync_check.sh
```

### С подробным выводом:

```bash
VERBOSE=1 ./sync_check.sh
```

### С увеличенным таймаутом:

```bash
TIMEOUT=120 ./sync_check.sh
```

### Помощь:

```bash
./sync_check.sh --help
```

## 📋 Требования

1. **Inventory файл**: `aztec_ansible/common/inventory/hosts`
2. **SSH ключ**: `aztec_ansible/common/ssh/id_rsa`
3. **Подготовленные серверы** через install playbook

### Если требования не выполнены:

```bash
# Сначала подготовьте серверы
cd aztec_ansible/install_playbook
./run_01_prepare.sh path/to/your/servers.csv

# Затем запустите проверку синхронизации
cd ..
./sync_check.sh
```

## 📊 Результаты проверки

### Статусы синхронизации:

- **SYNCED** ✅ - Нода полностью синхронизирована
- **SYNCING** ⏳ - Нода еще синхронизируется
- **NO_NODE** ❌ - Нода не найдена на портах
- **RPC_ERROR** 🚫 - Ошибка RPC запросов
- **TIMEOUT** ⏰ - Превышен таймаут проверки
- **ERROR** 💥 - Другие ошибки

### Файл результатов: `sync_results.csv`

```csv
ip,hostname,local_block,remote_block,sync_status,port,timestamp,raw_output
95.216.84.227,node1,2601,2601,SYNCED,8080,2024-01-15T10:30:00Z,"✅ Detected app running on port 8080..."
```

### Пример вывода:

```
========================================
        AZTEC SYNC CHECK SUMMARY
========================================
Total servers checked: 10
✅ Fully synced:      8
⏳ Still syncing:     1
❌ No node found:     1
🚫 RPC errors:        0
⏰ Timeouts:          0
💥 Other errors:      0
Success rate:         80%
========================================

✅ Successfully synced nodes:
  95.216.84.227 (node1) - Block: 2601
  95.216.84.228 (node2) - Block: 2601

⏳ Nodes still syncing:
  95.216.84.229 (node3) - 2598/2601

❌ Nodes not running:
  95.216.84.230 (node4)
```

## 🔍 Как работает проверка

### Автоматическое определение портов:

Скрипт проверяет порты в следующем порядке:

1. **8080** (основной порт Aztec)
2. **8081** (альтернативный порт)
3. **8082** (резервный порт)

### RPC проверки:

1. **Локальная нода**: `http://localhost:PORT/` - метод `node_getL2Tips`
2. **Удаленная нода**: `https://aztec-rpc.cerberusnode.com` - тот же метод
3. **Сравнение блоков** для определения синхронизации

### Обработка результатов:

- **Exit code 0**: Полная синхронизация
- **Exit code 1**: Нода не найдена
- **Exit code 2**: Ошибка RPC
- **Exit code 3**: Еще синхронизируется
- **Exit code 124**: Таймаут

## ⚡ Переменные окружения

| Переменная | По умолчанию | Описание                                   |
| ---------- | ------------ | ------------------------------------------ |
| `TIMEOUT`  | 60           | Таймаут проверки каждого сервера (секунды) |
| `VERBOSE`  | 0            | Подробный вывод (1 = включен)              |

## 🚨 Устранение проблем

### Нет inventory файла:

```bash
❌ Inventory файл не найден: ../common/inventory/hosts

Для создания inventory файла:
  cd ../install_playbook
  ./run_01_prepare.sh path/to/your/servers.csv
```

### Нет SSH ключа:

```bash
❌ SSH ключ не найден: ../common/ssh/id_rsa
Убедитесь что серверы подготовлены через install playbook
```

### В verbose режиме показывается:

```
Sync check results for 95.216.84.227:
Return code: 0
Status: SYNCED
Local block: 2601
Remote block: 2601
Port: 8080
Output: ✅ Detected app running on port 8080...
Error: N/A
```

## 🔄 Отличия от оригинального скрипта

### Оригинальный скрипт проблемы:

- ❌ Бесконечный цикл `while true`
- ❌ Интерактивный ввод порта
- ❌ Ручная остановка `Ctrl+C`

### Наше решение:

- ✅ Одноразовая проверка без циклов
- ✅ Автоматическое определение портов
- ✅ Возвращает конкретные exit codes
- ✅ Массовая проверка всех серверов
- ✅ Детальная статистика и логирование

## 📈 Мониторинг

### Отслеживание выполнения в реальном времени:

```bash
# В отдельном терминале
tail -f aztec_ansible/logs/sync_check_*.log

# Следить за результатами
watch -n 5 "tail -10 aztec_ansible/get_proof_playbook/sync_results.csv"
```

### Автоматизация проверок:

```bash
# Добавить в crontab для регулярных проверок
# Каждые 30 минут
*/30 * * * * cd /path/to/aztec && ./sync_check.sh >> /var/log/aztec_sync_check.log 2>&1
```

## 🎯 Использование в CI/CD

```bash
#!/bin/bash
# В пайплайне CI/CD

cd /path/to/aztec
./sync_check.sh

# Проверить результаты
if grep -q ",SYNCED," sync_results.csv; then
    echo "✅ Все ноды синхронизированы"
    exit 0
else
    echo "❌ Есть проблемы с синхронизацией"
    exit 1
fi
```

## 🔗 Связанные команды

```bash
# Получить proof после проверки синхронизации
./sync_check.sh && ./get_proof.sh

# Полная диагностика
VERBOSE=1 ./sync_check.sh
VERBOSE=1 ./get_proof.sh
```
