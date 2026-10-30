#!/usr/bin/env python3
"""ASC App Analytics Reports API の取得手順（report request の作成・状況確認・レポート取得）。

使い方:
  python3 scripts/app_analytics.py status            # request / report / instance の一覧（読み取り）
  python3 scripts/app_analytics.py create --yes      # ONGOING の report request を作成（書き込み。ユーザーの明示承認後のみ）
  python3 scripts/app_analytics.py fetch NAME [DIR]  # NAME を含む report の最新 instance をDL・展開（読み取り）
必要な環境変数: ASC_ADMIN_KEY_ID / ASC_ADMIN_KEY_P8_BASE64 / ASC_ISSUER_ID（Admin か App Manager のキー。
Sales and Trends 用の読み取りキー ASC_KEY_ID では 403 になる）。
"""
import base64, gzip, json, os, sys, time, urllib.error, urllib.request
import jwt  # PyJWT + cryptography

APP_ID = "6817160128"  # トオカエシ (Apple ID)
API = "https://api.appstoreconnect.apple.com"


def token():
    key = base64.b64decode(os.environ["ASC_ADMIN_KEY_P8_BASE64"])
    claims = {"iss": os.environ["ASC_ISSUER_ID"], "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"}
    return jwt.encode(claims, key, algorithm="ES256", headers={"kid": os.environ["ASC_ADMIN_KEY_ID"]})


def call(method, path, body=None):
    req = urllib.request.Request(path if path.startswith("http") else API + path, method=method,
                                 data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as f:
            return json.loads(f.read() or b"{}")
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path} -> {e.code}: {e.read().decode()[:300]}")


def requests_():
    return call("GET", f"/v1/apps/{APP_ID}/analyticsReportRequests")["data"]


def status():
    for r in requests_():
        print(f"request {r['id']} {r['attributes']['accessType']} stoppedDueToInactivity={r['attributes'].get('stoppedDueToInactivity')}")
        for rep in call("GET", f"/v1/analyticsReportRequests/{r['id']}/reports?limit=200")["data"]:
            a = rep["attributes"]
            inst = call("GET", f"/v1/analyticsReports/{rep['id']}/instances?filter[granularity]=DAILY&limit=200")["data"]
            dates = sorted(i["attributes"]["processingDate"] for i in inst)
            print(f"  {a['category']:<24} {a['name']:<50} DAILY instances {len(dates)} {dates[:1]}〜{dates[-1:]}")


def create():
    if "--yes" not in sys.argv:
        sys.exit("書き込みです。ユーザーの明示承認後に --yes を付けて実行する")
    if any(r["attributes"]["accessType"] == "ONGOING" for r in requests_()):
        sys.exit("ONGOING の request は既にある（1アプリ1件）。status で確認する")
    body = {"data": {"type": "analyticsReportRequests", "attributes": {"accessType": "ONGOING"},
                     "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}
    print(call("POST", "/v1/analyticsReportRequests", body)["data"]["id"], "作成。レポートは作成後1〜2日で現れる")


def fetch(name, out="."):
    for r in requests_():
        for rep in call("GET", f"/v1/analyticsReportRequests/{r['id']}/reports?limit=200")["data"]:
            if name not in rep["attributes"]["name"]:
                continue
            inst = call("GET", f"/v1/analyticsReports/{rep['id']}/instances?filter[granularity]=DAILY&limit=200")["data"]
            for i in sorted(inst, key=lambda i: i["attributes"]["processingDate"])[-1:]:
                for seg in call("GET", f"/v1/analyticsReportInstances/{i['id']}/segments")["data"]:
                    with urllib.request.urlopen(seg["attributes"]["url"], timeout=60) as f:  # 署名付きURL。認証ヘッダ不要
                        text = gzip.decompress(f.read()).decode("utf-8")
                    path = os.path.join(out, f"{rep['attributes']['name']}_{i['attributes']['processingDate']}.tsv")
                    open(path, "w").write(text); print(path)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    {"status": status, "create": create}.get(cmd, lambda: fetch(*sys.argv[2:4]))()
