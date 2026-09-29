#!/bin/zsh
# TestFlight 用のビルド。
#   scripts/testflight.sh export   … 署名付き .ipa を build/export に書き出す（Apple には送らない）
#   scripts/testflight.sh upload   … App Store Connect にアップロードする（TestFlight に届く）
# 前提: App Store Connect にアプリ作成済み、App Store 用プロファイル「Tokaeshi App Store」をインストール済み（docs/testflight.md）。
# App Store Connect API キーで認証する場合は ASC_KEY_PATH / ASC_KEY_ID / ASC_ISSUER_ID を環境変数で渡す。
set -euo pipefail

mode=${1:-export}
[[ $mode == export || $mode == upload ]] || { echo "usage: $0 [export|upload]" >&2; exit 64; }

cd "$(dirname "$0")/.."
build_dir=build
archive=$build_dir/Tokaeshi.xcarchive
# ビルド番号はアップロードごとに増やす必要がある。既定は git のコミット数（BUILD_NUMBER で上書き可）
build_number=${BUILD_NUMBER:-$(git rev-list --count HEAD)}

auth=()
if [[ -n ${ASC_KEY_PATH:-} ]]; then
  auth=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

xcodegen generate

(cd Core && swift test)

xcodebuild archive \
  -project NumberOthello.xcodeproj -scheme NumberOthello -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive" \
  CURRENT_PROJECT_VERSION="$build_number" \
  -allowProvisioningUpdates "${auth[@]}"

export_options=$build_dir/ExportOptions.plist
cp scripts/ExportOptions.plist "$export_options"
plutil -replace destination -string "$mode" "$export_options"

xcodebuild -exportArchive \
  -archivePath "$archive" -exportPath "$build_dir/export" -exportOptionsPlist "$export_options" \
  -allowProvisioningUpdates "${auth[@]}"

# ExportOptions の manageAppVersionAndBuildNumber により、upload 時に Xcode が番号を繰り上げる場合がある
echo "done: mode=$mode archive_build=$build_number（配布されるビルド番号は App Store Connect で確認）"
