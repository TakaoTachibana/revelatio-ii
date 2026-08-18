# REVELATIO II: Disruption Sensing Validation Test

source("ricci_tda_kernel.R")

cat("====================================================\n")
cat(" [TEST 1] Standard Normal State (Baseline Verification)\n")
cat("====================================================\n")
# 通常の疎なランダムグラフ
set.seed(42)
norm_adj <- matrix(0, 64, 64)
for(i in 1:63) { norm_adj[i, i+1] <- 1; norm_adj[i+1, i] <- 1 } # チェーン構造
r_norm <- compute_forman_ricci(norm_adj, 64)
cat(sprintf("-> Normal Mean Ricci: %6.2f (Expected: ~0.00)\n\n", r_norm))

cat("====================================================\n")
cat(" [TEST 2] Hub Concentration / Star Topology (Perturbed/Critical)\n")
cat("====================================================\n")
# ノード1に全ノードが集中（スター型ハブ構造）
star_adj <- matrix(0, 64, 64)
star_adj[1, 2:64] <- 1
star_adj[2:64, 1] <- 1
r_star <- compute_forman_ricci(star_adj, 64)

flag_star <- 0
if (r_star < -0.3) flag_star <- bitwOr(flag_star, 2) # PERTURBED (0x02)
if (r_star < -0.6) flag_star <- bitwOr(flag_star, 4) # CRITICAL (0x04)
cat(sprintf("-> Star Topology Mean Ricci: %6.2f | Flags: 0x%02X\n", r_star, flag_star))
cat(sprintf("   Expected Flags: 0x06 (PERTURBED + CRITICAL)\n\n"))

cat("====================================================\n")
cat(" [TEST 3] Topological Loop Formation (TDA Disruption)\n")
cat("====================================================\n")
# 128次元空間上に明瞭な円環（1D Persistent Loop）を生成
theta <- seq(0, 2*pi, length.out = 50)
loop_vecs <- matrix(rnorm(50 * 128, sd = 0.01), nrow = 50, ncol = 128)
loop_vecs[, 1] <- cos(theta) * 5.0
loop_vecs[, 2] <- sin(theta) * 5.0

tda_res <- compute_tda_persistence(loop_vecs)
flag_tda <- 0
if (tda_res$h1 > 0.3 || tda_res$h2 > 0.2) flag_tda <- bitwOr(flag_tda, 8) # TDA_DISRUPTION (0x08)

cat(sprintf("-> Loop H1 Persistence: %5.3f | H2 Persistence: %5.3f | Flags: 0x%02X\n", 
            tda_res$h1, tda_res$h2, flag_tda))
cat(sprintf("   Expected Flags: 0x08 (TDA_DISRUPTION)\n\n"))
