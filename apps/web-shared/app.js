// Nova 设置 —— Electron 和 Tauri 共用的网页前端（不依赖任何框架，也不联网）
(() => {
  'use strict';

  // 当前外壳：网址里的 ?tech= 优先；否则 Tauri 会注入 __TAURI_INTERNALS__
  const tech = new URLSearchParams(location.search).get('tech')
    || (('__TAURI_INTERNALS__' in window) ? 'Tauri' : 'Electron');
  document.title = `Nova 设置 — ${tech}`;
  document.getElementById('tech').textContent = tech;

  // [文字, 带齿轮, 默认打开]
  const general = [
    ['开机自启', true, true],
    ['最小化到托盘', true, true],
    ['自动更新', true, false],
    ['硬件加速', true, true],
    ['垂直同步', true, false],
    ['显示帧率', true, false],
    ['低延迟模式', true, false],
    ['夜间模式', false, true],
    ['后台静音', false, false],
    ['发送使用统计', false, false],
  ];
  const perf = [
    ['帧率限制', true, true],
    ['动态分辨率', true, false],
    ['预加载资源', true, false],
    ['多线程渲染', true, true],
    ['省电模式', true, false],
  ];
  const display = [
    ['自动亮度', false, false],
    ['HDR', false, true],
  ];

  // 一行：文字 …… [齿轮] [开关]
  function addRows(container, rows) {
    for (const [text, gear, on] of rows) {
      const row = document.createElement('div');
      row.className = 'row';

      const label = document.createElement('span');
      label.className = 'row-label';
      label.textContent = text;
      row.append(label);

      if (gear) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'gear';
        btn.title = `${text}设置`;
        btn.setAttribute('aria-label', `${text}设置`);
        btn.innerHTML = '<svg class="ic" aria-hidden="true"><use href="#i-gear"></use></svg>';
        row.append(btn);
      }

      // 开关：可访问名称 = 这一行的文字（录屏脚本靠它找控件）
      const sw = document.createElement('button');
      sw.type = 'button';
      sw.className = 'switch';
      sw.setAttribute('role', 'switch');
      sw.setAttribute('aria-checked', String(on));
      sw.setAttribute('aria-label', text);
      sw.addEventListener('click', () => {
        const next = sw.getAttribute('aria-checked') !== 'true';
        sw.setAttribute('aria-checked', String(next));
      });
      row.append(sw);

      container.append(row);
    }
  }

  addRows(document.getElementById('general'), general);
  addRows(document.getElementById('perf'), perf);
  addRows(document.getElementById('display'), display);

  // 滑块：拖动时实时更新右侧百分比和轨道上的紫色部分
  function bindSlider(id) {
    const input = document.getElementById(id);
    const value = document.getElementById(`${id}-value`);
    const update = () => {
      const min = Number(input.min), max = Number(input.max), v = Number(input.value);
      input.style.setProperty('--fill', String((v - min) / (max - min)));
      value.textContent = `${v}%`;
    };
    input.addEventListener('input', update);
    update();
  }

  bindSlider('bright');
  bindSlider('contrast');

  // 图标栏和标签：点击只切换选中样式，不切换内容
  function selectable(selector) {
    const items = Array.from(document.querySelectorAll(selector));
    for (const item of items) {
      item.addEventListener('click', () => {
        for (const other of items) {
          const active = other === item;
          other.classList.toggle('is-active', active);
          other.setAttribute('aria-selected', String(active));
        }
      });
    }
  }

  selectable('.rail-group .rail-btn');
  selectable('.tabs .tab');

  // 像原生程序一样：不弹网页右键菜单
  document.addEventListener('contextmenu', (e) => e.preventDefault());
})();
