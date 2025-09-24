import * as electron from 'electron';
const { ipcMain } = electron;
import { createDisplayWindow, closeDisplayWindowIfAny } from './windows';

ipcMain.handle('display:open', async () => {
  await createDisplayWindow();
  return true;
});

ipcMain.handle('display:close', async () => {
  closeDisplayWindowIfAny();
  return true;
});
