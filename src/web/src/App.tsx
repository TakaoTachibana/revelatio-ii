import React from 'react';
import { useAutopoieticStream } from './hooks/useAutopoieticStream';
import { HeaderHud } from './components/HeaderHud';
import { TelemetryPanel } from './components/TelemetryPanel';
import { LogStreamPanel } from './components/LogStreamPanel';
import './App.css';

export const App: React.FC = () => {
  const { event, triggerPosts, connected } = useAutopoieticStream();

  return (
    <div className="app-container">
      <HeaderHud
        connected={connected}
        stateFlags={event?.stateFlags ?? 0}
        reLambdaMax={event?.reLambdaMax ?? -0.45}
        writeIndex={event?.writeIndex ?? 0}
      />
      <div className="main-content">
        <TelemetryPanel
          equation={event?.equation ?? ''}
          reLambdaMax={event?.reLambdaMax ?? -0.45}
          meanRicci={event?.meanRicciCurvature ?? 0}
          h1Persistence={event?.tdaH1Persistence ?? 0}
          h2Persistence={event?.tdaH2Persistence ?? 0}
          residual={event?.residual ?? 0}
        />
        <LogStreamPanel posts={triggerPosts} />
      </div>
    </div>
  );
};

export default App;
