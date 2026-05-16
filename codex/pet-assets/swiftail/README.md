# Swiftail Pet Assets

フェレットのiOSアプリエンジニア風オリジナルキャラクター「Swiftail」の素材セットです。

## 収録素材

### Pet用透過PNG

`transparent/` 以下は背景透過済みです。

- `pet_idle.png` - 待機ポーズ
- `pet_typing_01.png` - タイピングフレーム1
- `pet_typing_02.png` - タイピングフレーム2
- `pet_typing_03.png` - タイピングフレーム3
- `pet_typing_04.png` - タイピングフレーム4
- `pet_success.png` - 成功・完了リアクション
- `pet_sleep.png` - 休憩・スリープポーズ

### Codex Pet用パッケージ

`pet-package/` 以下は Codex app の `/pet` で使うためのローカルカスタムペットパッケージです。

- `pet.json` - Swiftail のカスタムペット manifest
- `spritesheet.webp` - Codex Pet 仕様の 8x9 スプライトアトラス
- `spritesheet.png` - WebP 生成元の確認用 PNG

### SNS用画像

- `profile/swiftail_profile_square.png` - 正方形プロフィール画像
- `profile/swiftail_profile_background.png` - レトロゲーム風背景付き正方形プロフィール画像

### x.com用画像

- `banner/swiftail_x_header_retro.png` - レトロゲーム風ヘッダー画像

### 元画像

`source/` 以下には、透過処理前のクロマキー背景つき元画像を保存しています。

## タイピングアニメーション例

以下の順でループすると、軽快にキーボードを打っている動きになります。

```text
pet_typing_01.png
pet_typing_02.png
pet_typing_03.png
pet_typing_04.png
pet_typing_02.png
```

おすすめ表示時間は1フレームあたり80〜140msです。
