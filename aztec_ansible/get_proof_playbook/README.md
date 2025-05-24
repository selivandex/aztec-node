<!-- @format -->

# Сбор Proof с узлов Aztec

Этот плейбук подключается ко всем серверам из inventory файла и собирает proof данные с каждого узла Aztec.

## Описание

Плейбук выполняет следующие действия:

1. Использует существующий inventory файл с серверами
2. Подключается к каждому серверу из списка
3. Выполняет команду GetProof.sh на каждом сервере
4. Парсит результат для извлечения номера блока и proof
5. Сохраняет результаты в CSV файл с детальной аналитикой

## 🚀 Использование

### Простой запуск

```bash
cd aztec_ansible/get_proof_playbook
./run_get_proof.sh
```

### С дополнительными опциями

```bash
# Подробный вывод
VERBOSE=1 ./run_get_proof.sh

# Увеличенный таймаут (10 минут)
TIMEOUT=600 ./run_get_proof.sh

# Справка
./run_get_proof.sh --help
```

### Запуск из корня проекта

```bash
# Простой запуск
bash aztec_ansible/get_proof_playbook/run_get_proof.sh

# С опциями
VERBOSE=1 bash aztec_ansible/get_proof_playbook/run_get_proof.sh
```

## 📋 Требования

1. **Inventory файл**: Должен существовать `../common/inventory/hosts`
2. **SSH ключ**: Должен быть доступен `../common/ssh/id_rsa` (права 600)
3. **Подготовленные серверы**: Серверы должны быть подготовлены через установочные скрипты

### Если inventory файла нет

```bash
# Сначала подготовьте серверы
cd ../install_playbook
./run_01_prepare.sh path/to/your/servers.csv

# Затем запустите сбор proof
cd ../get_proof_playbook
./run_get_proof.sh
```

## 📊 Результат

Создается файл `proof_results.csv` со следующей структурой:

```
ip,address,block_number,proof,status,timestamp
95.216.84.227,0x123...abc,12345,0xabcd...,SUCCESS,2024-01-15T10:30:00Z
95.216.84.228,0x456...def,ERROR,ERROR,FAILED,2024-01-15T10:30:15Z
```

### Столбцы результата

- `ip` - IP-адрес сервера
- `address` - Ethereum адрес сервера (из inventory)
- `block_number` - Номер блока из GetProof.sh
- `proof` - Proof данные из GetProof.sh
- `status` - Статус выполнения (SUCCESS/ERROR/FAILED)
- `timestamp` - Время сбора данных

### Анализ результатов

Скрипт автоматически анализирует результаты и показывает:

- Общее количество серверов
- Количество успешных сборов
- Количество ошибок
- Процент успешности
- Примеры успешных и неудачных результатов

### Файлы логов

```bash
# Основной лог
../logs/proof_collection_YYYYMMDD_HHMMSS.log

# Сводка результатов
../logs/proof_summary_YYYYMMDD_HHMMSS.txt

# Резервные копии предыдущих результатов
proof_results.csv.backup.YYYYMMDD_HHMMSS
```

## 🔧 Обработка ошибок

- **Недоступный сервер**: Статус "FAILED", все поля содержат "ERROR"
- **Ошибка GetProof.sh**: Статус "ERROR", сохраняется текст ошибки
- **Таймаут**: Автоматический повтор до 2 раз с задержкой 30 секунд
- **Частичные ошибки**: Плейбук продолжает работу и анализирует частичные результаты

## ⚙️ Настройки

### Переменные окружения

- `VERBOSE=1` - Включает подробный вывод Ansible и предварительную проверку подключений
- `TIMEOUT=300` - Таймаут выполнения GetProof.sh (секунды, по умолчанию 300)

### Настройки в playbook

- `proof_timeout: 300` - Таймаут выполнения скрипта (5 минут)
- `max_retries: 2` - Количество повторов при ошибке
- `delay: 30` - Задержка между повторами (секунды)

## 📈 Мониторинг выполнения

```bash
# Следить за логом в реальном времени
tail -f ../logs/proof_collection_*.log

# Проверить промежуточные результаты
head proof_results.csv

# Следить за выполнением
watch -n 5 "wc -l proof_results.csv"
```

## 🚨 Устранение проблем

### "Inventory file not found"

```bash
cd ../install_playbook
./run_01_prepare.sh path/to/your/servers.csv
```

### "SSH key not found"

```bash
cp /path/to/your/key ../common/ssh/id_rsa
chmod 600 ../common/ssh/id_rsa
```

### "Some servers not reachable"

Проверьте SSH подключение и убедитесь, что серверы доступны:

```bash
ansible all -i ../common/inventory/hosts -m ping
```

## 📚 Дополнительная информация

- [Документация установки](../install_playbook/README.md)
- [Общая документация](../README.md)
