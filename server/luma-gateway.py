#!/usr/bin/env python3
import argparse
import html
import json
import re
import socket
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


MAX_BYTES = 512_000
MAX_TEXT = 24_000
USER_AGENT = "LumaGateway/0.1"


class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.title = ""
        self._in_title = False
        self._parts = []
        self._skip_depth = 0

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag == "title":
            self._in_title = True
        if tag in {"script", "style", "noscript", "svg"}:
            self._skip_depth += 1
        if tag in {"p", "br", "div", "section", "article", "header", "footer", "li", "h1", "h2", "h3"}:
            self._parts.append("\n")

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag == "title":
            self._in_title = False
        if tag in {"script", "style", "noscript", "svg"} and self._skip_depth > 0:
            self._skip_depth -= 1
        if tag in {"p", "div", "section", "article", "li", "h1", "h2", "h3"}:
            self._parts.append("\n")

    def handle_data(self, data):
        if self._in_title:
            self.title += data.strip() + " "
        if self._skip_depth == 0:
            self._parts.append(data)

    def text(self):
        raw = html.unescape(" ".join(self._parts))
        raw = re.sub(r"[ \t\r\f\v]+", " ", raw)
        raw = re.sub(r"\n\s+", "\n", raw)
        raw = re.sub(r"\n{3,}", "\n\n", raw)
        return raw.strip()


def lan_ip():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("8.8.8.8", 80))
            return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"


def fetch_url(url):
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in {"http", "https"}:
        raise ValueError("only http and https URLs are allowed")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "text/html,text/plain,*/*"})
    with urllib.request.urlopen(request, timeout=12) as response:
        status = getattr(response, "status", 200)
        content_type = response.headers.get("content-type", "")
        raw = response.read(MAX_BYTES)
        charset = response.headers.get_content_charset() or "utf-8"
    body = raw.decode(charset, errors="replace")
    if "html" in content_type.lower() or "<html" in body[:500].lower():
        parser = TextExtractor()
        parser.feed(body)
        title = parser.title.strip() or parsed.netloc
        text = parser.text()
    else:
        title = parsed.netloc
        text = body
    return {
        "ok": True,
        "url": url,
        "status": status,
        "title": title[:120],
        "text": text[:MAX_TEXT],
    }


def search_web(query):
    search_url = "https://duckduckgo.com/html/?" + urllib.parse.urlencode({"q": query})
    page = fetch_url(search_url)
    lines = [line.strip() for line in page["text"].splitlines() if line.strip()]
    results = []
    for line in lines:
        if len(results) >= 8:
            break
        if query.lower() in line.lower() and len(line) > 12:
            results.append({
                "title": line[:100],
                "url": search_url,
                "snippet": line[:180],
            })
    if not results:
        results.append({
            "title": "Open web search",
            "url": search_url,
            "snippet": "Search results are available through the gateway.",
        })
    return {"ok": True, "query": query, "results": results}


class Handler(BaseHTTPRequestHandler):
    def send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed.query)
        try:
            if parsed.path == "/health":
                self.send_json(200, {"ok": True, "service": "luma-gateway"})
            elif parsed.path == "/fetch":
                url = query.get("url", [""])[0]
                if not url:
                    self.send_json(400, {"ok": False, "error": "url is required"})
                    return
                self.send_json(200, fetch_url(url))
            elif parsed.path == "/search":
                search_query = query.get("q", [""])[0]
                if not search_query:
                    self.send_json(400, {"ok": False, "error": "q is required"})
                    return
                self.send_json(200, search_web(search_query))
            else:
                self.send_json(404, {"ok": False, "error": "not found"})
        except Exception as exc:
            self.send_json(502, {"ok": False, "error": str(exc)})

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args))


def main():
    parser = argparse.ArgumentParser(description="Luma web gateway")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=9000)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print("Luma Gateway")
    print("Local: http://127.0.0.1:%d" % args.port)
    print("LAN:   http://%s:%d" % (lan_ip(), args.port))
    server.serve_forever()


if __name__ == "__main__":
    main()
