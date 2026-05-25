#!/bin/bash

set -e

cd "$(dirname "$0")"

PROJECT_NAME=$(basename "$PWD")
SITE_TITLE="${PROJECT_NAME}"
ADMIN_USER="admin"
ADMIN_PASSWORD="password"
ADMIN_EMAIL="test@example.com"

echo "========================================"
echo "WordPress ローカル環境セットアップ"
echo "========================================"
echo ""

if ! command -v ddev >/dev/null 2>&1; then
  echo "エラー: DDEV がインストールされていません。"
  echo "先に DDEV をインストールしてください。"
  exit 1
fi

echo "DDEVプロジェクト名を確認します..."

if [ -f ".ddev/config.yaml" ]; then
  sed -i '' "s/^name: .*/name: ${PROJECT_NAME}/" .ddev/config.yaml
  echo "DDEVプロジェクト名を ${PROJECT_NAME} に設定しました。"
else
  echo "エラー: .ddev/config.yaml が見つかりません。"
  exit 1
fi

echo "DDEVを起動します..."
ddev start

echo ""
echo "WordPress本体を確認します..."

if [ ! -f "public/wp-load.php" ]; then
  echo "WordPress本体が見つからないため、日本語版WordPressをダウンロードします..."
  ddev wp core download --locale=ja
else
  echo "WordPress本体はすでに存在します。"
fi

echo ""
echo "wp-config.phpを確認します..."

if [ ! -f "public/wp-config.php" ]; then
  echo "wp-config.phpを作成します..."
  ddev wp config create \
    --dbname=db \
    --dbuser=db \
    --dbpass=db \
    --dbhost=db
else
  echo "wp-config.phpはすでに存在します。"
fi

echo ""
echo "WordPressのインストール状態を確認します..."

if ! ddev wp core is-installed >/dev/null 2>&1; then
  echo "WordPressをインストールします..."

  PRIMARY_URL=$(ddev describe -j | php -r '
    $json = stream_get_contents(STDIN);
    $data = json_decode($json, true);
    echo $data["raw"]["primary_url"] ?? "";
  ')

  if [ -z "$PRIMARY_URL" ]; then
    PRIMARY_URL="https://${PROJECT_NAME}.ddev.site"
  fi

  ddev wp core install \
    --url="$PRIMARY_URL" \
    --title="$SITE_TITLE" \
    --admin_user="$ADMIN_USER" \
    --admin_password="$ADMIN_PASSWORD" \
    --admin_email="$ADMIN_EMAIL"
else
  echo "WordPressはすでにインストール済みです。"
fi

echo ""
echo "WordPressを日本語環境に設定します..."

ddev wp language core install ja || true
ddev wp site switch-language ja

ddev wp option update timezone_string "Asia/Tokyo"
ddev wp option update date_format "Y年n月j日"
ddev wp option update time_format "H:i"
ddev wp option update start_of_week 1

echo ""
echo "不要な初期プラグインを削除します..."

ddev wp plugin delete hello --quiet || true
ddev wp plugin delete akismet --quiet || true

echo ""
echo "共通プラグインをインストール・有効化します..."

ddev wp plugin install wp-multibyte-patch --activate
ddev wp plugin install breadcrumb-navxt --activate
ddev wp plugin install custom-post-type-permalinks --activate
ddev wp plugin install seo-simple-pack --activate
ddev wp plugin install flexible-table-block --activate

echo ""
echo "パーマリンク設定を更新します..."

ddev wp option update permalink_structure "/%postname%/"
ddev wp rewrite flush

echo ""
echo "========================================"
echo "セットアップが完了しました！"
echo "========================================"
echo ""

echo "サイトURL:"
ddev describe | grep "Primary URL" || true

echo ""
echo "管理画面:"
echo "https://${PROJECT_NAME}.ddev.site/wp-admin"

echo ""
echo "ログイン情報:"
echo "ユーザー名: ${ADMIN_USER}"
echo "パスワード: ${ADMIN_PASSWORD}"
echo ""

echo "ACF PROなど案件固有のプラグインは、必要に応じて管理画面から追加してください。"