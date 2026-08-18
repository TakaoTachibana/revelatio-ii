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
				const m = data.metrics || data.Metrics;
				if (m) {
					setEvent({
						writeIndex: data.spectrumId ?? data.SpectrumId,
						stateFlags: m.stateFlags ?? m.StateFlags ?? 0,
						reLambdaMax: m.reLambdaMax ?? m.ReLambdaMax ?? -0.45,
						meanRicciCurvature: m.meanRicciCurvature ?? m.MeanRicciCurvature ?? 0,
						tdaH1Persistence: m.tdaH1Persistence ?? m.TdaH1Persistence ?? 0,
						tdaH2Persistence: m.tdaH2Persistence ?? m.TdaH2Persistence ?? 0,
						residual: m.sindyResidual ?? m.SindyResidual ?? 0,
						equation: m.equation ?? m.Equation ?? '',
					});
				}
				const posts = data.triggerPosts || data.TriggerPosts;
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
