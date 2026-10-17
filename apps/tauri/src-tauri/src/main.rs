// Nova 设置 —— Tauri 外壳：窗口在 tauri.conf.json 里配置，界面是共用的网页
// 发布版不弹控制台窗口
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("启动 Tauri 程序失败");
}
