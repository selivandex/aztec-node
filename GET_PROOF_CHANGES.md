<!-- @format -->

# Изменения в get_proof функциональности

## 🎯 Основные изменения

Скрипт `run_get_proof.sh` больше **НЕ ТРЕБУЕТ** CSV файл на входе. Теперь он использует существующий inventory файл, который создается при подготовке серверов.

## ✅ Что изменилось

### Старое использование:

```bash
./run_get_proof.sh path/to/servers.csv
```

### Новое использование:

```bash
./run_get_proof.sh
```

## 🚀 Новые способы запуска

### 1. Из папки get_proof_playbook:

```bash
cd aztec_ansible/get_proof_playbook
./run_get_proof.sh
```

### 2. Из корня проекта:

```bash
./get_proof.sh
```

### 3. С прямым вызовом из корня:

```bash
bash aztec_ansible/get_proof_playbook/run_get_proof.sh
```

### 4. С дополнительными опциями:

```bash
# Подробный вывод
VERBOSE=1 ./get_proof.sh

# Увеличенный таймаут
TIMEOUT=600 ./get_proof.sh

# Справка
./get_proof.sh --help
```

## 📋 Новые требования

1. **Inventory файл должен существовать**: `aztec_ansible/common/inventory/hosts`
2. **SSH ключ должен быть доступен**: `aztec_ansible/common/ssh/id_rsa`
3. **Серверы должны быть подготовлены** через install playbook

## 🔄 Как это работает

1. Скрипт проверяет наличие inventory файла
2. Если файла нет - показывает инструкции по подготовке серверов
3. Если файл есть - использует его для подключения к серверам
4. Собирает proof данные и анализирует результаты

## 🚨 Что делать если inventory файла нет

```bash
# Сначала подготовьте серверы
cd aztec_ansible/install_playbook
./run_01_prepare.sh path/to/your/servers.csv

# Затем запустите сбор proof
cd ../get_proof_playbook
./run_get_proof.sh
```

## 📁 Новые файлы

1. **`get_proof.sh`** - простой скрипт-обертка в корне проекта
2. Обновленный **`run_get_proof.sh`** - основной скрипт без требования CSV
3. Обновленная документация в **`README.md`**

## 🎉 Преимущества

- ✅ Не нужно помнить путь к CSV файлу
- ✅ Автоматически использует подготовленный inventory
- ✅ Простой запуск из корня проекта: `./get_proof.sh`
- ✅ Встроенная помощь и проверка требований
- ✅ Лучшие сообщения об ошибках с инструкциями
- ✅ Быстрый запуск без избыточных SSH проверок

## ⚡ Оптимизация подключений

### Что было:

- Скрипт всегда делал предварительный connectivity test через SSH
- Это дублировало функциональность Ansible и добавляло задержку

### Что стало:

- Connectivity test запускается только в verbose режиме (`VERBOSE=1`)
- По умолчанию Ansible сам управляет подключениями
- Быстрый запуск без лишних проверок

### Использование connectivity test:

```bash
# Быстрый запуск (рекомендуется)
./get_proof.sh

# С предварительной проверкой подключений
VERBOSE=1 ./get_proof.sh
```

## 🔧 Исправление ошибки regex parsing

### Проблема:

```
fatal: [node1]: FAILED! => {"msg": "Unexpected templating type error occurred on (...): 'NoneType' object is not iterable"}
```

### Причина:

- `regex_search` возвращал `None` когда паттерн не найден
- Попытка вызвать `first` от `None` вызывала ошибку
- **Основная проблема**: regex паттерн `.+` не захватывает символы новой строки в Proof данных
- Proof - это очень длинная base64 строка, которая может содержать переносы

### Пример вывода GetProof.sh:

```
Номер блока: 2226

Proof: AAAAHQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHc40mkiyUHag...
(очень длинная строка)
```

### Решение:

1. **Использовали `regex_replace`** вместо `regex_search` для извлечения групп
2. **Добавили поддержку многострочности** с `multiline=True, dotall=True`
3. **Упростили regex паттерны**:
   - Для блока: `Номер блока: ([0-9]+)`
   - Для proof: `Proof: (.+)` с multiline флагами
4. **Улучшили debug вывод** для диагностики

### До исправления:

```yaml
regex_search('Номер блока:\\s*(.+)', '\\1') | first # Ошибка!
```

### После исправления:

```yaml
regex_replace('.*Номер блока: ([0-9]+).*', '\\1') # Работает!
```

### Теперь playbook:

- ✅ Корректно парсит многострочный Proof
- ✅ Безопасно обрабатывает любой вывод GetProof.sh
- ✅ Не падает если паттерн не найден
- ✅ Показывает debug информацию в verbose режиме
- ✅ Корректно обрабатывает все edge cases

## 🛠️ Исправление ошибки Shell Syntax

### Проблема:

```
Error: /bin/sh: 1: Syntax error: "(" unexpected
```

### Причина:

- Использовали process substitution `bash <(curl ...)`
- На некоторых серверах `/bin/sh` может быть dash, а не bash
- Process substitution не поддерживается в POSIX shell

### Было:

```yaml
shell: |
  timeout 300 bash <(curl -s --connect-timeout 30 --max-time 60 \
  https://raw.githubusercontent.com/.../GetProof.sh)
```

### Стало:

```yaml
- name: Download GetProof script
  get_url:
    url: https://raw.githubusercontent.com/.../GetProof.sh
    dest: /tmp/getproof_{{ ansible_date_time.epoch }}.sh
    mode: "0755"

- name: Execute GetProof script
  shell: timeout 300 bash /tmp/getproof_{{ ansible_date_time.epoch }}.sh
```

### Преимущества нового подхода:

- ✅ Работает с любым shell (bash, dash, sh)
- ✅ Более надежное скачивание через Ansible `get_url`
- ✅ Автоматическая очистка временных файлов
- ✅ Лучшая обработка ошибок скачивания
- ✅ Retry механизм только для выполнения, не для скачивания

## 🐍 Переход на Python-based парсинг

### Проблема с Jinja2 templates:

```
regex_replace() got an unexpected keyword argument 'multiline'
```

### Причина:

- Ansible Jinja2 templates имеют ограниченную поддержку regex функций
- `regex_replace` не поддерживает флаги `multiline` и `dotall`
- Сложная логика парсинга в templates приводила к ошибкам

### Новое решение - Python скрипт:

Создан отдельный Python скрипт `parse_proof.py` который:

```python
def parse_proof_output(output):
    result = {
        "block_number": "N/A",
        "proof": "N/A",
        "status": "ERROR",
        "error": ""
    }

    # Extract block number
    block_match = re.search(r'Номер блока:\s*(\d+)', output)
    if block_match:
        result["block_number"] = block_match.group(1)

    # Extract proof data (handle multiline)
    proof_match = re.search(r'Proof:\s*(.+)', output, re.DOTALL)
    if proof_match:
        proof_data = proof_match.group(1).strip()
        proof_data = re.sub(r'\s+', '', proof_data)  # Clean whitespace
        result["proof"] = proof_data
```

### Новый workflow в Ansible:

```yaml
- name: Copy Python parser to server
  copy:
    src: parse_proof.py
    dest: /tmp/parse_proof.py

- name: Execute GetProof script
  shell: timeout 300 bash /tmp/getproof.sh
  register: proof_output

- name: Parse output using Python
  shell: python3 /tmp/parse_proof.py "{{ proof_output.stdout }}"
  register: parsed_result

- name: Use parsed JSON result
  set_fact:
    block_number: "{{ (parsed_result.stdout | from_json).block_number }}"
    proof_data: "{{ (parsed_result.stdout | from_json).proof }}"
```

### Преимущества Python подхода:

- ✅ **Полная поддержка regex** с любыми флагами (DOTALL, MULTILINE)
- ✅ **Простая отладка** - можно тестировать скрипт отдельно
- ✅ **JSON вывод** - легко использовать в Ansible
- ✅ **Надежный парсинг** многострочных данных
- ✅ **Обработка ошибок** с подробными сообщениями
- ✅ **Никаких проблем** с Jinja2 template ограничениями
