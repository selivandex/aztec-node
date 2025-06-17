<!-- @format -->

# Telegram Notifications Setup for Zabbix

## Prerequisites

1. Create a Telegram bot:

   - Message @BotFather on Telegram
   - Send `/newbot` command
   - Follow instructions to get your bot token
   - Save the token (format: `1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZ123456789`)

2. Get your Chat ID:
   - Message your bot or add it to a group
   - Send `/start` command
   - Get chat ID using this URL: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Look for `"chat":{"id":` in the response

## Configuration

1. Set environment variable before starting docker-compose:

   ```bash
   export TELEGRAM_BOT_TOKEN="your_bot_token_here"
   ```

   Or create a `.env` file in the project root:

   ```
   TELEGRAM_BOT_TOKEN=your_bot_token_here
   ```

2. Start the services:
   ```bash
   docker-compose up -d
   ```

## Zabbix Configuration

1. Log into Zabbix web interface (http://localhost:8123)
2. Go to Administration → Media types
3. Create new media type:

   - Name: `Telegram`
   - Type: `Script`
   - Script name: `telegram_alert.sh`
   - Script parameters:
     - `{ALERT.SENDTO}` (Chat ID)
     - `{ALERT.SUBJECT}`
     - `{ALERT.MESSAGE}`

4. Go to Administration → Users
5. Select a user and go to Media tab
6. Add media:

   - Type: `Telegram`
   - Send to: `your_chat_id` (e.g., `-123456789` for groups or `123456789` for private chats)

7. Create or modify triggers to send notifications

## Testing

Test the script manually:

```bash
docker exec zabbix-server /usr/lib/zabbix/alertscripts/telegram_alert.sh "your_chat_id" "Test Subject" "Test Message"
```

## Troubleshooting

- Check container logs: `docker logs zabbix-server`
- Verify bot token is correct
- Ensure chat ID is correct (negative for groups, positive for private chats)
- Make sure the bot has permission to send messages to the chat/group
