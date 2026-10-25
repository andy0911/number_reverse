#!/usr/bin/env python3
"""週次KPIのうち ASC Sales and Trends で取れる分（新規DL・IAP）を読み取りで集計する。

使い方: python3 scripts/weekly_kpi.py [YYYY-MM-DD]   # 指定日を含む直近7暦日（省略時は2日前まで）
必要な環境変数: ASC_KEY_ID / ASC_KEY_P8_BASE64 / ASC_ISSUER_ID / ASC_VENDOR_NUMBER
書き込みはしない。AdMob・DAU・継続率はここでは取れない（docs/kpi.md 参照）。
"""
import base64, datetime, gzip, io, json, os, sys, time, urllib.error, urllib.request
import jwt  # PyJWT + cryptography

APP_ID = "6817160128"  # トオカエシ (Apple ID)
API = "https://api.appstoreconnect.apple.com"


def token():
    key = base64.b64decode(os.environ["ASC_KEY_P8_BASE64"])
    claims = {"iss": os.environ["ASC_ISSUER_ID"], "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"}
    return jwt.encode(claims, key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"]})


def daily(date, tok):
    q = (f"/v1/salesReports?filter[frequency]=DAILY&filter[reportType]=SALES&filter[reportSubType]=SUMMARY"
         f"&filter[vendorNumber]={os.environ['ASC_VENDOR_NUMBER']}&filter[reportDate]={date}&filter[version]=1_0")
    try:
        with urllib.request.urlopen(urllib.request.Request(API + q, headers={"Authorization": "Bearer " + tok, "Accept": "application/a-gzip"}), timeout=60) as f:
            text = gzip.decompress(f.read()).decode("utf-8")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None  # 404: その日の売上行なし（0件）か、未公開（直近1〜2日）
        raise
    rows = [l.split("\t") for l in text.splitlines()]
    head, body = rows[0], rows[1:]
    return [dict(zip(head, r)) for r in body]


def main():
    end = datetime.date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else datetime.date.today() - datetime.timedelta(days=2)
    tok = token()
    total_dl = total_iap = 0
    missing = []
    for i in range(6, -1, -1):
        d = end - datetime.timedelta(days=i)
        rows = daily(d, tok)
        if rows is None:
            if d >= datetime.date.today() - datetime.timedelta(days=1):
                missing.append(str(d)); print(f"{d}  未公開（欠損）"); continue
            print(f"{d}  新規DL 0  IAP 0  （レポート行なし＝0件）"); continue
        mine = [r for r in rows if r.get("Apple Identifier") == APP_ID]
        # Product Type Identifier: 1=新規DL(iPhone) 1F/1T=iPad等, IA1=アプリ内課金。再DL(3)・更新(7)は除外
        dl = sum(int(r["Units"]) for r in mine if r.get("Product Type Identifier", "").startswith("1"))
        iap = sum(int(r["Units"]) for r in mine if r.get("Product Type Identifier", "").startswith("IA"))
        total_dl += dl; total_iap += iap
        print(f"{d}  新規DL {dl}  IAP {iap}")
    print(f"\n{end - datetime.timedelta(days=6)}〜{end}  新規DL計 {total_dl}  IAP計 {total_iap}  欠損日 {len(missing)} {missing}")


if __name__ == "__main__":
    main()
