// scripts/copy-preload.cjs
const fs = require('fs');
const fse = require('fs-extra');
const path = require('path');

const src = path.resolve('src/main/preload.cjs');
const dst = path.resolve('dist/main/preload.cjs');

fse.ensureDirSync(path.dirname(dst));
fse.copyFileSync(src, dst);
console.log('[copy-preload] copied ->', dst);
