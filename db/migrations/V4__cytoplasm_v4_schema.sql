CREATE DATABASE IF NOT EXISTS revelatio_db
	CHARACTER SET utf8mb4
	COLLATE utf8mb4_unicode_ci;

USE revelatio_db;

CREATE TABLE IF NOT EXISTS spctrum_history_v2 (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	calculatied_at_ns BIGINT NOT NULL,
	re_rambda_max DOUBLE NOT NULL,
	mean_ricci_curvature DOUBLE NOT NULL,
	tda_h1_persistence DOUBLE NOT NULL,
	tda_h2_persistence DOUBLE NOT NULL,
	sindy_residual DOUBLE NOT NULL,
	state_flags INT UNSIGNED NOT NULL,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	INDEX idx_calculated_at (calculated_at_ns),
	INDEX idx_re_lambda (re_labmda_max)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS critical_trigger_posts_v2 (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	spectrum_id BIGINT NOT NULL,
	slot_index INT UNSIGNED NOT NULL,
	post_uri VARCHAR(256) NOT NULL,
	author_did VARCHAR(128) NOT NULL,
	post_text TEXT NOT NULL,
	contribution_score DOUBLE NOT NULL,
	local_ricci_curvature DOUBLE NOT NULL,
	structural_role ENUM('SINGULARITY_CATALISY', 'BOUNDARY_BREAKER', 'VORTICITY_ENTER') NOT NULL,
	FOREIGN KEY (spectrum_id) REFERENCES spectrum_history_v2(id) ON DELETE CASCADE,
	INDEX idx_uri (post_uri),
	INDEX idx_author (author_did),
	INDEX idx_role (structural_role)
) ENGIN=InnoDB DEFAULT CHARSET=utf8mb4;


