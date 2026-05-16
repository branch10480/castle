# Swiftail Pixel Pet Assets

フェレットの iOS アプリエンジニア風オリジナルキャラクター「Swiftail」の細かめドット絵版 Codex Pet 素材セットです。

通常版 Swiftail は `codex/pet-assets/swiftail/` に残し、このディレクトリは別 ID の `swiftail-pixel` として管理します。

## 収録素材

### Codex Pet用パッケージ

`pet-package/` 以下は Codex app の `/pet` で使うためのローカルカスタムペットパッケージです。

- `pet.json` - Swiftail Pixel のカスタムペット manifest
- `spritesheet.png` - Codex Pet 仕様の 8x9 スプライトアトラス（manifest では PNG を使用）
- `spritesheet.webp` - lossless WebP 版の予備ファイル

全 state で使えるフレーム枠をできるだけ埋めています。

```text
idle          6 frames
running-right 8 frames
running-left  8 frames
waving        4 frames
jumping       5 frames
failed        8 frames
waiting       6 frames
running       6 frames
review        6 frames
```

### QA

- `qa/contact-sheet.png` - 全 state / frame の確認用 contact sheet
- `qa/validation-png.json` - PNG atlas の検証結果
- `qa/validation-webp.json` - WebP atlas の検証結果
