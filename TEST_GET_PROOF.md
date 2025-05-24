<!-- @format -->

# 🧪 Тестирование Get Proof после исправлений

## ✅ Все исправленные проблемы

1. **"NoneType object is not iterable"** - исправлен regex parsing
2. **"Syntax error: ( unexpected"** - исправлен shell syntax
3. **"regex_replace() got an unexpected keyword argument 'multiline'"** - заменен на Python парсинг
4. **Проблемы с многострочным proof** - добавлена поддержка
5. **Убрана зависимость от CSV файла** - используется inventory
6. **Оптимизированы SSH подключения** - убран лишний connectivity test

## 🚀 Как протестировать

### 1. Простой тест

```bash
# Из корня проекта
./get_proof.sh
```

### 2. С подробной диагностикой

```bash
# Покажет весь процесс парсинга и debug информацию
VERBOSE=1 ./get_proof.sh
```

### 3. С увеличенным таймаутом

```bash
# Для медленных серверов
TIMEOUT=600 ./get_proof.sh
```

### 4. Альтернативные способы запуска

```bash
# Из папки get_proof_playbook
cd aztec_ansible/get_proof_playbook
./run_get_proof.sh

# Прямой вызов из корня
bash aztec_ansible/get_proof_playbook/run_get_proof.sh
```

## 🔍 Что проверить в результатах

### Успешный результат должен показать:

```
======================================
       PROOF COLLECTION SUMMARY
======================================
Total servers processed: X
Successful collections:  Y
Failed collections:      Z
Success rate:           XX%
Results file:           ./proof_results.csv
======================================

Sample successful results:
  95.216.84.227 -> Block: 2226, Proof: AAAAHQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgp3r7EQXbWMX/...
```

### Файл результатов `proof_results.csv`:

```
ip,address,block_number,proof,status,timestamp
95.216.84.227,0x123...abc,2226,AAAAHQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgp3r7EQXbWMX...,SUCCESS,2024-01-15T10:30:00Z
```

## 🚨 Диагностика проблем

### В verbose режиме вы увидите:

1. **Connectivity test** (если включен)
2. **GetProof.sh output length** (без вывода полного содержимого)
3. **Python parser result** - JSON с результатами парсинга
4. **Block number** и **Proof data** из Python скрипта

### Python parser результат выглядит так:

```json
{
  "block_number": "2226",
  "proof": "AAAAHQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgp3r7EQXbWMX...",
  "status": "SUCCESS",
  "error": ""
}
```

### Если сервер недоступен:

```
Status: FAILED
Block: ERROR
Proof: ERROR
```

### Если GetProof.sh вернул ошибку:

```
Status: ERROR
Block: N/A
Proof: N/A
Error: [описание ошибки]
```

### Если парсинг не удался:

```
Status: ERROR
Error: Failed to parse GetProof.sh output
```

## 📊 Мониторинг выполнения

### Следить за процессом в реальном времени:

```bash
# В отдельном терминале
tail -f aztec_ansible/logs/proof_collection_*.log

# Или следить за результатами
watch -n 5 "wc -l aztec_ansible/get_proof_playbook/proof_results.csv"
```

## ✅ Проверка требований

Перед запуском убедитесь что:

1. **Inventory файл существует**: `aztec_ansible/common/inventory/hosts`
2. **SSH ключ доступен**: `aztec_ansible/common/ssh/id_rsa` (права 600)
3. **Серверы подготовлены** через install playbook

### Если inventory файла нет:

```bash
cd aztec_ansible/install_playbook
./run_01_prepare.sh path/to/your/servers.csv
```

## 🎯 Ожидаемые улучшения

После всех исправлений вы должны получить:

- ✅ **Быстрый запуск** без лишних SSH проверок
- ✅ **Надежный парсинг** любого вывода GetProof.sh
- ✅ **Отсутствие shell ошибок** на любых серверах
- ✅ **Корректную обработку** длинных proof строк
- ✅ **Подробную диагностику** в verbose режиме
- ✅ **Простоту использования** без CSV файлов
- ✅ **Python-based парсинг** без ограничений Jinja2
