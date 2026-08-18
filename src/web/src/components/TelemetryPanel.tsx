import React, { useEffect, useRef } from 'react';
import katex from 'katex';
import 'katex/dist/katex.min.css';
import './TelemetryPanel.css';

interface Props {
  equation: string;
  reLambdaMax: number;
  meanRicci: number;
  h1Persistence: number;
  h2Persistence: number;
  residual: number;
}

export const TelemetryPanel: React.FC<Props> = ({
  equation,
  reLambdaMax,
  meanRicci,
  h1Persistence,
  h2Persistence,
  residual
}) => {
  const katexRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (katexRef.current && equation) {
      const latexEq = equation
        .replaceAll('delu/delt =', '\\frac{\\partial \\mathbf{U}}{\\partial t} =')
        .replaceAll('del^2u', '\\nabla^2 \\mathbf{U}');

      katex.render(latexEq, katexRef.current, { throwOnError: false, displayMode: true });
    }
  }, [equation]);

  const calcPercent = (val: number, min: number, max: number) => {
    const clamped = Math.max(min, Math.min(max, val));
    return ((clamped - min) / (max - min)) * 100;
  };

  return (
    <aside className="telemetry-panel">
      <div className="panel-section-title">IDENTIFIED GRAPH-PDE EQUATION</div>
      <div className="pde-box">
        {equation ? <div ref={katexRef} /> : <span style={{ color: 'var(--text-muted)', fontSize: '12px' }}>Awaiting SINDy-PDE Identification...</span>}
      </div>

      <div className="panel-section-title">MANIFOLD & TOPOLOGY METRICS</div>
      <div className="gauge-group">
        <div className="gauge-item">
          <div className="gauge-label-row">
            <span>Re(λ_max) Spectral Stability</span>
            <strong>{reLambdaMax.toFixed(4)}</strong>
          </div>
          <div className="gauge-bar-bg">
            <div
              className="gauge-bar-fill"
              style={{
                width: `${calcPercent(reLambdaMax, -0.5, 0.1)}%`,
                backgroundColor: reLambdaMax > -0.05 ? 'var(--color-critical)' : 'var(--color-stable)'
              }}
            />
          </div>
        </div>

        <div className="gauge-item">
          <div className="gauge-label-row">
            <span>Mean Ricci Curvature (R_ij)</span>
            <strong>{meanRicci.toFixed(4)}</strong>
          </div>
          <div className="gauge-bar-bg">
            <div
              className="gauge-bar-fill"
              style={{
                width: `${calcPercent(meanRicci, -1.0, 0.5)}%`,
                backgroundColor: meanRicci < -0.3 ? 'var(--color-perturbed)' : 'var(--color-accent)'
              }}
            />
          </div>
        </div>

        <div className="gauge-item">
          <div className="gauge-label-row">
            <span>TDA H₁ Loop Persistence</span>
            <strong>{h1Persistence.toFixed(4)}</strong>
          </div>
          <div className="gauge-bar-bg">
            <div className="gauge-bar-fill" style={{ width: `${calcPercent(h1Persistence, 0, 1.0)}%`, backgroundColor: 'var(--color-accent)' }} />
          </div>
        </div>

        <div className="gauge-item">
          <div className="gauge-label-row">
            <span>TDA H₂ Void Persistence</span>
            <strong>{h2Persistence.toFixed(4)}</strong>
          </div>
          <div className="gauge-bar-bg">
            <div className="gauge-bar-fill" style={{ width: `${calcPercent(h2Persistence, 0, 0.5)}%`, backgroundColor: 'var(--color-accent)' }} />
          </div>
        </div>
      </div>

      <div className="panel-section-title">RESIDUAL & ERROR</div>
      <div style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
        PDE Residual Norm: <span style={{ color: 'var(--text-main)' }}>{residual.toFixed(6)}</span>
      </div>
    </aside>
  );
};
