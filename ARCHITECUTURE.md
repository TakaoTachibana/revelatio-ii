# REVELATIO II : System Engineering & Mathematical Specification
### Dual-Layer Tensor-Field & Graph-PDE Autopoietic Sensing Engine
#### Document Version: 2.0.0-APEP

---

## 1. System Architecture & Mathematical Foundations

REVELATIO II は、REVELATIO I におけるスカラー還元（$u(t) = \|\mathbf{v}(t)\|_2$）および擬似 1 次元格子の限界を完全突破し、**128次元特徴量テンソル場（Macro-Continuum）** と **Bluesky の動的グラフトポロジー（Micro-Interactions）** を直接結合した「グラフ偏微分方程式（Graph Reaction-Diffusion PDE）」および「リッチフロー多様体幾何学（Ricci Flow Manifold Geometry）」に基づく次世代オートポイエーティックセンシングエンジンである。

```
[Bluesky Jetstream API] 
       │
       ▼
[Phase 1: Go Ingester] ──(128D N-Gram & Graph Topology)──► [Shared Memory: Cytoplasm IV (512MB)]
                                                                  │      ▲
       ┌──────────────────────────────────────────────────────────┘      │ (New Coefficients)
       │                                                                 │
       ├──► [Phase 2A: R Analytics Kernel] ◄──(IPC Trigger)──────────────┤
       │    (TDA H₁/H₂ Persistence, Graph Laplacian L(t), Ricci Curvature)│
       │                                                                 │
       ├──► [Phase 2B: Julia Compute Engine] ────────────────────────────┘
       │    (Vector/Graph SINDy-PDE Sparse Regression)
       │
       ▼
[Phase 3: .NET Gateway Service]
       │
       ├─► [MariaDB Event Archive] (Longitudinal Structural Memory)
       │
       ▼ (WebSocket Broadcast)
[Phase 4: WebGL / React WebUI] (128D Manifold Deformable HUD)
```

### [System State Machine]
*   **STABLE** : $\text{Re}(\lambda_{\max}) \le -0.40$ かつ 局所平均曲率 $\bar{R} \ge 0$  
    $\rightarrow$ 128次元多様体上の調和的な回転・流動。通常ストリーム連続インジェクション。
*   **QUIET** : $-0.40 < \text{Re}(\lambda_{\max}) < -0.30$  
    $\rightarrow$ 局所多様体の微小振動。グラフトポロジーの近傍バッファ再構築。
*   **PERTURBED** : $-0.30 \le \text{Re}(\lambda_{\max}) < -0.05$ または 曲率歪み $|R_{ij}| > 1.2$  
    $\rightarrow$ エメラルドグリーンの流体脈動と変形。言論の過熱・偏向現象。起爆粒子（触媒ポスト）抽出アクティブ。
*   **CRITICAL** : $\text{Re}(\lambda_{\max}) \ge -0.05$ または 限界界面断絶（$H_1 / H_2$ 永続ホモロジー破綻）  
    $\rightarrow$ クリムゾンレッドの相転移（特異点スパイク発生）。限界界面穿孔ポストおよび特異点起爆ポストの 3D アンカーポップアップ表示。MariaDB への非破壊高圧縮アーカイビング発動。

### [Macro-Tensor Mathematical Equations]

1.  **グラフ反応拡散系偏微分方程式 (Graph Reaction-Diffusion PDE - Julia Engine)**:
    $N$ 個の動的ノード上の 128 次元特徴量状態行列 $\mathbf{U}(t) \in \mathbb{R}^{N \times 128}$ に対する運動方程式：
    $$\frac{\partial \mathbf{U}}{\partial t} = \mathbf{F}(\mathbf{U}) - \mathbf{D} \cdot (L(t) \otimes I_{128}) \mathbf{U}$$
    *   $\mathbf{F}(\mathbf{U}) = \mathbf{C}_1 \mathbf{U} + \mathbf{C}_2 (\mathbf{U} \circ \mathbf{U})$ : SINDy により同定される非線形自己増幅・相互作用項
    *   $L(t) = D(t) - A(t)$ : Bluesky のインタラクション（リポスト・引用・返信）から生成される動的グラフ・ラプラシアン
    *   $\mathbf{D} \in \mathbb{R}^{128 \times 128}$ : 特徴量次元間の異方性拡散テンソル

2.  **多様体計量とリッチフロー歪み (Ricci Curvature & Metric Tensor - R Engine)**:
    128次元潜在空間におけるデータ密度の局所不均一性から計量テンソル $g_{ij}$ を算出。空間の変形速度をリッチフロー方程式で記述：
    $$\frac{\partial g_{ij}}{\partial t} = -2 R_{ij}$$
    *   局所曲率 $R_{ij} < 0$ の急増は、特定の価値観・語彙への言論の急激な収縮（ブラックホール化・エコーチェンバーの巨大化）を幾何学的に判定する。

3.  **クロネッカー積固有スペクトルと相転移判定 (R Engine)**:
    結合ラプラシアン $\mathcal{L} = L(t) \otimes \Sigma_{\text{feature}}$ の最大固有値実部 $\text{Re}(\lambda_{\max})$ を算出。$\text{Re}(\lambda_{\max}) \ge -0.05$ の跳躍をもって、言論空間全体の構造的相転移（限界界面の崩壊）と定義する。

### [Micro-Particle Attribution Formula]

相転移または曲率特異点検出時における「起爆粒子（つぶやき）」の寄与スコア $S_i$ の算定：
$$S_i = \left\| \mathbf{v}_{\max}(i) \right\|^2 \cdot \left\| \nabla_{\mathbf{U}_i} \mathcal{R}_{\text{SINDy}} \right\|_F \cdot (1 + |R_{i}|)$$
*   $\mathbf{v}_{\max}(i)$ : 最大固有値 $\lambda_{\max}$ に対応する固有ベクトルの第 $i$ ノード成分
*   $\nabla_{\mathbf{U}_i} \mathcal{R}_{\text{SINDy}}$ : SINDy 残差に対するノード $i$ の感度行列（フロベニウスノルム）
*   $R_i$ : ノード $i$ 周辺の局所リッチ曲率
*   **逆射影**: スコア $S_i$ 上位のノードインデックスを、共有メモリ内の `Text LRU Buffer` の物理スロットへマッピングしてテキスト情報を即時抽出する。

---

## 2. Shared Memory Specification (Cytoplasm IV : Key 0x41504550)

*   **Total Footprint**: 512 MB (Linux System V Shared Memory)
*   **IPC Key**: `0x41504550` ("APEP")

### [Memory Layout Map]

| Address Range | Section Name | Size | Structure & Content |
| :--- | :--- | :--- | :--- |
| `0x00000000 - 0x00000100` | Header Section | 256 B | アトミックインデックス, $\text{Re}(\lambda_{\max})$, 曲率指標 $\bar{R}$, ステートフラグ, タイムスタンプ |
| `0x00000100 - 0x00000500` | Tensor Coefficients | 1,024 B | 128D SINDy 係数テンソル ($\mathbf{C}_1, \mathbf{C}_2$), 拡散テンソル $\mathbf{D}$, 残差 |
| `0x00000500 - 0x00004000` | Particle Output Area | 15,104 B | 抽出トリガーポスト (最大 64 件) のスロット ID, 寄与スコア $S_i$, 局所曲率, 構造的役割フラグ |
| `0x00004000 - 0x00044000` | Adjacency Matrix | 262,144 B | 近傍グラフの動的隣接行列 $A(t)$ (256×256 Float32 Dense Buffer) |
| `0x00044000 - 0x0C044000` | Vector Ring Buffer | 192 MB | 128D 特徴量ベクトルリングバッファ (容量: 262,144 スロット, 各 768 B [ID, TS, Float32[128]]) |
| `0x0C044000 - 0x20000000` | Text LRU Buffer | 320 MB | テキストメタデータ LRU スロット (容量: 16,384 スロット, 各 20.48 KB [URI, Author, Text, GraphMeta]) |

---

## 3. End-to-End Implementation Workflow by Layer

### Phase 1: Go Ingester & Graph Topology Extractor
1.  `bluesky_ingest.go` において Jetstream の `app.bsky.feed.post` をリアルタイム受信。
2.  テキストから 128 次元 n-gram ハッシュ射影ベクトル $\mathbf{v}_t$ を生成し、`Vector Ring Buffer` へアトミック書き込み。
3.  同時に、`reply`, `quote`, `mention` 情報を抽出し、共有メモリ内の `Adjacency Matrix` 領域上の対応するノード間の結合強度 $A_{ij}$ を動的に更新。
4.  テキスト本文、URI、DID を `Text LRU Buffer` へマルチバイト UTF-8 安全に書き込み。

### Phase 2: R & Julia Dual-Engine (Graph SINDy-PDE & Ricci Geometry)
1.  **[R Engine]**:
    *   `Vector Ring Buffer` および `Adjacency Matrix` から最新窓（例: 256ステップ）のテンソル場を取得。
    *   持続ホモロジー $H_1, H_2$ を計算。構造破綻（TDA Disruption）検知時に Julia へ IPC シグナル送信。
    *   局所計量 $g_{ij}$ からリッチ曲率 $R_{ij}$ を算出。
2.  **[Julia Engine]**:
    *   TDA シグナル受信時、128次元状態行列 $\mathbf{U}(t)$ に対する **Vector/Graph SINDy-PDE** スパース回帰を実行。
    *   非線形相互作用テンソル $\mathbf{C}_1, \mathbf{C}_2$ および拡散テンソル $\mathbf{D}$ を同定し、共有メモリの `Tensor Coefficients` へ送り返す。
3.  **[R Engine (Spectral Feedback)]**:
    *   同定されたテンソル係数を用いて結合ラプラシアン $\mathcal{L}$ を再構築し、$\text{Re}(\lambda_{\max})$ を更新。
    *   $\text{Re}(\lambda_{\max}) \ge -0.30$ または $|R_{ij}| > 1.2$ の場合、粒子寄与スコア $S_i$ を全ノードで計算。
    *   上位 64 件の起爆スロットインデックスおよび役割分類（特異点起爆 / 界面穿孔 / 渦中心）を `Particle Output Area` に書き込む。

### Phase 3: .NET Gateway Service & MariaDB Event Archive
1.  `CytoplasmReader.cs` が 共有メモリの `Particle Output Area` をゼロコピーで高速極小ポーリング。
2.  臨界イベント発祥時、抽出されたスロットインデックスに基づき `Text LRU Buffer` からポスト詳細を取得。
3.  **MariaDB への非同期永続化**:
    *   `spectrum_history_v2`: タイムスタンプ、$\text{Re}(\lambda_{\max})$、平均リッチ曲率 $\bar{R}$、SINDy テンソル係数を保存。
    *   `critical_trigger_posts_v2`: イベント ID、ポスト URI、著者 DID、本文、寄与スコア $S_i$、局所曲率 $R_i$、構造的役割分類を保存。
4.  JSON ペイロードを構築し、WebSocket 経由でフロントエンドへブロードキャスト。

### Phase 4: React / WebGL 128D Manifold Visualizer
1.  `Three.js` / WebGL カスタムシェーダーにより、128次元多様体を主成分・曲率テンソルに基づき 3D 幾何学メッシュとしてレンダリング。
2.  `Re(\lambda_{\max})` および 局所曲率 $R_{ij}$ に応じた動的マテリアル変化：
    *   STABLE: 青い幾何学的球面。調和的回転。
    *   PERTURBED: エメラルドグリーンの流体脈動と変形。
    *   CRITICAL: クリムゾンレッドへの全相転移。曲率負の特異点に鋭利な幾何学スパイクを挺出。
3.  **Holographic Card Overlay**: スパイク先端（特異点ノード）に追従する 3D アンカーカードを描画し、構造的起爆ポストの著者、本文、寄与スコア $S_i$、および「界面穿孔ポスト」「特異点起爆ポスト」のラベルをリアルタイム表示。

---

## 4. Database Schema (MariaDB)

```sql
CREATE DATABASE IF NOT EXISTS revelatio_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE revelatio_db;

-- マクロ・システム状態および多様体曲率履歴
CREATE TABLE IF NOT EXISTS spectrum_history_v2 (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    calculated_at_ns BIGINT NOT NULL,
    re_lambda_max DOUBLE NOT NULL,
    mean_ricci_curvature DOUBLE NOT NULL,
    tda_h1_persistence DOUBLE NOT NULL,
    tda_h2_persistence DOUBLE NOT NULL,
    sindy_residual DOUBLE NOT NULL,
    state_flags INT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_calculated_at (calculated_at_ns),
    INDEX idx_re_lambda (re_lambda_max)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 微視的・構造的起爆粒子（つぶやき）ログ
CREATE TABLE IF NOT EXISTS critical_trigger_posts_v2 (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    spectrum_id BIGINT NOT NULL,
    slot_index INT UNSIGNED NOT NULL,
    post_uri VARCHAR(256) NOT NULL,
    author_did VARCHAR(128) NOT NULL,
    post_text TEXT NOT NULL,
    contribution_score DOUBLE NOT NULL,
    local_ricci_curvature DOUBLE NOT NULL,
    structural_role ENUM('SINGULARITY_CATALYST', 'BOUNDARY_BREAKER', 'VORTICITY_CENTER') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (spectrum_id) REFERENCES spectrum_history_v2(id) ON DELETE CASCADE,
    INDEX idx_uri (post_uri),
    INDEX idx_author (author_did),
    INDEX idx_role (structural_role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 5. Verification & Validation Protocol

1.  **高次元アドバーサリアル・バーストテスト**:
    *   Bluesky インジェスターに対し、異種対立的な意味論ベクトルを持つ 1,000 件の疑似ポスト群（限界界面穿孔データ）を 10ms 以内に人工注入する。
2.  **多様体曲率・SINDy 応答検証**:
    *   R エンジンが局所負曲率の不連続な増加（$R_{ij} < -2.0$）を検知し、Julia の Vector SINDy-PDE が非線形相互作用項 $\mathbf{C}_2$ の非ゼロ同定を 200ms 以内に達成することを確認。
3.  **起爆粒子抽出精度テスト**:
    *   注入された疑似ポスト群の中から、幾何学的歪みを引き起こした正確な触媒ポスト URI が `Particle Output Area` 経由で .NET Gateway にて抽出され、MariaDB に正確な `structural_role` 分類とともに 15ms 以内に保存されることを検証。
4.  **WebGL レンダリング & アンカー追従検証**:
    *   WebUI 上でメッシュが赤色スパイク形状に変形し、抽出された起爆ポストが 3D 空間上の特異点座標に正確にバインドされてホログラフィック表示されることを確認する。
