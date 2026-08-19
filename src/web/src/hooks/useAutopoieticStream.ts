import { useEffect, useState } from 'react';

export interface TriggerPost {
  slotIndex: number;
  uri: string;
  authorDid: string;
  text: string;
  contributionScore: number;
  localRicciCurvature: number;
  structuralRole: string;
}

export interface TelemetryEvent {
  writeIndex?: number;
  stateFlags: number;
  reLambdaMax: number;
  meanRicciCurvature: number;
  tdaH1Persistence: number;
  tdaH2Persistence: number;
  residual: number;
  equation?: string;
}

export const useAutopoieticStream = () => {
  const [connected, setConnected] = useState(false);
  const [event, setEvent] = useState<TelemetryEvent | null>(null);
  const [triggerPosts, setTriggerPosts] = useState<TriggerPost[]>([]);

  useEffect(() => {
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${wsProtocol}//${window.location.hostname}:5000/ws/topology`;
    const socket = new WebSocket(wsUrl);

    socket.onopen = () => setConnected(true);
    socket.onclose = () => setConnected(false);
    socket.onerror = () => setConnected(false);

		socket.onmessage = (msg) => {
			try {
				const data = JSON.parse(msg.data);
				const m = data.metrics || data.Metrics || data;

				if (m) {
					// snake_case, camelCase, PascalCase の全パターンに対応
					const meanRicci = m.meanRicciCurvature ?? m.mean_ricci_curvature ?? m.MeanRicciCurvature ?? 0;
					const h1 = m.tdaH1Persistence ?? m.tda_h1_persistence ?? m.TdaH1Persistence ?? 0;
					const h2 = m.tdaH2Persistence ?? m.tda_h2_persistence ?? m.TdaH2Persistence ?? 0;
					const reLambda = m.reLambdaMax ?? m.re_lambda_max ?? m.ReLambdaMax ?? -0.45;
					const residual = m.sindyResidual ?? m.sindy_residual ?? m.SindyResidual ?? 0;
					const flags = m.stateFlags ?? m.state_flags ?? m.StateFlags ?? 0;
					const eq = m.equation ?? m.Equation ?? '';

					setEvent({
						writeIndex: data.spectrumId ?? data.SpectrumId ?? 0,
						stateFlags: flags,
						reLambdaMax: reLambda,
						meanRicciCurvature: meanRicci,
						tdaH1Persistence: h1,
						tdaH2Persistence: h2,
						residual: residual,
						equation: eq,
					});
				}

				const posts = data.triggerPosts || data.TriggerPosts || data.trigger_posts;
				if (posts && Array.isArray(posts)) {
					setTriggerPosts((prev) => [...posts, ...prev].slice(0, 50));
				}
			} catch (e) {
				console.error('[WebSocket Parse Error]', e);
			}
		};	
    return () => socket.close();
  }, []);

  return { connected, event, triggerPosts };
};
