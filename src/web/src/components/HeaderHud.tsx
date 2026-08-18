import React from 'react';
import './HeaderHud.css';

interface Props {
  connected: boolean;
  stateFlags: number;
  reLambdaMax: number;
  writeIndex: number;
}

export const HeaderHud: React.FC<Props> = ({ connected, stateFlags, reLambdaMax, writeIndex }) => {
  const getStatus = () => {
    if ((stateFlags & 0x04) !== 0 || reLambdaMax > -0.05) return { label: 'CRITICAL', cls: 'critical' };
    if ((stateFlags & 0x02) !== 0 || reLambdaMax > -0.30) return { label: 'PERTURBED', cls: 'perturbed' };
    return { label: 'STABLE', cls: 'stable' };
  };

  const status = getStatus();

  return (
    <header className="header-hud">
      <div className="header-title">
        <span className="system-tag">REVELATIO II</span>
        <span>// AUTOPOIETIC TELEMETRY CONTROL</span>
      </div>

      <div className="header-metrics">
        <div className="metric-item">
          <span className="metric-label">GATEWAY LINK</span>
          <span style={{ color: connected ? 'var(--color-stable)' : 'var(--color-critical)' }}>
            {connected ? 'ONLINE' : 'DISCONNECTED'}
          </span>
        </div>
        <div className="metric-item">
          <span className="metric-label">WRITE INDEX</span>
          <span>#{writeIndex}</span>
        </div>
        <div className="metric-item">
          <span className="metric-label">SYSTEM STATE</span>
          <span className={`status-badge ${status.cls}`}>{status.label}</span>
        </div>
      </div>
    </header>
  );
};
