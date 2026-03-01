---
name: text-milk
description: Send a text message to Milk (the human operator) via iMessage on the Mac. Use when you need to text Milk directly - examples: sending urgent alerts, quick status updates, or when the human is not reachable via Telegram/Discord.
---

# Text Milk

Send a text message to Milk (the human operator) via iMessage.

## Phone Numbers

- **Milk's phone:** +1 (248) 388-4297 (human operator - for texts TO Milk)

## How to Send

Use `osascript` to send via the Mac's Messages app:

```bash
osascript -e 'tell application "Messages" to send "YOUR MESSAGE" to buddy "+12483884297"'
```

## Usage

- **Urgent alerts**: When something requires immediate human attention
- **Quick updates**: When a short status message is needed
- **Fallback**: When Telegram/Discord are unavailable

## Notes

- Requires the Mac to be running and logged in
- Messages app must be accessible
- No media attachments supported via this method — plain text only
