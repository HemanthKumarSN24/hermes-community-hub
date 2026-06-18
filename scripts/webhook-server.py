#!/usr/bin/env python3
"""Hermes Hub Webhook Server — handles rate, search, publish for local n8n"""
import json, os, subprocess, sys
from http.server import HTTPServer, BaseHTTPRequestHandler

HUB_DIR = os.path.expanduser("~/Downloads/hermes/files/hermes-community-hub")
HOST, PORT = "127.0.0.1", 7890

class HubHandler(BaseHTTPRequestHandler):
    def _send(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _git_commit(self, msg, files="."):
        subprocess.run(["git", "add", files], cwd=HUB_DIR, capture_output=True)
        r = subprocess.run(["git", "commit", "-m", msg], cwd=HUB_DIR, capture_output=True, text=True)
        subprocess.run(["git", "push"], cwd=HUB_DIR, capture_output=True)
        return r.stdout

    def do_GET(self):
        if self.path == "/hub/search":
            idx = json.load(open(f"{HUB_DIR}/index.json"))
            skills = idx.get("skills", []) if isinstance(idx, dict) else idx
            self._send({"skills": skills})
        elif self.path.startswith("/hub/search?q="):
            term = self.path.split("?q=")[1].lower()
            idx = json.load(open(f"{HUB_DIR}/index.json"))
            skills = idx.get("skills", []) if isinstance(idx, dict) else idx
            results = [s for s in skills if term in (s.get("name","")+s.get("description","")+str(s.get("tags",""))).lower()]
            self._send({"skills": results})
        else:
            self._send({"error": "not found"}, 404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length)) if length else {}
        if self.path == "/hub/rate":
            ratings = json.load(open(f"{HUB_DIR}/data/ratings.json"))
            ratings["ratings"].append(body)
            json.dump(ratings, open(f"{HUB_DIR}/data/ratings.json","w"), indent=2)
            self._git_commit(f"rating: {body.get('skill_name','?')} - {body.get('rating','?')}/5", "data/ratings.json")
            # Rebuild index to update trending
            subprocess.run([sys.executable, f"{HUB_DIR}/scripts/build-index.py"], cwd=HUB_DIR)
            self._git_commit("rebuild index after rating", "index.json")
            self._send({"status": "rated"})
        elif self.path == "/hub/publish":
            name = body.get("skill_name", "")
            skel = body.get("skill_md", "")
            if not name or not skel:
                self._send({"error": "skill_name and skill_md required"}, 400)
                return
            os.makedirs(f"{HUB_DIR}/skills/{name}", exist_ok=True)
            with open(f"{HUB_DIR}/skills/{name}/SKILL.md","w") as f:
                f.write(skel)
            self._git_commit(f"publish: {name}", f"skills/{name}")
            subprocess.run([sys.executable, f"{HUB_DIR}/scripts/build-index.py"], cwd=HUB_DIR)
            self._git_commit("rebuild index", "index.json")
            self._send({"status": "published", "skill": name})
        else:
            self._send({"error": "not found"}, 404)

    def log_message(self, format, *args): pass  # quiet

if __name__ == "__main__":
    srv = HTTPServer((HOST, PORT), HubHandler)
    print(f"Hub webhook server on http://{HOST}:{PORT}")
    sys.stdout.flush()
    srv.serve_forever()