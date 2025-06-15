<!-- @format -->

# Исправление проблем с хостами Zabbix

## Проблема

Скрипт `run_06_add_host_to_zabbix.sh` создавал хосты в Zabbix с неправильными интерфейсами (IP 0.0.0.0:10050 вместо реального IP сервера) и без шаблона мониторинга.

## Исправленные проблемы

### 1. Неправильная обработка существующих хостов

**Проблема**: Когда хост уже существовал в Zabbix, скрипт не обновлял его IP адрес и шаблон.
**Решение**: Добавлена логика обновления существующих хостов через Zabbix API `host.update`.

### 2. Отсутствие шаблона мониторинга

**Проблема**: Если шаблон "Template Aztec Node Monitoring" не был импортирован в Zabbix, скрипт прерывал работу.
**Решение**: Скрипт теперь продолжает работу без шаблона и выводит предупреждения.

### 3. Неинформативные сообщения об ошибках

**Проблема**: Было непонятно, что именно пошло не так при создании хостов.
**Решение**: Добавлены подробные сообщения и инструкции по дальнейшим действиям.

## Что теперь делает скрипт

1. **Для новых хостов**: Создает с правильным IP адресом и шаблоном (если доступен)
2. **Для существующих хостов**: Обновляет IP адрес, группы хостов и шаблон
3. **При отсутствии шаблона**: Создает хосты без шаблона и выводит инструкции
4. **В конце работы**: Показывает следующие шаги для завершения настройки

## Как использовать исправленный скрипт

### Базовое использование

```bash
cd aztec_ansible/add_zabbix_hosts_playbook/

# С API токеном (рекомендуется)
ZABBIX_SERVER=http://your-zabbix-server/zabbix \
ZABBIX_API_TOKEN=your-api-token \
./run_06_add_host_to_zabbix.sh

# С логином/паролем
ZABBIX_SERVER=http://your-zabbix-server/zabbix \
ZABBIX_USER=Admin \
ZABBIX_PASSWORD=your-password \
./run_06_add_host_to_zabbix.sh
```

### Принудительное пересоздание хостов

Если вам нужно полностью пересоздать все хосты:

```bash
ZABBIX_SERVER=http://your-zabbix-server/zabbix \
ZABBIX_API_TOKEN=your-api-token \
./run_06_add_host_to_zabbix.sh --force-recreate
```

### Для отладки

Включите подробный вывод:

```bash
ZABBIX_SERVER=http://your-zabbix-server/zabbix \
ZABBIX_API_TOKEN=your-api-token \
./run_06_add_host_to_zabbix.sh --verbose
```

## Решение проблем с существующими хостами

Если у вас уже есть хосты с неправильными IP адресами (0.0.0.0:10050), просто запустите исправленный скрипт - он автоматически обновит их.

### Проверка результатов в Zabbix

1. Откройте веб-интерфейс Zabbix
2. Перейдите в **Configuration → Hosts**
3. Найдите ваши Aztec хосты
4. Убедитесь, что:
   - IP адреса правильные (не 0.0.0.0)
   - Порт 10050
   - Хосты находятся в группах "Aztec Nodes" и "Linux servers"
   - Привязан шаблон "Template Aztec Node Monitoring" (если импортирован)

### Импорт шаблона мониторинга

Если хосты были созданы без шаблона:

1. Скачайте `aztec_zabbix_template.xml` из проекта
2. В Zabbix web UI: **Configuration → Templates → Import**
3. Выберите файл и нажмите **Import**
4. Перейдите в **Configuration → Hosts**
5. Выберите ваши Aztec хосты
6. Нажмите **Mass update → Templates**
7. Добавьте "Template Aztec Node Monitoring"

## Мониторинг результатов

После исправления хостов:

- Подождите 2-3 минуты для первых данных
- Проверьте **Monitoring → Hosts** - статус должен быть "Enabled"
- В **Monitoring → Latest data** должны появиться метрики Aztec nodes

## Если проблемы остались

1. Проверьте логи Zabbix agent на серверах:

   ```bash
   tail -f /var/log/zabbix/zabbix_agent2.log
   ```

2. Проверьте подключение к Zabbix серверу:

   ```bash
   telnet your-zabbix-server 10051
   ```

3. Проверьте, что агент отвечает:

   ```bash
   zabbix_agent2 -t aztec.service.status
   ```

4. Проверьте конфигурацию агента:
   ```bash
   cat /etc/zabbix/zabbix_agent2.conf | grep -E "(Server|Hostname)"
   ```
