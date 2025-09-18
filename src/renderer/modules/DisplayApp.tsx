import React, { useEffect, useMemo, useRef, useState } from "react";

type OpenPayload = {
  id?: string;       // ID catalogue pour stats
  mediaId?: string;  // id interne (vault)
  src?: string;      // chemin/URL asset
  title?: string;
  artist?: string;
};

export default function DisplayApp() {
  const electron = (window as any).electron;

  // --- Refs / états ---
  const videoRef = useRef<HTMLVideoElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);

  // Garde-fous seek et open
  const seekBarRef = useRef<HTMLDivElement>(null);
  const isSeekingRef = useRef(false);
  const wasPlayingRef = useRef(false);
  const skipStatusWhileSeekRef = useRef(false);
  const endedGuardUntilRef = useRef(0);
  const lastSourceKeyRef = useRef<string | null>(null);
  
  // Système de comptage des vues
  const viewCountedRef = useRef<Set<string>>(new Set());

  // UI
  const [title, setTitle] = useState("");
  const [artist, setArtist] = useState("");
  const [currentId, setCurrentId] = useState<string | null>(null);
  const [showUI, setShowUI] = useState(true);
  const [lastMoveAt, setLastMoveAt] = useState<number>(Date.now());
  const [progress, setProgress] = useState({ t: 0, d: 0 });
  
  // Prochaine chanson
  const [nextTitle, setNextTitle] = useState("");
  const [nextArtist, setNextArtist] = useState("");

  // --- Pings activité (auto-lock côté main) ---
  useEffect(() => {
    const ping = () => electron?.session?.activity?.();
    const onMove = () => ping();
    const onKey = () => ping();
    window.addEventListener("mousemove", onMove);
    window.addEventListener("keydown", onKey);
    const id = window.setInterval(ping, 15000);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("keydown", onKey);
      window.clearInterval(id);
    };
  }, []);

  // --- Signaler que l'app display est prête ---
  useEffect(() => {
    console.log('[DisplayApp] Envoi signal display:ready');
    electron?.ipc?.send?.('display:ready');
  }, []);

  // --- Auto-hide overlay (2s) ---
  useEffect(() => {
    const i = setInterval(() => {
      if (Date.now() - lastMoveAt > 2000) setShowUI(false);
    }, 250);
    return () => clearInterval(i);
  }, [lastMoveAt]);

  // --- Utilitaires ---
  const fmt = (s: number) => {
    if (!Number.isFinite(s) || s < 0) return "--:--";
    const m = Math.floor(s / 60);
    const sec = Math.floor(s % 60);
    return `${m}:${sec.toString().padStart(2, "0")}`;
  };

  const pct = useMemo(() => {
    return progress.d > 0
      ? Math.max(0, Math.min(100, (progress.t / progress.d) * 100))
      : 0;
  }, [progress]);

  // --- Idempotence de player:open + contrôles player:control ---
  useEffect(() => {
    // OUVERTURE: ne recharge que si la source change
    const offOpen = electron?.ipc?.on?.("player:open", (p: OpenPayload) => {
      console.log("[display] 🎬 player:open handler appelé");
      console.log("[display] payload reçu:", p);
      
      const v = videoRef.current;
      if (!v) {
        console.error("[display] ❌ videoRef.current est null");
        return;
      }

      console.log("[display] ✅ videoRef trouvé, traitement...");
      console.log("[display] player:open reçu:", p);

      setTitle(p.title || "");
      setArtist(p.artist || "");
      setCurrentId(p.id || p.mediaId || null);

      const key = p.mediaId
        ? `vault:${p.mediaId}`
        : p.src
        ? `file:${p.src}`
        : "";

      if (key && lastSourceKeyRef.current === key) {
        // même source → pour le repeat, on force quand même la relecture
        console.log("[display] même source détectée:", key);
        console.log("[display] Force relecture pour repeat - currentTime:", v.currentTime);
        
        // Pour forcer la relecture de la même source, on reset currentTime à 0
        v.currentTime = 0;
        // Essayer de jouer directement
        console.log('[display] tryPlay() appelé - tentative de lecture');
        v.play().then(() => {
          console.log('[display] ✅ play() réussi');
        }).catch(e => {
          console.log('[display] ⚠️ play() blocked:', e);
        });
        return;
      }

      lastSourceKeyRef.current = key;
      
      // Reset du flag de vue pour la nouvelle vidéo (les vues seront comptées à la fin)
      // Note: viewCountedRef garde l'historique de session, pas de reset ici
      
      // Déterminer la source
      let nextSrc = '';
      if (p.mediaId) {
        nextSrc = `vault://media/${p.mediaId}`;
      } else if (p.src) {
        if (p.src.startsWith('asset://') || p.src.startsWith('file://')) {
          nextSrc = p.src;
        } else {
          // Chemin absolu Windows -> file:///
          nextSrc = 'file:///' + p.src.replace(/\\/g, '/');
        }
      } else {
        console.warn('[display] player:open sans src/mediaId');
        return;
      }

      console.log("[display] setting v.src =", nextSrc);
      v.src = nextSrc;
      
      // Sécuriser l'autoplay
      v.autoplay = true;
      v.playsInline = true;
      v.muted = false;

      const tryPlay = () => {
        console.log('[display] tryPlay() appelé - tentative de lecture');
        v.play().then(() => {
          console.log('[display] ✅ play() réussi');
        }).catch(err => {
          console.warn('[display] ❌ play() blocked:', err);
        });
      };

      // Réessaie au bon moment
      tryPlay();
      const onMeta = () => { 
        console.log("[display] loadedmetadata - tentative play()");
        tryPlay(); 
        v.removeEventListener('loadedmetadata', onMeta); 
      };
      const onCanPlay = () => { 
        console.log("[display] canplay - tentative play()");
        tryPlay(); 
        v.removeEventListener('canplay', onCanPlay); 
      };
      v.addEventListener('loadedmetadata', onMeta);
      v.addEventListener('canplay', onCanPlay);

      // Logs d'erreur utiles
      const onError = () => {
        // 1: MEDIA_ERR_ABORTED, 2: NETWORK, 3: DECODE, 4: SRC_NOT_SUPPORTED
        console.error('[display] video error', v.error?.code, v.error);
        console.error('[display] networkState', v.networkState, 'readyState', v.readyState);
        console.error('[display] currentSrc:', v.currentSrc);
      };
      v.addEventListener('error', onError, { once: true });

      console.log("[display] v.load() cause=open (source changée)");
      v.load();
      v.play().catch(() => {});
    });

    // CONTROLES
    const offCtrl = electron?.ipc?.on?.(
      "player:control",
      (payload: { action: string; value?: number }) => {
        const v = videoRef.current;
        if (!v) return;

        if (payload.action === "play") {
          v.play().catch(() => {});
          // Envoi statut immédiat
          setTimeout(() => {
            electron?.ipc?.send?.("player:status:update", {
              currentTime: v.currentTime,
              duration: Number.isFinite(v.duration) ? v.duration : 0,
              paused: v.paused,
              isPlaying: !v.paused,
              isPaused: v.paused,
            });
          }, 100);
        }
        if (payload.action === "pause") {
          v.pause();
          // Envoi statut immédiat
          electron?.ipc?.send?.("player:status:update", {
            currentTime: v.currentTime,
            duration: Number.isFinite(v.duration) ? v.duration : 0,
            paused: v.paused,
            isPlaying: !v.paused,
            isPaused: v.paused,
          });
        }
        if (payload.action === "stop") {
          v.pause();
          v.currentTime = 0;
          // Envoi statut immédiat
          electron?.ipc?.send?.("player:status:update", {
            currentTime: 0,
            duration: Number.isFinite(v.duration) ? v.duration : 0,
            paused: true,
            isPlaying: false,
            isPaused: false,
          });
          electron?.closeDisplayWindow?.().catch?.(() => {});
        }
        if (payload.action === "seek" && typeof payload.value === "number") {
          const dur = Number.isFinite(v.duration) ? v.duration : 0;
          if (dur > 0) {
            // clamp safe (évite ended fantôme)
            const safe = Math.min(payload.value, Math.max(0, dur - 0.08));
            v.currentTime = safe;
            setProgress({ t: v.currentTime || 0, d: dur });
          }
        }
        if (payload.action === "setVolume" && typeof payload.value === "number") {
          v.volume = Math.max(0, Math.min(1, payload.value));
        }
      }
    );

    // TIME/ENDED
    const onTime = () => {
      if (skipStatusWhileSeekRef.current) return; // pas de status pendant le drag
      const v = videoRef.current;
      if (!v) return;
      const dur = Number.isFinite(v.duration) ? v.duration : 0;
      setProgress({ t: v.currentTime || 0, d: dur });

      electron?.ipc?.send?.("player:status:update", {
        currentTime: v.currentTime,
        duration: dur,
        paused: v.paused,
        isPlaying: !v.paused,
        isPaused: v.paused,
      });
    };

    const onEnded = () => {
      // 🔥 TEST PREMIER - Envoi message simple pour confirmer que la fonction fonctionne
      electron?.ipc?.send?.("player:event", { type: "test-onended", message: "onEnded function was called!" });
      
      // 🔥 SUPER LOG pour diagnostique - envoi au main process
      electron?.ipc?.send?.('debug-log', '[display] 🔥🔥🔥 onEnded DÉCLENCHÉ ! DisplayApp reçoit événement ended');
      console.log("[display] 🔥 onEnded DÉCLENCHÉ ! Début du traitement...");
      console.log("[display] onEnded déclenché");
      
      // Ignorer les ended déclenchés par un seek très proche de la fin
      if (Date.now() < endedGuardUntilRef.current || isSeekingRef.current) {
        electron?.ipc?.send?.('debug-log', '[display] ended ignoré (seek récent)');
        console.warn("[display] ended ignoré (seek récent)");
        return;
      }
      const v = videoRef.current;
      if (!v) {
        electron?.ipc?.send?.('debug-log', '[display] ended ignoré (pas de vidéo)');
        console.warn("[display] ended ignoré (pas de vidéo)");
        return;
      }
      const dur = Number.isFinite(v.duration) ? v.duration : 0;
      electron?.ipc?.send?.('debug-log', `[display] ended - durée: ${dur}, currentTime: ${v.currentTime}`);
      console.log("[display] ended - durée:", dur, "currentTime:", v.currentTime);
      
      electron?.ipc?.send?.('debug-log', '[display] ✅ ended validé - traitement des vues');
      console.log("[display] ✅ ended validé - traitement des vues");

      // Incrémenter le compteur de vues à la fin de la lecture
      const id = currentId;
      electron?.ipc?.send?.('debug-log', `[display] ID pour vues: ${id}`);
      console.log("[display] ID pour vues:", id);
      if (id && !viewCountedRef.current.has(id)) {
        viewCountedRef.current.add(id);
        electron?.ipc?.send?.('debug-log', `[display] ✅ Incrémentation des vues pour: ${id}`);
        console.log("[display] ✅ Incrémentation des vues à la fin de la lecture pour:", id);
        
        try {
          // Envoi des stats de vue pour incrémenter le compteur
          electron?.stats?.played?.({ id, playedMs: 0 }).then(() => {
            electron?.ipc?.send?.('debug-log', `[display] ✅ Stats de vues envoyées - ID: ${id}`);
            console.log("[display] ✅ Stats de vues envoyées - ID:", id);
            
            // 🔔 Notifier le control window pour qu'il recharge les stats
            electron?.ipc?.send?.('stats:updated', { id });
            electron?.ipc?.send?.('debug-log', `[display] ✅ Notification stats:updated envoyée pour ID: ${id}`);
            console.log("[display] ✅ Notification stats:updated envoyée pour ID:", id);
          }).catch((e: any) => {
            electron?.ipc?.send?.('debug-log', `[display] ❌ Erreur stats: ${e}`);
            console.warn("[display] ❌ Erreur lors de l'envoi des stats de vues:", e);
          });
        } catch (e) {
          electron?.ipc?.send?.('debug-log', `[display] ❌ Erreur incrémentation: ${e}`);
          console.warn("[display] ❌ Erreur lors de l'incrémentation des vues:", e);
        }
      } else {
        electron?.ipc?.send?.('debug-log', `[display] ⚠️ Vues déjà comptées pour: ${id} ou pas d'ID`);
        console.log("[display] ⚠️ Vues déjà comptées pour:", id, "ou pas d'ID", "viewCounted:", viewCountedRef.current);
      }

      // Compter les stats de durée à la vraie fin (séparé du comptage des vues)
      try {
        const playedMs = Math.round((v.currentTime || 0) * 1000);
        console.log("[display] Stats durée - playedMs:", playedMs);
        if (id && playedMs > 0) {
          // Note: Ceci pourrait incrémenter une deuxième fois, mais c'est le comportement legacy
          electron?.stats?.played?.({ id, playedMs });
          console.log("[display] ✅ Stats durée envoyées");
        }
      } catch (e) {
        console.warn("[display] Error sending stats:", e);
      }

      // Notifier le control pour que la logique de repeat s'exécute
      console.log("[display] ✅ Envoi de l'événement 'ended' au control pour gestion du repeat");
      electron?.ipc?.send?.("player:event", { type: "ended" });
    };

    const v = videoRef.current;
    v?.addEventListener("timeupdate", onTime);
    v?.addEventListener("loadedmetadata", onTime);
    v?.addEventListener("ended", onEnded);

    return () => {
      offOpen?.();
      offCtrl?.();
      v?.removeEventListener("timeupdate", onTime);
      v?.removeEventListener("loadedmetadata", onTime);
      v?.removeEventListener("ended", onEnded);
    };
  }, [electron, currentId]);

  // --- Listener pour la prochaine chanson ---
  useEffect(() => {
    const offNextSong = electron?.ipc?.on?.("player:next-info", (payload: { title?: string; artist?: string }) => {
      console.log("[display] 🎵 next-info reçu:", payload);
      setNextTitle(payload.title || "");
      setNextArtist(payload.artist || "");
    });

    return () => {
      offNextSong?.();
    };
  }, [electron]);

  // --- Raccourcis clavier ---
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const v = videoRef.current;
      if (!v) return;

      if (e.key === " ") {
        e.preventDefault();
        v.paused ? v.play() : v.pause();
      }
      if (e.key === "f" || e.key === "F") {
        e.preventDefault();
        electron?.toggleFullscreen?.();
      }
      if (e.key === "Escape") {
        e.preventDefault();
        v.pause();
        v.currentTime = 0;
        electron?.closeDisplayWindow?.().catch?.(() => {});
      }
      if (e.key === "ArrowRight") {
        e.preventDefault();
        v.currentTime = (v.currentTime || 0) + 5;
      }
      if (e.key === "ArrowLeft") {
        e.preventDefault();
        v.currentTime = Math.max(0, (v.currentTime || 0) - 5);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [electron]);

  // --- UI helpers ---
  const onDoubleClick = () => electron?.toggleFullscreen?.();
  const onMouseMove = () => {
    setShowUI(true);
    setLastMoveAt(Date.now());
  };

  // --- Seek par pointer events (anti-redémarrage) ---
  const setFromClientX = (clientX: number) => {
    const v = videoRef.current,
      bar = seekBarRef.current;
    if (!v || !bar) return;

    const duration = Number.isFinite(v.duration) ? v.duration : 0;
    if (duration <= 0) return;

    const rect = bar.getBoundingClientRect();
    const width = Math.max(1, rect.width);
    const ratio = Math.max(0, Math.min(1, (clientX - rect.left) / width));

    // éviter de coller à duration → pas d'ended fantôme
    const safe = Math.min(ratio * duration, Math.max(0, duration - 0.08));
    v.currentTime = safe;
    setProgress({ t: v.currentTime || 0, d: duration });
  };

  const onPointerDownSeek = (e: React.PointerEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    (e.currentTarget as HTMLDivElement).setPointerCapture?.(e.pointerId);

    const v = videoRef.current;
    if (!v) return;

    wasPlayingRef.current = !v.paused;
    try {
      v.pause();
    } catch {}

    isSeekingRef.current = true;
    skipStatusWhileSeekRef.current = true;
    endedGuardUntilRef.current = Date.now() + 1000; // 1s d'immunité ended
    console.log("[display] SEEK start");

    setFromClientX(e.clientX);
  };

  const onPointerMoveSeek = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!isSeekingRef.current) return;
    e.preventDefault();
    e.stopPropagation();
    setFromClientX(e.clientX);
  };

  const onPointerUpSeek = (e: React.PointerEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    isSeekingRef.current = false;
    skipStatusWhileSeekRef.current = false;
    console.log("[display] SEEK end");

    const v = videoRef.current;
    if (v && wasPlayingRef.current) {
      // relance après positionnement
      setTimeout(() => v.play().catch(() => {}), 0);
    }
  };

  // --- Rendu ---
  return (
    <div
      ref={wrapRef}
      onDoubleClick={onDoubleClick}
      onMouseMove={onMouseMove}
      style={{
        width: "100vw",
        height: "100vh",
        background: "#000",
        color: "#fff",
        position: "relative",
        padding: "clamp(8px, 3vmin, 40px)",
        boxSizing: "border-box",
        overflow: "hidden",
        cursor: showUI ? "default" : "none",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      {/* Vidéo — fit proportionnel sans découpe */}
      <video
        ref={videoRef}
        style={{
          maxWidth: "100%",
          maxHeight: "100%",
          width: "auto",
          height: "auto",
          objectFit: "contain",
          display: "block",
          backgroundColor: "#000",
        }}
        playsInline
        disablePictureInPicture
        controls={false}
      />

      {/* Overlay top (titre + artiste) */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          right: 0,
          padding: "12px 16px",
          pointerEvents: "none",
          opacity: showUI ? 1 : 0,
          transition: "opacity 200ms linear",
          display: "flex",
          justifyContent: "center",
        }}
      >
        {(title || artist) && (
          <div
            style={{
              maxWidth: "80vw",
              background:
                "linear-gradient(180deg, rgba(0,0,0,0.65), rgba(0,0,0,0.0))",
              padding: "8px 12px",
              borderRadius: 12,
              backdropFilter: "blur(2px)",
              textAlign: "center",
              lineHeight: 1.2,
            }}
          >
            <div
              style={{
                fontWeight: 600,
                fontSize: 18,
                whiteSpace: "nowrap",
                textOverflow: "ellipsis",
                overflow: "hidden",
              }}
            >
              {title || "—"}
            </div>
            <div
              style={{
                fontSize: 12,
                opacity: 0.8,
                whiteSpace: "nowrap",
                textOverflow: "ellipsis",
                overflow: "hidden",
              }}
            >
              {artist || ""}
            </div>
          </div>
        )}
      </div>

      {/* Barre de progression (pointer events) */}
      <div
        ref={seekBarRef}
        onPointerDown={onPointerDownSeek}
        onPointerMove={onPointerMoveSeek}
        onPointerUp={onPointerUpSeek}
        title={`${fmt(progress.t)} / ${fmt(progress.d)}`}
        style={{
          position: "absolute",
          left: "clamp(12px, 3vmin, 40px)",
          right: "clamp(12px, 3vmin, 40px)", // maintenant symétrique, plus d'espace pour bouton stop
          bottom: "clamp(10px, 2.5vmin, 32px)",
          height: 6,
          borderRadius: 4,
          background: "rgba(255,255,255,0.12)",
          overflow: "hidden",
          opacity: showUI ? 1 : 0,
          transition: "opacity 200ms linear",
          cursor: "pointer",
          touchAction: "none",
          userSelect: "none",
        }}
      >
        <div
          style={{
            width: `${pct}%`,
            height: "100%",
            background: "rgba(10,200,110,0.9)",
          }}
        />
      </div>

      {/* Overlay bottom (prochaine chanson) */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: 0,
          right: 0,
          padding: "12px 16px 32px 16px", // padding-bottom ajusté pour éviter la barre de progression
          pointerEvents: "none",
          opacity: showUI ? 1 : 0,
          transition: "opacity 200ms linear",
          display: "flex",
          justifyContent: "center",
        }}
      >
        {(nextTitle || nextArtist) && (
          <div
            style={{
              maxWidth: "80vw",
              background:
                "linear-gradient(0deg, rgba(0,0,0,0.65), rgba(0,0,0,0.0))",
              padding: "8px 12px",
              borderRadius: 12,
              backdropFilter: "blur(2px)",
              textAlign: "center",
              lineHeight: 1.2,
            }}
          >
            <div
              style={{
                fontSize: 10,
                opacity: 0.7,
                marginBottom: 2,
                textTransform: "uppercase",
                letterSpacing: "0.5px",
                fontWeight: 500,
              }}
            >
              À suivre
            </div>
            <div
              style={{
                fontWeight: 600,
                fontSize: 14,
                whiteSpace: "nowrap",
                textOverflow: "ellipsis",
                overflow: "hidden",
              }}
            >
              {nextTitle || "—"}
            </div>
            <div
              style={{
                fontSize: 10,
                opacity: 0.8,
                whiteSpace: "nowrap",
                textOverflow: "ellipsis",
                overflow: "hidden",
              }}
            >
              {nextArtist || ""}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
