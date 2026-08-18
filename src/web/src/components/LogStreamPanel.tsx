import React from 'react';
import { TriggerPost } from '../hooks/useAutopoieticStream';
import './LogStreamPanel.css';

interface Props {
  posts: TriggerPost[];
}

export const LogStreamPanel: React.FC<Props> = ({ posts }) => {
  return (
    <main className="log-panel">
      <div className="panel-section-title">CRITICAL TRIGGER PARTICLES & LOG STREAM ({posts.length})</div>
      <div className="log-container">
        {posts.length === 0 ? (
          <div style={{ color: 'var(--text-muted)', fontSize: '12px', padding: '12px' }}>
            Listening for structural trigger particles and manifold disruption events...
          </div>
        ) : (
          posts.map((post, idx) => (
            <div key={`${post.slotIndex}-${idx}`} className={`post-card trigger-card ${post.structuralRole}`}>
              <div className="post-header-row">
                <span className="author-did">{post.authorDid}</span>
                <span className={`role-badge ${post.structuralRole}`}>{post.structuralRole}</span>
              </div>
              <div className="post-text">{post.text}</div>
              <div className="post-footer-row">
                <span>Score: <strong style={{ color: 'var(--color-accent)' }}>{post.contributionScore.toFixed(4)}</strong></span>
                <span>Local Ricci: <strong style={{ color: 'var(--color-accent)' }}>{post.localRicciCurvature.toFixed(4)}</strong></span>
                <span>Slot: #{post.slotIndex}</span>
              </div>
            </div>
          ))
        )}
      </div>
    </main>
  );
};
