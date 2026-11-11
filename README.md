# 片单 · Film Watchlist（ai coding）

> A local-first watchlist for film \& TV franchises. Single HTML file + a tiny
> PowerShell server, no Python / Node / build step. Windows only.

给影迷用的本地片单工具：按系列（漫威、007、星球大战……）整理电影，点一下标记「已看」，
带参数筛选、联网搜索和系列识别。**数据全部存在本机**，不上传任何服务器。

!\[Windows](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)
!\[PowerShell](https://img.shields.io/badge/runtime-PowerShell%205.1-5391FE)
!\[No dependencies](https://img.shields.io/badge/dependencies-none-green)

## 功能

* **多片单**：左侧切换，内置漫威 / 007 / 星球大战 / 哈利·波特 / 神奇动物 / 速度与激情 / 碟中谍 / DC 等系列
* **点击已看**：点整行即可标记 / 取消，顶部实时显示进度
* **固定显示**：点每行右侧的 ☆ 变 ★，该条目**不受筛选和「已看/未看」影响**始终显示；排序仍按所选方式，不会提到最前
* **观看入口**：每行右侧的「观看」按钮，弹出已启用的视频平台（B站 / 腾讯视频 / 爱奇艺 / 优酷 / 芒果TV），点哪个就在哪个平台搜该片（自动带年份，避免同名作品混淆）
* **自定义平台**：可在「设置与备份」里自行添加平台——只需填名称 + 平台首页地址（如 `https://www.douyin.com`）。点它时会**直接打开该平台首页，并把片名复制到剪贴板**，粘贴到站内搜索框即可；点 ✎ 可编辑名称和地址，× 可删除
* **评分**：每行显示分数徽章，来源可在设置里切换（豆瓣 / IMDb / TMDB / 不显示）；点徽章即可填 0–10 分，各平台分数分开保存；填了 TMDB / OMDb 的 Key 后可用「拉取评分」批量补齐
* **筛选**：版本、出品、年代、上映状态，**都支持多选**（同框为「或」，跨框为「且」）；筛选和已看筛选**按片单分别记住**，切换片单互不影响（排序是全局设置）
* **搜索**：按片名、备注、出品过滤；输入系列名会弹出「切换到系列片」，一键跳转
* **联网搜索**：接 Wikidata（免 API Key），会**自动识别系列片**——搜「007」提示「詹姆斯·邦德电影系列」，点一下就取回整系列片目并新建片单
* **更新**：TMDB 同步或导入 JSON
* **自定义片单**：自己起名，或从片库 / 联网结果添加

## 快速开始

1. 下载本仓库（或 Releases 里的 zip）并解压
2. 双击 **`start.bat`**
3. 浏览器会自动打开 [http://127.0.0.1:8765/](http://127.0.0.1:8765/)

停止服务：关掉任务栏里最小化的 `Film Server` 窗口。

> 也可以只把 `index.html` 单独发给别人，双击即可用；此时数据存在浏览器里，
> 页面顶部会出现黄色提示条，属正常现象。

## 运行要求

|项目|说明|
|-|-|
|系统|Windows 10 / 11|
|运行时|系统自带的 Windows PowerShell 5.1|
|浏览器|Edge / Chrome|
|依赖|**无**（不需要 Python、Node 或任何第三方库）|

## 文件结构

```
index.html        界面本体（单文件，包含片库数据）
server.ps1        本地服务：静态页面 + /api/state 读写 data/state.json
start.bat         启动器（必须保持纯 ASCII 内容）
data/             运行时自动生成，存放用户数据（已在 .gitignore 中排除）
```

## 公开 API 密钥

「设置与备份 → API 密钥」里可以填两个**免费**服务的 Key，只存在本机的 `data/state.json`：

| 服务 | 用途 | 申请地址 |
|---|---|---|
| TMDB | 「更新」同步系列新片；拉取 TMDB 评分 | https://www.themoviedb.org/settings/api |
| OMDb | 拉取 IMDb 评分 | https://www.omdbapi.com/apikey.aspx |

填好后，在评分平台选 IMDb 或 TMDB，点「拉取评分」即可批量补齐当前片单的分数（只补空的，间隔 200ms 限速，连续失败会自动停止）。豆瓣没有公开接口，只能手动填。

## 数据与隐私

* 所有数据存放在 `data/state.json`，**只在本机**，不经任何服务器
* `data/state.bak.json` 是上一次保存的备份
* 设置里的 TMDB API Key 也保存在同一文件；**该目录已加入 `.gitignore`**，
如果你手动改过 `.gitignore` 或曾经把它提交过，请及时更换 Key
* 服务只监听 `127.0.0.1`，局域网内其他设备访问不到

## 已知限制

* **仅 Windows**：依赖 PowerShell 与批处理
* `/api/\*` 返回 `Access-Control-Allow-Origin: \*`，用于让 `file://` 直接打开页面时
也能读写磁盘。副作用是本机任意网页（在服务运行时）也能读写这份数据。
日常个人使用影响很小；若要更严格，可以改为只允许同源访问（此时
`file://` 模式只能退化为浏览器本地存储）
* 编辑 `server.ps1` 后请保持 **UTF-8 with BOM**，否则 PowerShell 5.1 在非中文
系统上会把中文读成乱码；`start.bat` 内不能出现非 ASCII 字符

## 二次开发

片库数据内嵌在 `index.html` 的 `SERIES\_LIB` / `MARVEL\_ITEMS` 两个常量里，
直接编辑即可。接口很简单：

|方法|路径|说明|
|-|-|-|
|GET|`/api/health`|服务状态|
|GET|`/api/state`|读取全部数据|
|PUT|`/api/state`|整体覆盖写入（写入前自动备份上一版）|

## License

尚未指定。若要允许他人自由使用，建议添加 MIT License；
若仅自己使用，保持现状即可。

