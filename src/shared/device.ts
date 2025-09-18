import pkg from 'node-machine-id';
const { machineIdSync } = pkg;
import crypto from 'crypto';
import os from 'os';
import { exec } from 'child_process';
import { promisify } from 'util';
import type { DeviceFingerprint, USBDeviceInfo } from '../types/license.js';

const execAsync = promisify(exec);

export function getDeviceIds() {
  const original = machineIdSync(true); // "original" (non haché)
  const hash = crypto.createHash('sha256').update(original, 'utf8').digest('hex'); // 64 hex
  return { original, hash };
}

/**
 * Génère une empreinte complète de la machine
 */
export async function getMachineFingerprint(): Promise<DeviceFingerprint> {
  const { original: machineId } = getDeviceIds();
  const platform = os.platform();
  const arch = os.arch();
  const hostname = os.hostname();
  
  let networkMac: string | undefined;
  let usbSerial: string | undefined;
  
  try {
    // Obtenir l'adresse MAC principale
    const networkInterfaces = os.networkInterfaces();
    for (const [name, interfaces] of Object.entries(networkInterfaces)) {
      if (interfaces && name !== 'lo' && !name.includes('virtual')) {
        const physicalInterface = interfaces.find(iface => !iface.internal && iface.mac !== '00:00:00:00:00:00');
        if (physicalInterface) {
          networkMac = physicalInterface.mac;
          break;
        }
      }
    }
    
    // Détecter USB série selon l'OS
    usbSerial = await detectUSBSerial();
    
  } catch (error) {
    console.log('[DEVICE] Erreur détection périphériques:', error);
  }
  
  return {
    machineId,
    platform,
    arch,
    usbSerial,
    networkMac,
    hostname
  };
}

/**
 * Détecte le numéro de série du périphérique USB courant
 */
export async function detectUSBSerial(): Promise<string | undefined> {
  const platform = os.platform();
  
  try {
    switch (platform) {
      case 'win32':
        return await detectUSBSerialWindows();
      case 'darwin':
        return await detectUSBSerialMacOS();
      case 'linux':
        return await detectUSBSerialLinux();
      default:
        console.log('[DEVICE] Plateforme non supportée pour détection USB:', platform);
        return undefined;
    }
  } catch (error) {
    console.log('[DEVICE] Erreur détection USB série:', error);
    return undefined;
  }
}

/**
 * Détection Windows via WMI et PowerShell
 */
async function detectUSBSerialWindows(): Promise<string | undefined> {
  try {
    // Essayer d'identifier le disque de l'application
    const appPath = process.execPath;
    const driveLetter = appPath.substring(0, 2); // Ex: "C:"
    
    // Obtenir le numéro de série du volume
    const { stdout } = await execAsync(`powershell -Command "Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq '${driveLetter}'} | Select-Object VolumeSerialNumber"`);
    
    const lines = stdout.split('\n');
    for (const line of lines) {
      const match = line.match(/([A-F0-9]{8})/);
      if (match) {
        console.log('[DEVICE] USB Serial Windows détecté:', match[1]);
        return match[1];
      }
    }
    
    // Fallback : essayer via diskpart
    const { stdout: diskpartOut } = await execAsync('echo list volume | diskpart');
    console.log('[DEVICE] Diskpart output pour debug:', diskpartOut);
    
  } catch (error) {
    console.log('[DEVICE] Erreur PowerShell Windows:', error);
  }
  
  return undefined;
}

/**
 * Détection macOS via IORegistry
 */
async function detectUSBSerialMacOS(): Promise<string | undefined> {
  try {
    // Lister les périphériques USB
    const { stdout } = await execAsync('system_profiler SPUSBDataType -json');
    const usbData = JSON.parse(stdout);
    
    // Rechercher les périphériques de stockage
    for (const device of usbData.SPUSBDataType || []) {
      if (device.bsd_name || device._name?.includes('Storage')) {
        const serial = device.serial_num || device._name;
        if (serial) {
          console.log('[DEVICE] USB Serial macOS détecté:', serial);
          return serial;
        }
      }
    }
    
    // Fallback via diskutil
    const { stdout: diskOut } = await execAsync('diskutil list');
    console.log('[DEVICE] Diskutil output pour debug:', diskOut);
    
  } catch (error) {
    console.log('[DEVICE] Erreur system_profiler macOS:', error);
  }
  
  return undefined;
}

/**
 * Détection Linux via udev et blkid
 */
async function detectUSBSerialLinux(): Promise<string | undefined> {
  try {
    // Essayer avec lsblk pour identifier les périphériques USB
    const { stdout } = await execAsync('lsblk -o NAME,TRAN,SERIAL,MOUNTPOINT -J');
    const blockDevices = JSON.parse(stdout);
    
    for (const device of blockDevices.blockdevices || []) {
      if (device.tran === 'usb' && device.serial) {
        console.log('[DEVICE] USB Serial Linux détecté:', device.serial);
        return device.serial;
      }
    }
    
    // Fallback via udevadm
    const { stdout: udevOut } = await execAsync('find /dev/disk/by-id -name "*usb*" | head -5');
    console.log('[DEVICE] Udev USB devices:', udevOut);
    
  } catch (error) {
    console.log('[DEVICE] Erreur lsblk Linux:', error);
  }
  
  return undefined;
}

/**
 * Génère un identifiant stable pour binding USB+machine
 */
export async function generateStableDeviceId(): Promise<string> {
  const fingerprint = await getMachineFingerprint();
  
  // Combiner plusieurs sources pour stabilité
  const components = [
    fingerprint.machineId,
    fingerprint.platform,
    fingerprint.arch,
    fingerprint.usbSerial || 'no-usb',
    fingerprint.networkMac || 'no-mac'
  ];
  
  const combined = components.join('|');
  const hash = crypto.createHash('sha256').update(combined, 'utf8').digest('hex');
  
  console.log('[DEVICE] Stable ID généré depuis:', components);
  return hash;
}

/**
 * Valide qu'un device ID correspond à la machine actuelle
 */
export async function validateDeviceBinding(expectedDeviceId: string): Promise<boolean> {
  try {
    const currentDeviceId = await generateStableDeviceId();
    const isValid = currentDeviceId === expectedDeviceId;
    
    console.log('[DEVICE] Validation binding:', { expected: expectedDeviceId.substring(0, 8), current: currentDeviceId.substring(0, 8), isValid });
    
    return isValid;
  } catch (error) {
    console.error('[DEVICE] Erreur validation binding:', error);
    return false;
  }
}

/**
 * Obtient des informations détaillées sur le périphérique USB actuel
 */
export async function getCurrentUSBInfo(): Promise<USBDeviceInfo | undefined> {
  const serial = await detectUSBSerial();
  if (!serial) return undefined;
  
  return {
    serial,
    label: 'USB Video Vault',
    mountPath: process.cwd()
  };
}
