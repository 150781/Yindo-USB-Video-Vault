import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';
import DisplayApp from './modules/DisplayApp';

console.log('[renderer] display loaded');

const el = document.getElementById('root');
if (!el) {
  const div = document.createElement('div');
  div.id = 'root';
  document.body.appendChild(div);
  createRoot(div).render(<DisplayApp />);
} else {
  createRoot(el).render(<DisplayApp />);
}
