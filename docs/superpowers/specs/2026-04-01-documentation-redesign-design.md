# HashQuery ドキュメント再設計 設計書

**日付:** 2026-04-01
**対象:** HashQuery プロジェクトの全ドキュメント（コードは対象外）

---

## 背景と目的

既存ドキュメントは手作りの非公式フォーマットで書かれており、参考資料としての位置づけだった。
これを Claude が標準フォーマットを定義し直すことで、チームの Perl 開発者と Claude の両方が正式な仕様として読めるドキュメント体系に再構築する。

---

## ディレクトリ構造

```
.
├── src/
│   └── HashQuery.pm               # モジュール本体（対象外）
├── test/
│   └── hashquery.t                # テスト（対象外）
├── examples/
│   └── sample_usage.pl            # 使用例（対象外）
├── docs/
│   ├── spec.md                    # 仕様書（日本語）← HashQuery_Spec.md を改名・再フォーマット
│   ├── test-spec.md               # テスト仕様書（日本語）← HashQuery_TestSpec.md を改名・再フォーマット
│   └── CodingRule.md              # コーディングルール参考文献（変更なし）
├── README.md                      # 英語 — プロジェクトの顔・チームへの入口
└── CLAUDE.md                      # 日本語 — Claude Code 専用操作指示
```

### ファイルの役割定義

| ファイル | 読者 | 言語 | 役割 |
|---|---|---|---|
| `README.md` | 人間（チーム） | 英語 | 概要・インストール・クイックスタート・docs/ への誘導 |
| `docs/spec.md` | 人間 + Claude | 日本語 | 機能仕様・設計判断・API 定義 |
| `docs/test-spec.md` | 人間 + Claude | 日本語 | テストケース定義・テストデータ |
| `docs/CodingRule.md` | 参考文献 | 日本語 | 変更なし |
| `CLAUDE.md` | Claude | 日本語 | 変更フロー・コーディング規約・コミット規則 |

---

## 各ファイルのフォーマット仕様

### README.md（英語）

人間向けの唯一の入口。英語で書き、チームの Perl 開発者が 5 分で全体を把握できることを目標とする。

```
# HashQuery
<one-liner: what it is>

## Requirements
<Perl version, dependencies>

## Installation
<cpanm command + use statement>

## Quick Start
<最小限のコード例 1 つ>

## Features
<提供する関数・機能の一覧テーブル>

## Documentation
<docs/ 内の各ファイルへのリンクと説明>

## Testing
<テスト実行コマンドと出力例>
```

**フォーマット原則:**
- セクションは上記 7 つに固定する
- Quick Start のコード例は 1 つだけ。詳細は docs/spec.md へ誘導する
- 技術的詳細は README に書かない

---

### docs/spec.md（日本語）

機能仕様・API リファレンス・設計判断を記述する正式仕様書。

```
# HashQuery 仕様書

## 0. 設計原則
<絶対条件・基本原則の箇条書き>

## 1. 提供関数一覧
<関数名・役割・分類のテーブル>

## 2. DSL 構文
<プロトタイプ定義と基本構文例>

## 3. 各関数リファレンス
### query
### as
### select
### where
### having
<各関数: シグネチャ・動作説明・コード例>

## 4. 条件メソッド（where / having 共通）
<like / not_like / between / in / not_in / asNull>

## 5. where 専用関数
<grep_concat>

## 6. having 専用集計関数
<count_by / max_by / min_by / first_by / last_by>

## 7. 実行モデル
<処理順序の説明と図>

## 8. 制約・注意事項
<箇条書き>
```

**フォーマット原則:**
- 各関数リファレンスは「シグネチャ → 動作説明 → コード例」の順で統一する
- 設計判断（なぜそうなっているか）は動作説明に含める
- 見出しレベルは H2 までを基本とし、関数リファレンスのみ H3 を使う

---

### docs/test-spec.md（日本語）

テストケースの定義書。テストコードを書く前に参照する仕様。

```
# HashQuery テスト仕様書

## テストデータ
<各テーブルの名前・定義・用途をテーブル形式で記述>

## テストケース
### 1. query — 基本動作
### 2. select
### 3. where
### 4. grep_concat
### 5. having
### 6. as
### 7. 組み合わせ
```

各テストケースは以下のフォーマットで統一する:

```
| No. | 説明 | 入力 / 条件 | 期待結果 |
|-----|------|------------|---------|
```

**フォーマット原則:**
- テストデータは先頭にまとめ、テストケース内で参照する（定義の重複を避ける）
- No. はセクション内で連番（例: `where-1`, `where-2`）ではなく全体通し番号
- 期待結果は「行数」「列」「値」を明記する

---

### CLAUDE.md（日本語）

Claude Code が操作する際の指示ファイル。簡潔・命令形で書く。

```
# コーディング規約
<変数名・設計方針の要点のみ箇条書き>

# Git 運用
<git add / commit の手順>

# 変更フロー
<番号付き手順: 仕様書 → テスト仕様書 → コード → テスト → コミット>

# 実装前の確認
<変更箇所を提示して承認を得る旨>

# ドキュメント同期
<コード変更時の README / spec / test-spec 更新ルール>

# コミット前の README 確認
<README との整合確認手順>
```

**フォーマット原則:**
- CodingRule.md の要約版として機能させる（詳細は CodingRule.md を参照）
- 命令形・箇条書きを基本とする
- セクションは H1 で統一（ネストしない）

---

## 移行方針

1. `docs/HashQuery_Spec.md` → `docs/spec.md`（改名 + 再フォーマット）
2. `docs/HashQuery_TestSpec.md` → `docs/test-spec.md`（改名 + 再フォーマット）
3. `docs/CodingRule.md` → 変更なし
4. `README.md` → 再フォーマット（英語化）
5. `CLAUDE.md` → 再設計

旧ファイル（`HashQuery_Spec.md`, `HashQuery_TestSpec.md`）は新ファイル作成後に削除する。

---

## 対象外

- `src/HashQuery.pm`
- `test/hashquery.t`
- `examples/sample_usage.pl`
- `docs/CodingRule.md`
