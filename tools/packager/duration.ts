export async function probeDurationMs(filePath: string): Promise<number | null> {
  try {
    const ffprobe = await import('ffprobe-static').then(m => m.default || m);
    const ffmpeg = await import('fluent-ffmpeg').then(m => m.default || m);
    return new Promise((resolve) => {
      ffmpeg.ffprobe(filePath, { path: ffprobe.path }, (err, data) => {
        if (err) return resolve(null);
        const d = data.format?.duration;
        resolve(typeof d === 'number' && isFinite(d) ? Math.round(d * 1000) : null);
      });
    });
  } catch {
    // lib non installée → on renvoie null, le client pourra hydrater plus tard
    return null;
  }
}
