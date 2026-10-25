#!/usr/bin/env python3
"""AdMob の日次（表示回数・推定収益・eCPM）を読み取りで取得し、アプリ別に出力する。

使い方: python3 scripts/admob_report.py [開始日 終了日]   # 省略時は直近7日（今日を除く）
必要な環境変数: ADMOB_CLIENT_ID / ADMOB_CLIENT_SECRET / ADMOB_REFRESH_TOKEN
ネットワーク許可: oauth2.googleapis.com, admob.googleapis.com
書き込みはしない。
"""
import datetime, json, os, sys, urllib.error, urllib.parse, urllib.request


def call(url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=60) as f:
            return json.load(f)
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read().decode()[:500]}")


def access_token():
    body = urllib.parse.urlencode({
        "grant_type": "refresh_token", "client_id": os.environ["ADMOB_CLIENT_ID"],
        "client_secret": os.environ["ADMOB_CLIENT_SECRET"], "refresh_token": os.environ["ADMOB_REFRESH_TOKEN"],
    }).encode()
    return call("https://oauth2.googleapis.com/token", body)["access_token"]


def main():
    today = datetime.date.today()
    start = datetime.date.fromisoformat(sys.argv[1]) if len(sys.argv) > 2 else today - datetime.timedelta(days=7)
    end = datetime.date.fromisoformat(sys.argv[2]) if len(sys.argv) > 2 else today - datetime.timedelta(days=1)
    h = {"Authorization": "Bearer " + access_token()}
    acc = call("https://admob.googleapis.com/v1/accounts", headers=h)["account"][0]
    spec = {"reportSpec": {
        "dateRange": {"startDate": {"year": start.year, "month": start.month, "day": start.day},
                      "endDate": {"year": end.year, "month": end.month, "day": end.day}},
        "dimensions": ["DATE", "APP"],
        "metrics": ["IMPRESSIONS", "ESTIMATED_EARNINGS"],
        "localizationSettings": {"currencyCode": "JPY"}}}
    res = call(f"https://admob.googleapis.com/v1/{acc['name']}/networkReport:generate",
               json.dumps(spec).encode(), {**h, "Content-Type": "application/json"})
    imp = 0
    earn = 0.0
    for item in res:
        r = item.get("row")
        if not r:
            continue
        d, m = r["dimensionValues"], r["metricValues"]
        i = int(m.get("IMPRESSIONS", {}).get("integerValue", 0))
        e = int(m.get("ESTIMATED_EARNINGS", {}).get("microsValue", 0)) / 1e6
        imp += i; earn += e
        print(d["DATE"]["value"], d["APP"].get("displayLabel", d["APP"]["value"]),
              "表示", i, "収益(円)", round(e, 2), "eCPM(円)", round(e / i * 1000, 1) if i else "-")
    # AdMob は表示0の日の行を返さない（0件日＝行なし）。直近約3日は遅延で増えうる。
    print(f"\n{start}〜{end}  表示計 {imp}  収益計(円) {earn:.2f}  eCPM(円) {earn / imp * 1000:.1f}" if imp else f"\n{start}〜{end}  表示 0")


if __name__ == "__main__":
    main()
