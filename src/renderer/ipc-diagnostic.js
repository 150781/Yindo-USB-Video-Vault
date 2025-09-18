// Test IPC reorder method directly from renderer
async function testIpcReorder() {
  console.log('[DIAGNOSTIC] Testing IPC reorder method...');
  
  // Check if electron object exists
  if (!window.electron) {
    console.error('[DIAGNOSTIC] window.electron not available');
    return;
  }
  
  // Check if queue methods exist
  if (!window.electron.queue) {
    console.error('[DIAGNOSTIC] window.electron.queue not available');
    return;
  }
  
  // Check if reorder method exists
  if (!window.electron.queue.reorder) {
    console.error('[DIAGNOSTIC] window.electron.queue.reorder not available');
    return;
  }
  
  console.log('[DIAGNOSTIC] Electron queue methods available:', Object.keys(window.electron.queue));
  
  try {
    // Test reorder with a dummy operation (move first item to second position)
    console.log('[DIAGNOSTIC] Calling reorder(0, 1)...');
    const result = await window.electron.queue.reorder(0, 1);
    console.log('[DIAGNOSTIC] Reorder result:', result);
    
    if (result && result.queue) {
      console.log('[DIAGNOSTIC] Queue items after reorder:', result.queue.length);
    } else {
      console.error('[DIAGNOSTIC] Invalid reorder result - missing queue property');
    }
  } catch (error) {
    console.error('[DIAGNOSTIC] Error calling reorder:', error);
  }
}

// Run test after DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  // Wait a bit for electron to be ready
  setTimeout(testIpcReorder, 2000);
});

// Also provide a manual test function
window.testIpcReorder = testIpcReorder;
