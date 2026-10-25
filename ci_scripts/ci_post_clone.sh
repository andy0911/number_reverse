#!/bin/zsh
# Xcode Cloud 用: クローン直後に実行される。NumberOthello.xcodeproj は Git 管理外（project.yml から生成）なので、
# ここで xcodegen を入れて生成する。ビルド番号は Xcode Cloud の CI_BUILD_NUMBER が自動で使われる。
set -euo pipefail

cd "$CI_PRIMARY_REPOSITORY_PATH"

if ! command -v xcodegen >/dev/null 2>&1; then
  # Homebrew の自動更新・自動クリーンアップは時間の無駄なので止める
  HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install xcodegen
fi

xcodegen generate
