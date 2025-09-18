import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';
import ControlWindowClean from './modules/ControlWindowClean';
import LicenseGate from './modules/LicenseGate';

console.log('[renderer] control loaded');

function App() {
  return (
    <LicenseGate>
      <ControlWindowClean />
    </LicenseGate>
  );
}

createRoot(document.getElementById('root')!).render(<App />);
