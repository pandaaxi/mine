import os
import time
import requests
from zipfile import ZipFile, ZIP_DEFLATED

bot_token = os.getenv('TELEGRAM_BOT_TOKEN')
chat_id = os.getenv('TELEGRAM_CHAT_ID')
directory_path = '/app/data'  # Set the directory path

def send_telegram_document(bot_token, chat_id, document_path):
    """
    Send a document to a Telegram chat using a bot.
    """
    url = f"https://api.telegram.org/bot{bot_token}/sendDocument"
    with open(document_path, 'rb') as document:
        files = {'document': document}
        data = {'chat_id': chat_id}
        response = requests.post(url, files=files, data=data)
        print(f"Sent {document_path}: {response.text}")

def main():
    while True:
        for item in os.listdir(directory_path):
            full_path = os.path.join(directory_path, item)
            if os.path.isfile(full_path):
                print(f"Sending file {full_path}...")
                send_telegram_document(bot_token, chat_id, full_path)

        print("Waiting for 5 hours before next send...")
        time.sleep(28800 )  # Delay for 5 hours; 18000 seconds

if __name__ == "__main__":
    main()
