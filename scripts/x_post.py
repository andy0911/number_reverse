#!/usr/bin/env python3
"""docs/x-queue.json の投稿のうち、予定時刻を過ぎた未投稿分を X API で投稿する。

使い方:
  python3 scripts/x_post.py             # ドライラン（検査だけ。投稿しない）
  python3 scripts/x_post.py --send      # 予定時刻を過ぎた未投稿を投稿し、キューに投稿IDを書き戻す
必要な環境変数（--send のときだけ）: X_API_KEY / X_API_SECRET / X_ACCESS_TOKEN / X_ACCESS_SECRET
テキストのみ（画像・動画は未対応。メディアAPIの料金が未確認のため）。URL付き投稿は1本$0.20（docs/x-posting.md）。
"""
import base64, datetime, hashlib, hmac, json, os, secrets, sys, time, urllib.parse, urllib.request

QUEUE = os.path.join(os.path.dirname(__file__), "..", "docs", "x-queue.json")
URL = "https://api.x.com/2/tweets"
CREDIT = "原案: @bdgame_"
FORBIDDEN = ["オセロ", "10で返す", "足して10で挟む", "3分で1局", "新感覚", "話題", "人気"]


def check(post):
    """投稿前チェック。問題のリストを返す（空なら通過）。"""
    t, errs = post["text"], []
    if CREDIT not in t:
        errs.append(f"「{CREDIT}」がない")
    if "?ct=" not in t:
        errs.append("?ct= の識別リンクがない")
    errs += [f"禁止語「{w}」" for w in FORBIDDEN if w in t]
    n = sum(1 if ord(c) < 0x2000 else 2 for c in t)  # 全角は2、URLは23として数える近似
    if n > 280:
        errs.append(f"長すぎる（概算{n}/280）")
    return errs


def oauth_header(method, url):
    p = {"oauth_consumer_key": os.environ["X_API_KEY"], "oauth_nonce": secrets.token_hex(16),
         "oauth_signature_method": "HMAC-SHA1", "oauth_timestamp": str(int(time.time())),
         "oauth_token": os.environ["X_ACCESS_TOKEN"], "oauth_version": "1.0"}
    q = lambda s: urllib.parse.quote(str(s), safe="~")
    base = "&".join([method, q(url), q("&".join(f"{q(k)}={q(v)}" for k, v in sorted(p.items())))])  # JSON本文は署名に含めない
    key = f"{q(os.environ['X_API_SECRET'])}&{q(os.environ['X_ACCESS_SECRET'])}"
    p["oauth_signature"] = base64.b64encode(hmac.new(key.encode(), base.encode(), hashlib.sha1).digest()).decode()
    return "OAuth " + ", ".join(f'{q(k)}="{q(v)}"' for k, v in sorted(p.items()))


def send(text):
    req = urllib.request.Request(URL, data=json.dumps({"text": text}).encode(), method="POST",
                                 headers={"Authorization": oauth_header("POST", URL), "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as f:
        return json.load(f)["data"]["id"]


def main():
    do_send = "--send" in sys.argv
    with open(QUEUE, encoding="utf-8") as f:
        queue = json.load(f)
    now = datetime.datetime.now(datetime.timezone.utc)
    bad = False
    for post in queue["posts"]:
        errs = check(post)
        due = datetime.datetime.fromisoformat(post["scheduled_at"]) <= now
        state = "投稿済み" if post.get("tweet_id") else ("予定時刻超過" if due else "待機")
        print(f"{post['id']}: {state}" + (f" 検査NG: {'; '.join(errs)}" if errs else " 検査OK"))
        bad |= bool(errs)
    if bad:
        sys.exit("検査NGがあるため投稿しない")
    if not do_send:
        return
    if not queue.get("approved"):
        sys.exit("approved が true でないため投稿しない（あんでぃさんの承認後に true にする）")
    for post in queue["posts"]:
        if post.get("tweet_id") or datetime.datetime.fromisoformat(post["scheduled_at"]) > now:
            continue
        post["tweet_id"] = send(post["text"])
        post["posted_at"] = now.isoformat()
        with open(QUEUE, "w", encoding="utf-8") as f:  # 1本ごとに書き戻し、二重投稿を防ぐ
            json.dump(queue, f, ensure_ascii=False, indent=2)
        print("投稿:", post["id"], post["tweet_id"])


if __name__ == "__main__":
    main()
