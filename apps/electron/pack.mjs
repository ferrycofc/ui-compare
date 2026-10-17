// 用 @electron/packager 打包成 Windows x64 程序（build.ps1 调用：node pack.mjs <输出目录>）
// 用 JS 接口而不是命令行，是为了不在 pwsh / cmd 里转义正则表达式。
import { packager } from '@electron/packager';

const out = process.argv[2];
if (!out) {
  console.error('用法：node pack.mjs <输出目录>');
  process.exit(1);
}

const appPaths = await packager({
  dir: '.',
  name: 'Nova',
  executableName: 'Nova',
  platform: 'win32',
  arch: 'x64',
  out,
  overwrite: true,
  asar: true,
  prune: true,
  // 路径相对于 apps/electron，以 / 开头。只留下 main.js、package.json 和 web/
  ignore: [
    /^\/dist($|\/)/,
    /^\/node_modules($|\/)/,
    /^\/build\.ps1$/,
    /^\/pack\.mjs$/,
    /^\/app\.json$/,
    /^\/\.gitignore$/,
  ],
  win32metadata: {
    CompanyName: 'Nova',
    ProductName: 'Nova',
    FileDescription: 'Nova 设置',
  },
});

console.log(appPaths.join('\n'));
