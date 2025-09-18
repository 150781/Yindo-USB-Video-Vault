import { ipcMain } from 'electron';
import { createDisplayWindow, closeDisplayWindowIfAny } from './windows.js';

ipcMain.handle('display:open', async () => {
  await createDisplayWindow();
  return true;
});

ipcMain.handle('display:close', async () => {
  closeDisplayWindowIfAny();
  return true;
});
