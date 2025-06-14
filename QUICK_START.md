<!-- @format -->

# 🚀 Быстрый старт - Установка Aztec

## Полный workflow из корня проекта

```bash
# 1. Генерация inventory
./generate_hosts.sh your_servers.csv

# 2. Установка всех компонентов
cd aztec_ansible/install_playbook
./run_all_stages.sh hosts_your_servers

# 3. Возврат в корень и сбор proof
cd ../..
./get_proof.sh
```

## Запуск из корня проекта

### Полная установка (рекомендуется)

```bash
# Генерировать inventory
./generate_hosts.sh your_servers.csv

# Перейти в папку установки и запустить полную установку
cd aztec_ansible/install_playbook
./run_all_stages.sh hosts_your_servers
```

### Поэтапная установка

```bash
# Генерировать inventory
./generate_hosts.sh your_servers.csv

# Перейти в папку установки
cd aztec_ansible/install_playbook

# Этап 1: Подготовка серверов и Docker
./run_01_prepare.sh hosts_your_servers

# Этап 2: Установка Aztec
./run_03_install_aztec.sh hosts_your_servers
```

### Альтернативный запуск из корня

```bash
# Генерация inventory
./generate_hosts.sh your_servers.csv

# Полная установка напрямую из корня
bash aztec_ansible/install_playbook/run_all_stages.sh hosts_your_servers

# Поэтапно из корня
bash aztec_ansible/install_playbook/run_01_prepare.sh hosts_your_servers
bash aztec_ansible/install_playbook/run_03_install_aztec.sh hosts_your_servers
```

## 🔍 Сбор Proof после установки

После успешной установки и запуска узлов можно собрать proof данные:

```bash
# Самый простой способ - из корня проекта
./get_proof.sh

# Или традиционный способ
cd aztec_ansible/get_proof_playbook
./run_get_proof.sh

# Из корня проекта с прямым вызовом
bash aztec_ansible/get_proof_playbook/run_get_proof.sh

# С подробным выводом
VERBOSE=1 ./get_proof.sh

# С увеличенным таймаутом
TIMEOUT=600 ./get_proof.sh

# Справка
./get_proof.sh --help
```

## 🚨 Исправление проблем с Docker

### При ошибке "Conflicting values set for option Signed-By"

```bash
# Запустить исправление
cd aztec_ansible/install_playbook
./run_00_fix_docker_sources.sh

# Повторить установку Docker
./run_02_install_docker.sh
```

## 🚨 Устранение частых проблем

### Docker источники

При ошибках установки Docker запустите исправление:

```bash
cd aztec_ansible/install_playbook
./run_00_fix_docker_sources.sh
```

### Get_proof ошибки

Новая версия автоматически исправляет:

- ✅ "NoneType object is not iterable" - исправлен regex parsing
- ✅ "Syntax error: ( unexpected" - исправлен shell syntax
- ✅ Проблемы с многострочным proof - добавлена поддержка

Для диагностики используйте verbose режим:

```bash
VERBOSE=1 ./get_proof.sh
```

## 📋 Требования

1. **SSH ключ**: `aztec_ansible/common/ssh/id_rsa` (права 600)
2. **CSV файл серверов**: колонки `IP,ADDRESS,PRIVATE_KEY`
3. **Права sudo** без пароля на всех серверах
4. **Ansible** установлен и настроен

## 📊 Просмотр логов

```bash
# Все логи
ls aztec_ansible/logs/

# Следить за последней установкой
tail -f aztec_ansible/logs/complete_install_*.log

# Логи конкретного этапа
tail -f aztec_ansible/logs/fix_docker_sources_*.log
tail -f aztec_ansible/logs/prepare_*.log
tail -f aztec_ansible/logs/docker_*.log
tail -f aztec_ansible/logs/aztec_*.log

# Логи сбора proof
tail -f aztec_ansible/logs/proof_collection_*.log
```

## 🎯 Время выполнения

- **Исправление Docker sources**: 1-2 минуты на сервер
- **Подготовка серверов**: 3-5 минут на сервер
- **Установка Docker**: 5-10 минут на сервер
- **Установка Aztec**: 20-30 минут на сервер
- **Сбор proof**: 2-5 минут на сервер

**Общее время установки**: 30-45 минут на сервер

## 📚 Подробная документация

- [Полная документация](aztec_ansible/README.md)
- [Документация установки](aztec_ansible/install_playbook/README.md)
- [Документация сбора proof](aztec_ansible/get_proof_playbook/README.md)
- [Изменения в get_proof](GET_PROOF_CHANGES.md)
