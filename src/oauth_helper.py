import sys
import os
import json
import time
import requests

CLIENT_ID = "861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com"
CLIENT_SECRET = "SboVhoG9s0rNafixCSGGKXAT"
DEVICE_CODE_URL = "https://oauth2.googleapis.com/device/code"
TOKEN_URL = "https://oauth2.googleapis.com/token"
SCOPE = "http://gdata.youtube.com https://www.googleapis.com/auth/youtube-paid-content"

TOKEN_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tokens.json")

def request_device_code():
    try:
        resp = requests.post(DEVICE_CODE_URL, data={
            "client_id": CLIENT_ID,
            "scope": SCOPE
        }, timeout=10)
        
        if resp.status_code == 200:
            data = resp.json()
            # print output in formatted json for Flutter to parse
            print(json.dumps({
                "status": "ok",
                "device_code": data.get("device_code"),
                "user_code": data.get("user_code"),
                "verification_url": data.get("verification_url", "https://www.google.com/device"),
                "interval": data.get("interval", 5),
                "expires_in": data.get("expires_in", 1800)
            }), flush=True)
        else:
            print(json.dumps({
                "status": "error",
                "message": f"Google API error: {resp.status_code} - {resp.text}"
            }), flush=True)
    except Exception as e:
        print(json.dumps({
            "status": "error",
            "message": str(e)
        }), flush=True)

def poll_for_token(device_code, interval=5, timeout=300):
    start_time = time.time()
    while time.time() - start_time < timeout:
        time.sleep(interval)
        try:
            resp = requests.post(TOKEN_URL, data={
                "client_id": CLIENT_ID,
                "client_secret": CLIENT_SECRET,
                "device_code": device_code,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            }, timeout=10)
            
            data = resp.json()
            if "access_token" in data:
                # Success! Save tokens to tokens.json
                token_data = {
                    "access_token": data.get("access_token"),
                    "refresh_token": data.get("refresh_token"),
                    "token_type": data.get("token_type"),
                    "expires_in": data.get("expires_in"),
                    "created_at": time.time(),
                    "status": "authorized"
                }
                with open(TOKEN_FILE, "w") as f:
                    json.dump(token_data, f, indent=2)
                
                print(json.dumps({
                    "status": "authorized",
                    "message": "Google Account linked successfully!"
                }), flush=True)
                return
            
            error = data.get("error")
            if error == "authorization_pending":
                print(json.dumps({"status": "pending"}), flush=True)
                continue
            elif error == "slow_down":
                interval += 2
                continue
            elif error in ("expired_token", "access_denied"):
                print(json.dumps({"status": "failed", "error": error}), flush=True)
                return
        except Exception as e:
            print(json.dumps({"status": "error", "error": str(e)}), flush=True)
            
    print(json.dumps({"status": "timeout"}), flush=True)

if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--poll":
        device_code = sys.argv[2]
        poll_for_token(device_code)
    else:
        request_device_code()
