// Nova 设置 —— Electron 外壳：一个普通的原生窗口，里面加载共用的网页界面
'use strict';

const { app, BrowserWindow, Menu, nativeTheme } = require('electron');
const path = require('node:path');

function createWindow() {
  const win = new BrowserWindow({
    // 外框尺寸（含边框），和其它技术一致：看得见的窗口约 906 × 653
    width: 920,
    height: 660,
    resizable: false,
    maximizable: false,
    fullscreenable: false,
    center: true,
    title: 'Nova 设置 — Electron',
    backgroundColor: '#0f1014',
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  // 窗口标题固定不变，不跟着网页的 <title> 走
  win.on('page-title-updated', (e) => e.preventDefault());

  // 画好第一帧再显示，避免白屏闪一下
  win.once('ready-to-show', () => win.show());
  setTimeout(() => {
    if (!win.isDestroyed() && !win.isVisible()) win.show();
  }, 3000);

  win.loadFile(path.join(__dirname, 'web', 'index.html'));
}

app.whenReady().then(() => {
  nativeTheme.themeSource = 'dark'; // 深色的原生标题栏
  Menu.setApplicationMenu(null);    // 不要菜单栏
  createWindow();
});

app.on('window-all-closed', () => app.quit());
